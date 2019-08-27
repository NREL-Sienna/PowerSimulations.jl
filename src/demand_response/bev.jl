# Response for demands like BEVs, where there is some flexbility, but also hard constraints.


# Import modules.

using Dates, JuMP, TimeSeries

import PowerSystems: BevDemand, ChargingPlan, LocatedDemand, aligntimes


"""
Apply efficiency factors to relate energy at the vehicle to energy at the charger.

# Arguments
- `demand :: BevDemand{T,L}`: the demand

# Returns
- a function that converts energy at the vehicle to energy at the charger
"""
function applyefficiencies(demand :: BevDemand{T,L}) where L where T <: TimeType
    function f(x)
        if x == 0
            0.
        elseif x > 0
            x / demand.efficiency.in
        else
            x * demand.efficiency.out
        end
    end
    f
end


"""
Represent demand constraints for a BEV as a JuMP model.

# Arguments
- `demand :: BevDemand{T,L}`: the BEV demand

# Returns
- `model :: JuMP.Model`           : a JuMP model containing the constraints, where
                                    `charge` is the kWh charge during the time
                                    interval and `battery` is the batter level at
                                    the start of the interval and where the start
                                    of the intervals are given by `locations`
- `result() :: ChargingPlan{T,L}` : a function that returns the charging plan, 
                                    but which can only be called after the model
                                    has been solved
"""
function demandconstraints(demand :: BevDemand{T,L}) where L where T <: TimeType
    pricing = map(v -> 1., demand.power)
    demandconstraintsprices(demand, pricing)
end


"""
Represent time-of-use demand constraints for a BEV as a JuMP model.

See <https://github.nrel.gov/SIIP/dr-study-1/issues/26#issuecomment-22885> for pricing schedules.

# Arguments
- `demand  :: BevDemand{T,L}`: the BEV demand
- `daytime :: Bool`          : whether to use daytime (default) time-of-use
                               schedule instead of nightime ones
- `summer  :: Bool`          : whether to use a summer (default) time-of-use
                               schedule instead of a winter one

# Returns
- `model :: JuMP.Model`           : a JuMP model containing the constraints, where
                                    `charge` is the kWh charge during the time
                                    interval and `battery` is the batter level at
                                    the start of the interval and where the start
                                    of the intervals are given by `locations`
- `result() :: ChargingPlan{T,L}` : a function that returns the charging plan, 
                                    but which can only be called after the model
                                    has been solved
"""
function demandconstraintstou(demand :: BevDemand{T,L}; daytime = true :: Bool, summer = true :: Bool) where L where T <: TimeType
    # FIXME: This assumes a single-day simulation.
    pricing =
        if daytime
            TimeArray(
                         [Time(0), Time(9), Time(14), Time(18), Time(21), Time(23,59,59)],
                if summer 
                         [     4.,      8.,      14.,       8.,       4.,             4.]
                else
                         [     4.,      5.,       8.,       5.,       4.,             4.]
                end
            )
        else 
            TimeArray(
                         [Time(0), Time(7), Time(13), Time(20), Time(23), Time(23,59,59)],
                if summer
                         [    13.,     27.,      49.,      27.,      13.,            13.]
                else
                         [    13.,     21.,      34.,      21.,      13.,            13.]
                end
            )
        end
    demandconstraintsprices(demand, pricing)
end


