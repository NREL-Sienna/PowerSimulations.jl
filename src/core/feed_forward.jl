struct UpperBoundFF <: AbstractAffectFeedForward
    variable_from_stage::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
end

function UpperBoundFF(;variable_from_stage, affected_variables)
    return UpperBoundFF(variable, affected_variables, nothing)
end

get_variable_from_stage(p::UpperBoundFF) = p.binary_from_stage

struct RangeFF <: AbstractAffectFeedForward
    variable_from_stage_ub::Symbol
    variable_from_stage_lb::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
end

function RangeFF(;variable_from_stage_ub, affected_variables_lb, affected_variables)
    return RangeFF(binary_from_stage, affected_variables, nothing)
end

get_bounds_from_stage(p::RangeFF) = (p.variable_from_stage_lb, p.variable_from_stage_lb)

struct SemiContinuousFF <: AbstractAffectFeedForward
    binary_from_stage::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
end

function SemiContinuousFF(;binary_from_stage, affected_variables)
    return SemiContinuousFF(binary_from_stage, affected_variables, nothing)
end

get_binary_from_stage(p::SemiContinuousFF) = p.binary_from_stage

get_affected_variables(p::AbstractAffectFeedForward) = p.affected_variables
