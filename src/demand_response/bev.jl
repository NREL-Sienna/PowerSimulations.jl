# Response for demands like BEVs, where there is some flexbility, but also hard constraints.


# Import modules.

using Dates, JuMP, TimeSeries

import PowerSystems: BevDemand, LocatedDemand, aligntimes


"""
Apply efficiency factors to relate energy at the vehicle to energy at the charger.

# Arguments
- `demand :: BevDemand{T,L}`: the demand

# Returns
- a function that converts energy at the vehicle to energy at the charger
"""
function applyefficiencies(demand :: BevDemand{T,L}) where L where T <: TimeType
    function f(x)
        x > 0 ? x / demand.efficiency.in : x * demand.efficiency.out
    end
    f
end


"""
Represent demand constraints for a BEV as a JuMP model.

# Arguments
- `demand :: BevDemand{T,L}`: the BEV demand

# Returns
- `locations :: TimeArray{T,L}`   : location of the BEV during each time interval
- `model :: JuMP.Model`           : a JuMP model containing the constraints, where
                                    `charge` is the kWh charge during the time
                                    interval and `battery` is the batter level at
                                    the start of the interval and where the start
                                    of the intervals are given by `locations`
- `result() :: LocatedDemand{T,}` : a function that results the located demand,
                                    but which can only be called after the model
                                    has been solved
"""
function demandconstraints(demand :: BevDemand{T,L}) where L where T <: TimeType
    pricing = map(v -> 1., demand.power)
    demandconstraints(demand, pricing)
end


"""
Represent demand constraints for a BEV as a JuMP model, minimizing the price paid.

# Arguments
- `demand :: BevDemand{T,L}`: the BEV demand
- `prices :: TimeArray{T}`  : the electricity prices

# Returns
- `locations :: TimeArray{T,L}`   : location of the BEV during each time interval
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

constraints = demandconstraints(example, pricing)
optimize!(constraints.model, with_optimizer(GLPK.Optimizer))
locateddemands = constraints.result()
```
"""


function demandconstraints(demand :: BevDemand{T,L}, prices :: TimeArray{Float64,1,T,Array{Float64,1}}) where L where T <: TimeType

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

    #Day vs Night charging constraint
    #@constraint(model, daycharging[i=1:NP], charge[i] == 0)

    batteryLevels = @variable(model, demand.capacity.min <= battery[1:NT] <= demand.capacity.max)
    if demand.timeboundary == nothing
        @constraint(model, boundaryconstraint, battery[1] == battery[NT])
    else
        @constraint(model, boundaryleftconstraint , demand.timeboundary[1] <= battery[1] <= demand.timeboundary[1])
        @constraint(model, boundaryrightconstraint, demand.timeboundary[2] <= battery[NT] <= demand.timeboundary[2])
    end

    @constraint(model, balanceconstraint[i=1:NP], battery[i+1] == battery[i] + charge[i] - consumption[i])

    @objective(model, Min, sum(price[i] * charge[i] for i = 1:NP))
    #print(battery[1].val())
    #Contains optimization charging results with charging rate from charger during each time interval
    function result() :: LocatedDemand{T,L}
        TimeArray(
            xt,
            collect(
                zip(
                    location,
                    vcat(
                        eff.(JuMP.value.(chargevars) ./ duration),
                        NaN
                    )
                )
            )
        )
    end

    #Contains optimization charging results with charge used by car during each time interval
    function result2() :: LocatedDemand{T,L}
        TimeArray(
            xt,
            collect(
                zip(
                    location,
                    vcat(
                        JuMP.value.(chargevars),
                        NaN
                    )
                )
            )
        )
    end

    #Constains optimization results for the battery levels of a car during each time interval.
    #Note that the battery variable goes up to NT, but here we use 1:NP
    function result3() :: LocatedDemand{T,L}
        TimeArray(
            xt,
            collect(
                zip(
                    location,
                    vcat(
                        JuMP.value.(batteryLevels)[1:NT]
                    )
                )
            )
        )
    end

    #Return Objective Value
    function objectiveValue()
        JuMP.objective_value(model)
    end

    #Return LP Termination Status
    function LPTerminationStatus()
        JuMP.termination_status(model)
    end

    (
        locations=TimeArray(xt, location),
        model=model,
        result=result,
        result2=result2,
        result3=result3,
        objectiveValue=objectiveValue,
        termStatus=LPTerminationStatus,
        ConsumpAndChargeMax=hcat([consumption], [chargemax]),
        batteryCapacity=[demand.capacity.min, demand.capacity.max],
        LPModel=model
    )

end