"""
Represent demand constraints for a BEV as a JuMP model, minimizing the price paid.

# Arguments
- `demand :: BevDemand{T,L}`: the BEV demand
- `prices :: TimeArray{T}`  : the electricity prices

# Returns
- `model :: JuMP.Model`           : a JuMP model containing the constraints, where
                                    `charge` is the kWh charge during the time
                                    interval and `battery` is the batter level at
                                    the start of the interval and where the start
                                    of the intervals are given by `locations`
- `result() :: LocatedDemand{T,}` : a function that results the located demand,
                                    but which can only be called after the model
                                    has been solved

# Example
```
using Dates, GLPK, JuMP, PowerSystems, PowerSimulations, TimeSeries

example = BevDemand(
    TimeArray(
        [Time(0)          , Time(8)         , Time(9)              , Time(17)       , Time(18)         , Time(23,59,59)   ], # [h]
        [("Home #23", (ac=1.4, dc=0.)), ("Road #14", (ac=0., dc=0.)), ("Workplace #3", (ac=7.7, dc=0.)), ("Road #9", (ac=0., dc=0.)), ("Home #23", (ac=1.4, dc=0.)), ("Home #23", (ac=1.4, dc=0.))]  # [kW]
    ),
    TimeArray(
        [Time(0), Time(8), Time(9), Time(17), Time(18), Time(23,59,59)], # [h]
        [     0.,     10.,      0.,      11.,       0.,             0.]  # [kW]
    ),
    (min=0., max=40.), # [kWh]
    (ac=(min=0., max=20.), dc=(min=0., max=50.)), # [kW]
    (in=0.90, out=0.), # [kWh/kWh]
    nothing,
)

pricing = TimeArray([Time(0), Time(12)], [10., 3.])

constraints = demandconstraintsprices(example, pricing)
optimize!(constraints.model, with_optimizer(GLPK.Optimizer))
chargingplan = constraints.result()
```
"""
function demandconstraintsprices(demand :: BevDemand{T,L}, prices :: TimeArray{Float64,1,T,Array{Float64,1}}) where L where T <: TimeType

    # FIXME: Add DC constraints.

    eff = applyefficiencies(demand)

    onehour = Time(1) - Time(0)
    eff = applyefficiencies(demand)
    x = aligntimes(aligntimes(demand.locations, demand.power), prices)
    xt = timestamp(x)
    xv = values(x)

    NT = length(x)
    NP = NT - 1

    hour = map(t -> t.instant / onehour, xt)
    location = map(v -> v[1][1][1], xv)
    duration = (xt[2:NT] - xt[1:NP]) / onehour
    chargemin = duration .* map(v -> min(v[1][1][2].ac, demand.rate.ac.min), xv[1:NP])
    chargemax = duration .* map(v -> min(v[1][1][2].ac, demand.rate.ac.max), xv[1:NP])
    consumption = duration .* map(v -> v[1][2], xv[1:NP])
    price = map(v -> v[2], xv[1:NP])

    model = Model()

    chargevars = @variable(model, charge[1:NP])
    @constraint(model, chargeconstraint[i=1:NP], charge[i] <= chargemax[i])
    @constraint(model, dischargeconstraint[i=1:NP], charge[i] >= chargemin[i])

    batteryLevels = @variable(model, demand.capacity.min <= battery[1:NT] <= demand.capacity.max)
    if demand.timeboundary == nothing
        @constraint(model, boundaryconstraint, battery[1] == battery[NT])
    else
        @constraint(model, boundaryleftconstraint , demand.timeboundary[1] <= battery[1] <= demand.timeboundary[1])
        @constraint(model, boundaryrightconstraint, demand.timeboundary[2] <= battery[NT] <= demand.timeboundary[2])
    end

    @constraint(model, balanceconstraint[i=1:NP], battery[i+1] == battery[i] + charge[i] - consumption[i])

    @objective(model, Min, sum(price[i] * charge[i] for i = 1:NP))

    function result() ChargingPlan{T,L}
        TimeArray(
            xt,
            vcat(
                [(
                    location        = location[i]                             ,
                    duration        = duration[i]                             ,
                    load            = eff(JuMP.value(charge[i]) / duration[i]),
                    chargerate      = JuMP.value(charge[i]) / duration[i]     ,
                    maxchargerate   = chargemax[i]                            ,
                    consumptionrate = consumption[i] / duration[i]            ,
                    batterylevel    = JuMP.value(battery[i])                  ,
                ) for i in 1:NP],
                (
                    location        = location[NT]                            ,
                    duration        = NaN                                     ,
                    load            = NaN                                     ,
                    chargerate      = NaN                                     , 
                    maxchargerate   = NaN                                     ,
                    consumptionrate = NaN                                     ,
                    batterylevel    = JuMP.value(battery[NT])                 ,
                )
            )
        )
    end

    (
        model=model,
        result=result,
    )

end


