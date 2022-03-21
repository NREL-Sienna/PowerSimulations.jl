function get_affected_values(ff::AbstractAffectFeedforward)
    return ff.affected_values
end

function attach_feedforward!(model, ff::T) where {T <: AbstractAffectFeedforward}
    if !isempty(model.feedforwards)
        ff_k = [get_optimization_container_key(v) for v in model.feedforwards if isa(v, T)]
        if get_optimization_container_key(ff) ∈ ff_k
            return
        end
    end
    push!(model.feedforwards, ff)
    return
end

function get_component_type(ff::AbstractAffectFeedforward)
    return get_component_type(get_optimization_container_key(ff))
end

"""
Adds an upper bound constraint to a variable.
"""
struct UpperBoundFeedforward <: AbstractAffectFeedforward
    optimization_container_key::OptimizationContainerKey
    affected_values::Vector
    function UpperBoundFeedforward(;
        component_type::Type{<:PSY.Component},
        source::Type{T},
        affected_values::Vector{DataType},
        meta=CONTAINER_KEY_EMPTY_META,
    ) where {T}
        values_vector = Vector(undef, length(affected_values))
        for (ix, v) in enumerate(affected_values)
            if v <: VariableType
                values_vector[ix] =
                    get_optimization_container_key(v(), component_type, meta)
            else
                error(
                    "UpperBoundFeedforward is only compatible with VariableType affected values",
                )
            end
        end
        new(get_optimization_container_key(T(), component_type, meta), values_vector)
    end
end

get_default_parameter_type(::UpperBoundFeedforward, _) = UpperBoundValueParameter()
get_optimization_container_key(ff::UpperBoundFeedforward) = ff.optimization_container_key

"""
Adds a lower bound constraint to a variable.
"""
struct LowerBoundFeedforward <: AbstractAffectFeedforward
    optimization_container_key::OptimizationContainerKey
    affected_values::Vector{<:OptimizationContainerKey}
    function LowerBoundFeedforward(;
        component_type::Type{<:PSY.Component},
        source::Type{T},
        affected_values::Vector{DataType},
        meta=CONTAINER_KEY_EMPTY_META,
    ) where {T}
        values_vector = Vector{VariableKey}(undef, length(affected_values))
        for (ix, v) in enumerate(affected_values)
            if v <: VariableType
                values_vector[ix] =
                    get_optimization_container_key(v(), component_type, meta)
            else
                error(
                    "LowerBoundFeedforward is only compatible with VariableType affected values",
                )
            end
        end
        new(get_optimization_container_key(T(), component_type, meta), values_vector)
    end
end

get_default_parameter_type(::LowerBoundFeedforward, _) = LowerBoundValueParameter()
get_optimization_container_key(ff::LowerBoundFeedforward) = ff.optimization_container_key

"""
Adds a constraint to make the bounds of a variable 0.0. Effectively allows to "turn off" a value.
"""
struct SemiContinuousFeedforward <: AbstractAffectFeedforward
    optimization_container_key::OptimizationContainerKey
    affected_values::Vector{<:OptimizationContainerKey}
    function SemiContinuousFeedforward(;
        component_type::Type{<:PSY.Component},
        source::Type{T},
        affected_values::Vector{DataType},
        meta=CONTAINER_KEY_EMPTY_META,
    ) where {T}
        values_vector = Vector{VariableKey}(undef, length(affected_values))
        for (ix, v) in enumerate(affected_values)
            if v <: VariableType
                values_vector[ix] =
                    get_optimization_container_key(v(), component_type, meta)
            else
                error(
                    "SemiContinuousFeedforward is only compatible with VariableType affected values",
                )
            end
        end
        new(get_optimization_container_key(T(), component_type, meta), values_vector)
    end
end

get_default_parameter_type(::SemiContinuousFeedforward, _) = OnStatusParameter()
get_optimization_container_key(f::SemiContinuousFeedforward) = f.optimization_container_key

function has_semicontinuous_feedforward(
    model::DeviceModel,
    ::Type{T},
)::Bool where {T <: Union{VariableType, ExpressionType}}
    if isempty(model.feedforwards)
        return false
    end
    sc_feedforwards = [x for x in model.feedforwards if isa(x, SemiContinuousFeedforward)]
    if isempty(sc_feedforwards)
        return false
    end

    keys = get_affected_values(sc_feedforwards[1])

    return T ∈ get_entry_type.(keys)