"""
Greedy charging LP
"""
function demandconstraints2(demand :: BevDemand{T,L}, prices :: TimeArray{Float64,1,T,Array{Float64,1}}) where L where T <: TimeType

    # FIXME: Add DC constraints.s


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


    model = Model()


    chargevars = @variable(model, charge[1:NP])
    @constraint(model, chargeconstraint[   i=1:NP], charge[i] <= chargemax[i])
    @constraint(model, dischargeconstraint[i=1:NP], charge[i] >= chargemin[i])

    #Day vs Night charging constraint
    #@constraint(model, daycharging[i=1:NP], charge[i] == 0)

    batteryLevels = @variable(model, demand.capacity.min <= battery[1:NT] <= demand.capacity.max)
    if demand.timeboundary == nothing
        @constraint(model, boundaryconstraint, battery[1] == battery[NT])
    else
        @constraint(model, boundaryleftconstraint , demand.timeboundary[1] <= battery[1 ] <= demand.timeboundary[1])
        @constraint(model, boundaryrightconstraint, demand.timeboundary[2] <= battery[NT] <= demand.timeboundary[2])
    end #Edit this timeboundary constraint for greedy charging?

    @constraint(model, balanceconstraint[i=1:NP], battery[i+1] == battery[i] + charge[i] - consumption[i])

    @objective(model, Max, sum(battery[i] for i = 1:NP))
    #print(battery[1].val())
    #Contains optimization charging results with charging rate from charger during each time interval
    function result() :: LocatedDemand{T,L}
        TimeArray(
            xt,
            collect(
                zip(
                    location,
                    vcat(
                        eff.(JuMP.value.(chargevars) ./ duration),
                        NaN
                    )
                )
            )
        )
    end

    #Contains optimization charging results with charge used by car during each time interval
    function result2() :: LocatedDemand{T,L}
        TimeArray(
            xt,
            collect(
                zip(
                    location,
                    vcat(
                        JuMP.value.(chargevars),
                        NaN
                    )
                )
            )
        )
    end

    #Constains optimization results for the battery levels of a car during each time interval.
    #Note that the battery variable goes up to NT, but here we use 1:NP
    function result3() :: LocatedDemand{T,L}
        TimeArray(
            xt,
            collect(
                zip(
                    location,
                    vcat(
                        JuMP.value.(batteryLevels)[1:NT]
                    )
                )
            )
        )
    end

    #Return Objective Value
    function objectiveValue()
        JuMP.objective_value(model)
    end

    #Return LP Termination Status
    function LPTerminationStatus()
        JuMP.termination_status(model)
    end

    (
        locations=TimeArray(xt, location),
        model=model,
        result=result,
        result2=result2,
        result3=result3,
        termStatus=LPTerminationStatus,
        ConsumpAndChargeMax=hcat([consumption], [chargemax]),
        batteryCapacity=[demand.capacity.min, demand.capacity.max]
    )

end


