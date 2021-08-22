struct UpperBoundFF <: AbstractAffectFeedForward
    device_type::Type{<:PSY.Component}
    variable_source_problem::Type{<:VariableType}
    affected_variables::Vector{DataType}
    cache::Union{Nothing, Type{<:AbstractCache}}
    function UpperBoundFF(;
        device_type::Type{<:PSY.Component},
        variable_source_problem::Type{<:VariableType},
        affected_variables::Vector{DataType},
        cache::Union{Nothing, Type{<:AbstractCache}} = nothing,
    )
        new(device_type, variable_source_problem, affected_variables, cache)
    end
end

get_variable_source_problem_key(p::UpperBoundFF) =
    VariableKey(p.variable_source_problem, p.device_type)

struct SemiContinuousFF <: AbstractAffectFeedForward
    device_type::Type{<:PSY.Component}
    binary_source_problem::Type{<:VariableType}
    affected_variables::Vector{DataType}
    cache::Union{Nothing, Type{<:AbstractCache}}
    function SemiContinuousFF(;
        device_type::Type{<:PSY.Component},
        binary_source_problem::Type{<:VariableType},
        affected_variables::Vector{DataType},
        cache::Union{Nothing, Type{<:AbstractCache}} = nothing,
    )
        new(device_type, binary_source_problem, affected_variables, cache)
    end
end

get_binary_source_problem_key(p::SemiContinuousFF) =
    VariableKey(p.binary_source_problem, p.device_type)

function get_affected_variables(p::AbstractAffectFeedForward)
    return [VariableKey(a, p.device_type) for a in p.affected_variables]
end

struct IntegralLimitFF <: AbstractAffectFeedForward
    device_type::Type{<:PSY.Component}
    variable_source_problem::Type{<:VariableType}
    affected_variables::Vector{DataType}
    cache::Union{Nothing, Type{<:AbstractCache}}
    function IntegralLimitFF(;
        device_type::Type{<:PSY.Component},
        variable_source_problem::Type{<:VariableType},
        affected_variables::Vector{DataType},
        cache::Union{Nothing, Type{<:AbstractCache}} = nothing,
    )
        new(device_type, variable_source_problem, affected_variables, cache)
    end
end

get_variable_source_problem_key(p::IntegralLimitFF) =
    VariableKey(p.variable_source_problem, p.device_type)

struct ParameterFF <: AbstractAffectFeedForward
    device_type::Type{<:PSY.Component}
    variable_source_problem::Type{<:VariableType}
    affected_parameters::Vector
    function ParameterFF(;
        device_type::Type{<:PSY.Component},
        variable_source_problem::Type{<:VariableType},
        affected_parameters::Vector,
    )
        new(device_type, variable_source_problem, affected_parameters)
    end
end

struct RangeFF <: AbstractAffectFeedForward
    variable_source_problem_ub::Symbol
    variable_source_problem_lb::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
    function RangeFF(
        variable_source_problem_ub::AbstractString,
        variable_source_problem_lb::AbstractString,
        affected_variables::Vector{<:AbstractString},
        cache::Union{Nothing, Type{<:AbstractCache}},
    )
        new(
            Symbol(variable_source_problem_ub),
            Symbol(variable_source_problem_lb),
            Symbol.(affected_variables),
            cache,
        )
    end
end

function RangeFF(;
    variable_source_problem_ub,
    variable_source_problem_lb,
    affected_variables,
)
    return RangeFF(
        variable_source_problem_ub,
        variable_source_problem_lb,
        affected_variables,
        nothing,
    )
end

get_bounds_source_problem(p::RangeFF) =
    (p.variable_source_problem_lb, p.variable_source_problem_lb)
