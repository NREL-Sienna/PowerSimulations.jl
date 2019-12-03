abstract type AbstractAffectFeedForward end

struct UpperBoundFF <: AbstractAffectFeedForward
    name::Symbol
    variable_from_stage::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
end

function UpperBoundFF(name, ;variable_from_stage, affected_variables)
    return UpperBoundFF(name, variable, affected_variables, nothing)
end

get_variable_from_stage(p::UpperBoundFF) = p.binary_from_stage

struct RangeFF <: AbstractAffectFeedForward
    name::Symbol
    variable_from_stage_ub::Symbol
    variable_from_stage_lb::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
end

function RangeFF(name ;variable_from_stage_ub, affected_variables_lb, affected_variables)
    return RangeFF(name, binary_from_stage, affected_variables, nothing)
end

get_bounds_from_stage(p::RangeFF) = (p.variable_from_stage_lb, p.variable_from_stage_lb)

struct SemiContinuousFF <: AbstractAffectFeedForward
    name::Symbol
    binary_from_stage::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
end

function SemiContinuousFF(name ;binary_from_stage, affected_variables)
    return SemiContinuousFF(name, binary_from_stage, affected_variables, nothing)
end

get_binary_from_stage(p::SemiContinuousFF) = p.binary_from_stage

get_affected_variables(p::AbstractAffectFeedForward) = p.affected_variables