"""
Represent demand constraints for a BEV Greedy charging scenario LP as a JuMP model, maximizing the BEV's battery level.

# Arguments
- `demand :: BevDemand{T,L}`: the BEV demand

# Returns
- `model :: JuMP.Model`           : a JuMP model containing the constraints, where
                                    `charge` is the kWh charge during the time
                                    interval and `battery` is the batter level at
                                    the start of the interval and where the start
                                    of the intervals are given by `locations`
- `result() :: ChargingPlan{T,L}` : a function that returns the charging plan, 
                                    but which can only be called after the model
                                    has been solved

"""
function demandconstraintsgreedy(demand :: BevDemand{T,L}) where L where T <: TimeType

    # FIXME: Add DC constraints.s

    eff = applyefficiencies(demand)

    onehour = Time(1) - Time(0)
    eff = applyefficiencies(demand)
    x = aligntimes(demand.locations, demand.power)
    xt = timestamp(x)
    xv = values(x)

    NT = length(x)
    NP = NT - 1

    hour = map(t -> t.instant / onehour, xt)
    location = map(v -> v[1][1], xv)
    duration = (xt[2:NT] - xt[1:NP]) / onehour
    chargemin = duration .* map(v -> min(v[1][2].ac, demand.rate.ac.min), xv[1:NP])
    chargemax = duration .* map(v -> min(v[1][2].ac, demand.rate.ac.max), xv[1:NP])
    consumption = duration .* map(v -> v[2], xv[1:NP])

    model = Model()

    chargevars = @variable(model, charge[1:NP])
    @constraint(model, chargeconstraint[   i=1:NP], charge[i] <= chargemax[i])
    @constraint(model, dischargeconstraint[i=1:NP], charge[i] >= chargemin[i])

    batteryLevels = @variable(model, demand.capacity.min <= battery[1:NT] <= demand.capacity.max)
    if demand.timeboundary == nothing
        @constraint(model, boundaryconstraint, battery[1] == battery[NT])
    else
        @constraint(model, boundaryleftconstraint , demand.timeboundary[1] <= battery[1 ] <= demand.timeboundary[1])
        @constraint(model, boundaryrightconstraint, demand.timeboundary[2] <= battery[NT] <= demand.timeboundary[2])
    end #Edit this timeboundary constraint for greedy charging?

    @constraint(model, balanceconstraint[i=1:NP], battery[i+1] == battery[i] + charge[i] - consumption[i])

    @objective(model, Max, sum(battery[i] for i = 1:NP))

    function result() ChargingPlan{T,L}
        TimeArray(
            xt,
            vcat(
                [(
                    location        = location[i]                             ,
                    duration        = duration[i]                             ,
                    load            = eff(JuMP.value(charge[i]) / duration[i]),
                    chargerate      = JuMP.value(charge[i]) / duration[i]     ,
                    maxchargerate   = chargemax[i]                            ,
                    consumptionrate = consumption[i] / duration[i]            ,
                    batterylevel    = JuMP.value(battery[i])                  ,
                ) for i in 1:NP],
                (
                    location        = location[NT]                            ,
                    duration        = NaN                                     ,
                    load            = NaN                                     ,
                    chargerate      = NaN                                     , 
                    maxchargerate   = NaN                                     ,
                    consumptionrate = NaN                                     ,
                    batterylevel    = JuMP.value(battery[NT])                 ,
                )
            )
        )
    end

    (
        model=model,
        result=result,
    )

end


"""
Represent demand constraints for a BEV full charge scenario LP as a JuMP model, minimizing the price paid while
constraining BEVs to charge continuously if not fully charged and charging is available.

# Arguments
- `demand :: BevDemand{T,L}`: the BEV demand

# Returns
- `model :: JuMP.Model`           : a JuMP model containing the constraints, where
                                    `charge` is the kWh charge during the time
                                    interval and `battery` is the batter level at
                                    the start of the interval and where the start
                                    of the intervals are given by `locations`
- `result() :: ChargingPlan{T,L}` : a function that returns the charging plan, 
                                    but which can only be called after the model
                                    has been solved

"""
function demandconstraintsfull(demand :: BevDemand{T,L}) where L where T <: TimeType
    pricing = map(v -> 1., demand.power)
    demandconstraintsfull(demand, pricing)
end


