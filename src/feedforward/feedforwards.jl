function _get_optimization_container_key(
    ::T,
    ::Type{U},
) where {T <: AuxVariableType, U <: PSY.Component}
    return AuxVariableKey(T, U)
end

function _get_optimization_container_key(
    ::T,
    ::Type{U},
) where {T <: VariableType, U <: PSY.Component}
    return VariableKey(T, U)
end

function _get_optimization_container_key(
    ::T,
    ::Type{U},
) where {T <: ParameterType, U <: PSY.Component}
    return ParameterKey(T, U)
end

function _get_optimization_container_key(
    ::T,
    ::Type{U},
) where {T <: ConstraintType, U <: PSY.Component}
    return ConstraintKey(T, U)
end

function get_optimization_container_key(ff::AbstractAffectFeedForward)
    return ff.optimization_container_key
end

function get_affected_values(ff::AbstractAffectFeedForward)
    return ff.affected_values
end

"""
Adds an upper bound constraint to a variable.
"""
struct UpperBoundFeedForward <: AbstractAffectFeedForward
    optimization_container_key::OptimizationContainerKey
    affected_values::Vector
    function UpperBoundFeedForward(;
        component_type::Type{<:PSY.Component},
        source::Type{T},
        affected_values::Vector{DataType},
    ) where {T}
        values = Vector(undef, length(affected_values))
        for (ix, v) in enumerate(affected_values)
            if v <: VariableType
                values[ix] = _get_optimization_container_key(v(), component_type)
            else
                error(
                    "UpperBoundFeedForward is only compatible with VariableType affected values",
                )
            end
        end
        new(_get_optimization_container_key(T(), component_type), values)
    end
end

get_default_parameter_type(::UpperBoundFeedForward, _) = UpperBoundValueParameter()

"""
Adds a lower bound constraint to a variable.
"""
struct LowerBoundFeedForward <: AbstractAffectFeedForward
    optimization_container_key::OptimizationContainerKey
    affected_values::Vector{<:OptimizationContainerKey}
    function LowerBoundFeedForward(;
        component_type::Type{<:PSY.Component},
        source::Type{T},
        affected_values::Vector{DataType},
    ) where {T}
        values = Vector{VariableKey}(undef, length(affected_values))
        for (ix, v) in enumerate(affected_values)
            if v <: VariableType
                values[ix] = _get_optimization_container_key(v(), component_type)
            else
                error(
                    "LowerBoundFeedForward is only compatible with VariableType affected values",
                )
            end
        end
        new(_get_optimization_container_key(T(), component_type), values)
    end
end

get_default_parameter_type(::LowerBoundFeedForward, _) = LowerBoundValueParameter()

"""
Adds a constraint to make the bounds of a variable 0.0. Effectively allows to "turn off" a value.
"""
struct SemiContinuousFeedForward <: AbstractAffectFeedForward
    optimization_container_key::OptimizationContainerKey
    affected_values::Vector{<:OptimizationContainerKey}
    function SemiContinuousFeedForward(;
        component_type::Type{<:PSY.Component},
        source::Type{T},
        affected_values::Vector{DataType},
    ) where {T}
        values = Vector{VariableKey}(undef, length(affected_values))
        for (ix, v) in enumerate(affected_values)
            if v <: VariableType
                values[ix] = _get_optimization_container_key(v(), component_type)
            else
                error(
                    "SemiContinuousFeedForward is only compatible with VariableType affected values",
                )
            end
        end
        new(_get_optimization_container_key(T(), component_type), values)
    end
end

get_default_parameter_type(::SemiContinuousFeedForward, _) = OnStatusParameter()

"""
Adds a constraint to limit the sum of a variable over the number of periods to the source value
"""
struct IntegralLimitFeedForward <: AbstractAffectFeedForward
    optimization_container_key::OptimizationContainerKey
    affected_values::Vector{<:OptimizationContainerKey}
    number_of_periods::Int
    function IntegralLimitFeedForward(;
        component_type::Type{<:PSY.Component},
        source::Type{T},
        affected_values::Vector{DataType},
        number_of_periods::Int,
    ) where {T}
        values = Vector{VariableKey}(undef, length(affected_values))
        for (ix, v) in enumerate(affected_values)
            if v <: VariableType
                values[ix] = _get_optimization_container_key(v(), component_type)
            else
                error(
                    "IntegralLimitFeedForward is only compatible with VariableType or ParamterType affected values",
                )
            end
        end
        new(_get_optimization_container_key(T(), component_type), values, number_of_periods)
    end
end

get_default_parameter_type(::IntegralLimitFeedForward, _) = OnStatusParameter()

"""
Fixes a Variable or Parameter Value in the model. Is the only Feed Forward that can be used
with a Parameter or a Variable as the affected value.
"""
struct FixValueFeedForward <: AbstractAffectFeedForward
    optimization_container_key::OptimizationContainerKey
    affected_values::Vector
    function FixValueFeedForward(;
        component_type::Type{<:PSY.Component},
        source::Type{T},
        affected_values::Vector{DataType},
    ) where {T}
        values = Vector(undef, length(affected_values))
        for (ix, v) in enumerate(affected_values)
            if v <: VariableType || v <: ParameterType
                values[ix] = _get_optimization_container_key(v(), component_type)
            else
                error(
                    "UpperBoundFeedForward is only compatible with VariableType affected values",
                )
            end
        end
        new(_get_optimization_container_key(T(), component_type), values)
    end
end

get_default_parameter_type(::FixValueFeedForward, _) = OnStatusParameter()
