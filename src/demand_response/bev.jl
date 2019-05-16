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
function demandconstraints2(demand :: BevDemand{T,L}, prices :: TimeArray{Float64,1,T,Array{Float64,1}}) where L where T <: TimeType

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
    @constraint(model, chargeconstraint[   i=1:NP], charge[i] <= chargemax[i])
    @constraint(model, dischargeconstraint[i=1:NP], charge[i] >= chargemin[i])

    @variable(model, demand.capacity.min <= battery[1:NT] <= demand.capacity.max)
    if demand.timeboundary == nothing
        @constraint(model, boundaryconstraint, battery[1] == battery[NT])
    else
        @constraint(model, boundaryleftconstraint , demand.timeboundary[1] <= battery[1 ] <= demand.timeboundary[1])
        @constraint(model, boundaryrightconstraint, demand.timeboundary[2] <= battery[NT] <= demand.timeboundary[2])
    end

    @constraint(model, balanceconstraint[i=1:NP], battery[i+1] == battery[i] + charge[i] - consumption[i])

    @objective(model, Min, sum(price[i] * charge[i] for i = 1:NP))

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

    (
        locations=TimeArray(xt, location),
        model=model,
        result=result
    )

end