end

function has_semicontinuous_feedforward(
    model::DeviceModel,
    ::Type{T},
)::Bool where {T <: Union{ActivePowerRangeExpressionUB, ActivePowerRangeExpressionLB}}
    return has_semicontinuous_feedforward(model, ActivePowerVariable)
end

"""
Adds a constraint to limit the sum of a variable over the number of periods to the source value
"""
struct EnergyLimitFeedforward <: AbstractAffectFeedforward
    optimization_container_key::OptimizationContainerKey
    affected_values::Vector{<:OptimizationContainerKey}
    number_of_periods::Int
    function EnergyLimitFeedforward(;
        component_type::Type{<:PSY.Component},
        source::Type{T},
        affected_values::Vector{DataType},
        number_of_periods::Int,
        meta=CONTAINER_KEY_EMPTY_META,
    ) where {T}
        values_vector = Vector{VariableKey}(undef, length(affected_values))
        for (ix, v) in enumerate(affected_values)
            if v <: VariableType
                values_vector[ix] =
                    get_optimization_container_key(v(), component_type, meta)
            else
                error(
                    "EnergyLimitFeedforward is only compatible with VariableType or ParamterType affected values",
                )
            end
        end
        new(
            get_optimization_container_key(T(), component_type, meta),
            values_vector,
            number_of_periods,
        )
    end
end

get_default_parameter_type(::EnergyLimitFeedforward, _) = EnergyLimitParameter()
get_optimization_container_key(ff) = ff.optimization_container_key
get_number_of_periods(ff) = ff.number_of_periods

"""
Fixes a Variable or Parameter Value in the model. Is the only Feed Forward that can be used
with a Parameter or a Variable as the affected value.
"""
struct FixValueFeedforward <: AbstractAffectFeedforward
    optimization_container_key::OptimizationContainerKey
    affected_values::Vector
    function FixValueFeedforward(;
        component_type::Type{<:PSY.Component},
        source::Type{T},
        affected_values::Vector{DataType},
        meta=CONTAINER_KEY_EMPTY_META,
    ) where {T}
        values_vector = Vector(undef, length(affected_values))
        for (ix, v) in enumerate(affected_values)
            if v <: VariableType || v <: ParameterType
                values_vector[ix] =
                    get_optimization_container_key(v(), component_type, meta)
            else
                error(
                    "UpperBoundFeedforward is only compatible with VariableType affected values",
                )
            end
        end
        new(get_optimization_container_key(T(), component_type, meta), values_vector)
    end
end

get_default_parameter_type(::FixValueFeedforward, _) = FixValueParameter()
get_optimization_container_key(ff::FixValueFeedforward) = ff.optimization_container_key

"""
Adds a constraint to enforce a minimum energy level target with a slack variable associated witha penalty term.
"""
struct EnergyTargetFeedforward <: AbstractAffectFeedforward
    optimization_container_key::OptimizationContainerKey
    affected_values::Vector{<:OptimizationContainerKey}
    target_period::Int
    penalty_cost::Float64
    function EnergyTargetFeedforward(;
        component_type::Type{<:PSY.Component},
        source::Type{T},
        affected_values::Vector{DataType},
        target_period::Int,
        penalty_cost::Float64,
        meta=CONTAINER_KEY_EMPTY_META,
    ) where {T}
        values_vector = Vector{VariableKey}(undef, length(affected_values))
        for (ix, v) in enumerate(affected_values)
            if v <: VariableType
                values_vector[ix] =
                    get_optimization_container_key(v(), component_type, meta)
            else
                error(
                    "EnergyTargetFeedforward is only compatible with VariableType or ParamterType affected values",
                )
            end
        end
        new(
            get_optimization_container_key(T(), component_type, meta),
            values_vector,
            target_period,
            penalty_cost,
        )
    end
end

get_default_parameter_type(::EnergyTargetFeedforward, _) = EnergyTargetParameter()
get_optimization_container_key(ff::EnergyTargetFeedforward) = ff.optimization_container_key