"""
Represent demand constraints for a BEV full charge scenario LP as a JuMP model, minimizing the price paid while
constraining BEVs to charge continuously if not fully charged and charging is available.

# Arguments
- `demand :: BevDemand{T,L}`: the BEV demand
- `prices :: TimeArray{T}`  : the electricity prices

# Returns
- `model :: JuMP.Model`           : a JuMP model containing the constraints, where
                                    `charge` is the kWh charge during the time
                                    interval and `battery` is the batter level at
                                    the start of the interval and where the start
                                    of the intervals are given by `locations`
- `result() :: ChargingPlan{T,L}` : a function that returns the charging plan, 
                                    but which can only be called after the model
                                    has been solved

"""
function demandconstraintsfull(demand :: BevDemand{T,L}, prices :: TimeArray{Float64,1,T,Array{Float64,1}}) where L where T <: TimeType

    # FIXME: Add DC constraints.

    eff = applyefficiencies(demand)

    onehour = Time(1) - Time(0)
    eff = applyefficiencies(demand)
    x = aligntimes(aligntimes(demand.locations, demand.power), prices)
    xt = timestamp(x)
    xv = values(x)

    NT = length(x)
    NP = NT - 1

    hour = map(t -> t.instant / onehour, xt)
    location = map(v -> v[1][1][1], xv)
    duration = (xt[2:NT] - xt[1:NP]) / onehour
    chargemin = duration .* map(v -> min(v[1][1][2].ac, demand.rate.ac.min), xv[1:NP])
    chargemax = duration .* map(v -> min(v[1][1][2].ac, demand.rate.ac.max), xv[1:NP])
    consumption = duration .* map(v -> v[1][2], xv[1:NP])
    price = map(v -> v[2], xv[1:NP])

    model = Model()

    chargevars = @variable(model, charge[1:NP])
    @constraint(model, chargeconstraint[i=1:NP], charge[i] <= chargemax[i])
    @constraint(model, dischargeconstraint[i=1:NP], charge[i] >= chargemin[i])

    batteryLevels = @variable(model, demand.capacity.min <= battery[1:NT] <= demand.capacity.max)
    if demand.timeboundary == nothing
        @constraint(model, boundaryconstraint, battery[1] == battery[NT])
    else
        @constraint(model, boundaryleftconstraint , demand.timeboundary[1] <= battery[1] <= demand.timeboundary[1])
        @constraint(model, boundaryrightconstraint, demand.timeboundary[2] <= battery[NT] <= demand.timeboundary[2])
    end

    @constraint(model, balanceconstraint[i=1:NP], battery[i+1] == battery[i] + charge[i] - consumption[i])

    #Constraints to force full charging if available whenever BEV charging has begun
        #Define binary indicator variable
    @variable(model, indicator1[1:NP], Bin)
    @variable(model, indicator2[1:NP], Bin)
    @variable(model, indicator3[1:NP], Bin)
    #Three conditions must be met to force charging in the succeeding time interval:

    #1. (Charge from the original timer interval) > 0
    @constraint(model, origChargeGreater[i=1:(NP-1)], charge[i] >= 0 + 0.001 - 100(1-indicator1[i+1]))
    @constraint(model, origChargeLess[i=1:(NP-1)], charge[i] <= 0 + 100(indicator1[i+1]))
    #2. Charging opportunity must be available, or chargemax > 0
    @constraint(model, chargeAvailGreater[i=1:(NP-1)], chargemax[i+1] >= 0 + 0.001 - 100(1-indicator2[i+1]))
    @constraint(model, chargeAvailLess[i=1:(NP-1)], chargemax[i+1] >= 0 + 100(indicator2[i+1]))
    #3. Battery is not fully charged, or (capacity - battery) > 0   !!CHECK!!
    @constraint(model, batteryFullGreater[i=1:(NP-1)], demand.capacity.max - battery[i+1] >= 0 + 0.001 - 200(1-indicator3[i+1]))
    @constraint(model, batteryFullLess[i=1:(NP-1)], demand.capacity.max - battery[i+1] <= 0 + 200(indicator3[i+1]))

    #Combine the 3 conditions into one indicator variable
    @variable(model, indicator[1:NP])
    @constraint(model, totalIndicator[i=1:NP], indicator[i] == indicator1[i] + indicator2[i] + indicator3[i])

    #Force charging if the indicator variable value in that succeeding time interval is 1. Otherwise, enforce nothing.
    @constraint(model, conditionsIndGreater[i=1:(NP-1)], charge[i+1] >= 0 + 0.001 - 100(3-indicator[i+1]))
    @constraint(model, conditionsIndLess[i=1:(NP-1)], charge[i+1] <= 0 + 100*indicator[i+1])

    @objective(model, Min, sum(price[i] * charge[i] for i = 1:NP))

    #Contains optimization charging results with charging rate from charger during each time interval
    function result() ChargingPlan{T,L}
        TimeArray(
            xt,
            vcat(
                [(
                    location        = location[i]                             ,
                    duration        = duration[i]                             ,
                    load            = eff(JuMP.value(charge[i]) / duration[i]),
                    chargerate      = JuMP.value(charge[i]) / duration[i]     ,
                    maxchargerate   = chargemax[i]                            ,
                    consumptionrate = consumption[i] / duration[i]            ,
                    batterylevel    = JuMP.value(battery[i])                  ,
                ) for i in 1:NP],
                (
                    location        = location[NT]                            ,
                    duration        = NaN                                     ,
                    load            = NaN                                     ,
                    chargerate      = NaN                                     , 
                    maxchargerate   = NaN                                     ,
                    consumptionrate = NaN                                     ,
                    batterylevel    = JuMP.value(battery[NT])                 ,
                )
            )
        )
    end

    (
        model=model,
        result=result,
    )

end