"""
Greedy Charging procedural approach
"""
function greedyChargingDemand(demand :: BevDemand{T,L}, prices :: TimeArray{Float64,1,T,Array{Float64,1}}) where L where T <: TimeType
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

    #Initialize battery levels
    battery = [demand.capacity.max] #Initial and final battery values?
    charge = []

    #Find value of greatest consumption in back-to-back time interval
    consumpMax = [0]
    consumpCompare = [0]
    for i in 1:95
        print(consumption[i])
        if i == 1
            if consumption[1] > 0
                consumpCompare[1] += consumption[1]
            end
        else
            if consumption[i] > 0 && consumption[i-1] == 0
                consumpCompare[1] += consumption[i]
            elseif consumption[i] > 0 && consumption[i-1] > 0
                consumpCompare[1] += consumption[i]
            elseif consumption[i] == 0
                consumpMax[1] = max(consumpMax[1], consumpCompare[1])
                consumpCompare[1] = 0
            end
        end
    end
    print(string(consumpMax[1], " "))
    #Attempt greedy charging procedure with inital battery level at maximum capacity
    for i in 1:95
        if (battery[i] < demand.capacity.max) && (chargemax[i] > 0)
            if (battery[i] + chargemax[i]) > demand.capacity.max
                append!(battery, demand.capacity.max)
                append!(charge, (demand.capacity.max - battery[i]))
            else
                append!(battery, battery[i] + chargemax[i])
                append!(charge, chargemax[i])
            end
        elseif (battery[i] == demand.capacity.max) && (consumption[i] == 0)
            append!(battery, battery[i])
            append!(charge, 0.0)
        elseif (chargemax[i] == 0.0) && (consumption[i] == 0)
            append!(battery, battery[i])
            append!(charge, 0.0)
        elseif consumption[i] > 0
            append!(battery, battery[i] - consumption[i])
            append!(charge, 0.0)
        end
    end

    if length(battery[battery .< 0]) > 0
        battery = []
        for i in 1:96
            append!(battery, NaN)
        end

        charge = []
        for i in 1:95
            append!(charge, NaN)
        end

    elseif (sum(consumption) > sum(chargemax)) && (length(battery[battery .< 0]) == 0)
        battery = []
        for i in 1:96
            append!(battery, NaN)
        end

        charge = []
        for i in 1:95
            append!(charge, NaN)
        end

    elseif (battery[96] < demand.capacity.max) && length(battery[battery .< 0]) == 0 && sum(consumption) <= sum(chargemax)
        #Create curve ignoring maximum battery capacity
        battery = [demand.capacity.max]
        charge = []
        for i in 1:95
            if chargemax[i] > 0
                append!(battery, battery[i] + chargemax[i])
                append!(charge, chargemax[i])
            elseif consumption[i] > 0
                append!(battery, battery[i] - consumption[i])
                append!(charge, 0.0)
            elseif (chargemax[i] == 0.0) && (consumption[i] == 0)
                append!(battery, battery[i])
                append!(charge, 0.0)
            end
        end

        #Check if there is a starting charge value for which the ending charge value can be equal.
        if consumpMax[1] > (demand.capacity.max - demand.capacity.min)
            battery = []
            for i in 1:96
                append!(battery, NaN)
            end

            charge = []
            for i in 1:95
                append!(charge, NaN)
            end

        elseif battery[96] >= battery[1] && consumpMax[1] <= (demand.capacity.max - demand.capacity.min)
            #Shift data down such that the maximum battery level lies along the
            #maximum battery capacity line.
            shift = maximum(battery) - demand.capacity.max
            battery = [battery[96] - shift]
            charge = []
            println(string("initial:", battery[96] - shift))
            println(string("batteryCap", demand.capacity.max))

            #Apply greedy charging procedure with new inital battery level
            for i in 1:95
                if (battery[i] < demand.capacity.max) && (chargemax[i] > 0)
                    if (battery[i] + chargemax[i]) > demand.capacity.max
                        append!(battery, demand.capacity.max)
                        append!(charge, (demand.capacity.max - battery[i]))
                    else
                        append!(battery, battery[i] + chargemax[i])
                        append!(charge, chargemax[i])
                    end
                elseif (battery[i] == demand.capacity.max) && (consumption[i] == 0)
                    append!(battery, battery[i])
                    append!(charge, 0.0)
                elseif (chargemax[i] == 0.0) && (consumption[i] == 0)
                    append!(battery, battery[i])
                    append!(charge, 0.0)
                elseif consumption[i] > 0
                    append!(battery, battery[i] - consumption[i])
                    append!(charge, 0.0)
                end
            end
        end
    end

    convert(Array{Float64}, battery)
    convert(Array{Float64}, charge)
    #Contains optimization charging results with charging rate from charger during each time interval
    function result()
        TimeArray(
            xt,
            collect(
                zip(
                    location,
                    vcat(
                        eff.(charge ./ duration),
                        NaN
                    )
                )
            )
        )
    end

    #Contains optimization charging results with charge used by car during each time interval
    function result2()
        TimeArray(
            xt,
            collect(
                zip(
                    location,
                    vcat(
                        charge,
                        NaN
                    )
                )
            )
        )
    end

    #Constains optimization results for the battery levels of a car during each time interval.
    #Note that the battery variable goes up to NT, but here we use 1:NP
    function result3()
        TimeArray(
            xt,
            collect(
                zip(
                    location,
                    vcat(
                        battery
                    )
                )
            )
        )
    end

    (
        locations=TimeArray(xt, location),
        result=result,
        result2=result2,
        result3=result3,
        objectiveValue=sum(charge),
        ConsumpAndChargeMax=hcat([consumption], [chargemax]),
        batteryCapacity=[demand.capacity.min, demand.capacity.max],
    )

end


"""Full charge each charge time"""
function fullChargeDemand(demand :: BevDemand{T,L}, prices :: TimeArray{Float64,1,T,Array{Float64,1}}) where L where T <: TimeType

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
    function result() :: LocatedDemand{T,L}
        TimeArray(
            xt,
            collect(
                zip(
                    location,
                    vcat(
                        eff.(JuMP.value.(chargevars) ./ duration),
                        NaN
                    )
                )
            )
        )
    end

    #Contains optimization charging results with charge used by car during each time interval
    function result2() :: LocatedDemand{T,L}
        TimeArray(
            xt,
            collect(
                zip(
                    location,
                    vcat(
                        JuMP.value.(chargevars),
                        NaN
                    )
                )
            )
        )
    end

    #Constains optimization results for the battery levels of a car during each time interval.
    #Note that the battery variable goes up to NT, but here we use 1:NP
    function result3() :: LocatedDemand{T,L}
        TimeArray(
            xt,
            collect(
                zip(
                    location,
                    vcat(
                        JuMP.value.(batteryLevels)[1:NT]
                    )
                )
            )
        )
    end

    #Return Objective Value
    function objectiveValue()
        JuMP.objective_value(model)
    end

    #Return LP Termination Status
    function LPTerminationStatus()
        JuMP.termination_status(model)
    end

    (
        locations=TimeArray(xt, location),
        model=model,
        result=result,
        result2=result2,
        result3=result3,
        objectiveValue=objectiveValue,
        termStatus=LPTerminationStatus,
        ConsumpAndChargeMax=hcat([consumption], [chargemax]),
        batteryCapacity=[demand.capacity.min, demand.capacity.max]
    )

end
