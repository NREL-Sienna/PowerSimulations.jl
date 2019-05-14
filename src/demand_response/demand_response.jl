# Abstract representation of demand.

#=
Demands are parameterized in terms of how they are registered in time and where
they are located.  Functions will be provided to convert `Demand` into the
appropriate type `StaticLoad`, `InterruptibleLoad`, etc. that is properly
located at a `Bus`.
=#


# Import packages.

using Dates, TimeSeries

import PowerSystems: Demand


"""
Represent demand constraints as a JuMP model.

This must be implemented by subtypes of `Demand`.

# Arguments
- `demand :: Demand{T,L}`: the demand

# Returns
- `locations :: TimeArray{T,L}`   : location of the demand during each time interval
- `model :: JuMP.Model`           : a JuMP model containing the constraints`
- `result() :: LocatedDemand{T,}` : a function that results the located demand,
                                    but which can only be called after the model
                                    has been solved
"""
function demandconstraints(demand :: Demand{T,L}) where L where T <: TimeType
end


"""
Represent demand constraints as a JuMP model, minimizing the price paid.

This must be implemented by subtypes of `Demand`.

# Arguments
- `demand :: Demand{T,L}` : the demand
- `prices :: TimeArray{T}`: the electricity prices

# Returns
- `locations :: TimeArray{T,L}`   : location of the demand during each time interval
- `model :: JuMP.Model`           : a JuMP model containing the constraints`
- `result() :: LocatedDemand{T,}` : a function that results the located demand,
                                    but which can only be called after the model
                                    has been solved
"""
function demandconstraints(demand :: Demand{T,L}, prices :: TimeArray{Float64,1,T,Array{Float64,1}}) where L where T <: TimeType
end
