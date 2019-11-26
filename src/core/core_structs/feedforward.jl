abstract type AbstractAffectFeedForward end

struct UpperBoundFF <: AbstractAffectFeedForward
    vars_prefix::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
end

UpperBoundFF(var::Symbol,
             cache::Union{Nothing, Type{<:AbstractCache}}=nothing) = UpperBoundFF([var], cache)

get_vars_prefix(p::UpperBoundFF) = p.vars_prefix

struct RangeFF <: AbstractAffectFeedForward
    lb_vars_prefix::Vector{Symbol}
    ub_vars_prefix::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
end

RangeFF(var_lb::Symbol,
        var_ub::Symbol,
        cache::Union{Nothing, Type{<:AbstractCache}}=nothing) = RangeFF([var_lb], [var_ub], cache)

get_vars_prefix(p::RangeFF) = (p.lb_var_prefix, p.lb_var_prefix)

struct SemiContinuousFF <: AbstractAffectFeedForward
    vars_prefix::Vector{Symbol}
    bin_prefix::Symbol
    cache::Union{Nothing, Type{<:AbstractCache}}
end

SemiContinuousFF(var::Symbol,
    bin_var::Symbol,
    cache::Union{Nothing, Type{<:AbstractCache}}=nothing) = SemiContinuousFF([var], bin_var, cache)

get_bin_prefix(p::SemiContinuousFF) = p.bin_prefix
get_vars_prefix(p::SemiContinuousFF) = p.vars_prefix
