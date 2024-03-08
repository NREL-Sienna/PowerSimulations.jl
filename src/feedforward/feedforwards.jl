function get_affected_values(ff::AbstractAffectFeedforward)
    return ff.affected_values
end

function attach_feedforward!(
    model::DeviceModel,
    ff::T,
) where {T <: AbstractAffectFeedforward}
    if !isempty(model.feedforwards)
        ff_k = [get_optimization_container_key(v) for v in model.feedforwards if isa(v, T)]
        if get_optimization_container_key(ff) ∈ ff_k
            return
        end
    end
    push!(model.feedforwards, ff)
    return
end

function attach_feedforward!(
    model::ServiceModel,
    ff::T,
) where {T <: AbstractAffectFeedforward}
    if get_feedforward_meta(ff) != NO_SERVICE_NAME_PROVIDED
        ff_ = ff
    else
        ff_ = T(;
            component_type = get_component_type(ff),
            source = get_entry_type(get_optimization_container_key(ff)),
            affected_values = affected_values =
                get_entry_type.(get_affected_values(ff)),
            meta = model.service_name,
        )
    end
    if !isempty(model.feedforwards)
        ff_k = [get_optimization_container_key(v) for v in model.feedforwards if isa(v, T)]
        if get_optimization_container_key(ff_) ∈ ff_k
            return
        end
    end
    push!(model.feedforwards, ff_)
    return
end

function get_component_type(ff::AbstractAffectFeedforward)
    return get_component_type(get_optimization_container_key(ff))
end

function get_feedforward_meta(ff::AbstractAffectFeedforward)
    return get_optimization_container_key(ff).meta
end

"""
Adds an upper bound constraint to a variable.
"""
struct UpperBoundFeedforward <: AbstractAffectFeedforward
    optimization_container_key::OptimizationContainerKey
    affected_values::Vector
    add_slacks::Bool
    function UpperBoundFeedforward(;
        component_type::Type{<:PSY.Component},
        source::Type{T},
        affected_values::Vector{DataType},
        add_slacks::Bool = false,
        meta = IS.Optimization.CONTAINER_KEY_EMPTY_META,
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
        new(
            get_optimization_container_key(T(), component_type, meta),
            values_vector,
            add_slacks,
        )
    end
end

get_default_parameter_type(::UpperBoundFeedforward, _) = UpperBoundValueParameter
get_optimization_container_key(ff::UpperBoundFeedforward) = ff.optimization_container_key
get_slacks(ff::UpperBoundFeedforward) = ff.add_slacks

"""
Adds a lower bound constraint to a variable.
"""
struct LowerBoundFeedforward <: AbstractAffectFeedforward
    optimization_container_key::OptimizationContainerKey
    affected_values::Vector{<:OptimizationContainerKey}
    add_slacks::Bool
    function LowerBoundFeedforward(;
        component_type::Type{<:PSY.Component},
        source::Type{T},
        affected_values::Vector{DataType},
        add_slacks::Bool = false,
        meta = IS.Optimization.CONTAINER_KEY_EMPTY_META,
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
        new(
            get_optimization_container_key(T(), component_type, meta),
            values_vector,
            add_slacks,
        )
    end
end

get_default_parameter_type(::LowerBoundFeedforward, _) = LowerBoundValueParameter
get_optimization_container_key(ff::LowerBoundFeedforward) = ff.optimization_container_key
get_slacks(ff::LowerBoundFeedforward) = ff.add_slacks

function attach_feedforward!(
    model::ServiceModel,
    ff::T,
) where {T <: Union{LowerBoundFeedforward, UpperBoundFeedforward}}
    if get_feedforward_meta(ff) != NO_SERVICE_NAME_PROVIDED
        ff_ = ff
    else
        ff_ = T(;
            component_type = get_component_type(ff),
            source = get_entry_type(get_optimization_container_key(ff)),
            affected_values = get_entry_type.(get_affected_values(ff)),
            meta = model.service_name,
            add_slacks = ff.add_slacks,
        )
    end
    if !isempty(model.feedforwards)
        ff_k = [get_optimization_container_key(v) for v in model.feedforwards if isa(v, T)]
        if get_optimization_container_key(ff_) ∈ ff_k
            return
        end
    end
    push!(model.feedforwards, ff_)
    return
end

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
        meta = IS.Optimization.CONTAINER_KEY_EMPTY_META,
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

get_default_parameter_type(::SemiContinuousFeedforward, _) = OnStatusParameter
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
        meta = IS.Optimization.CONTAINER_KEY_EMPTY_META,
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

get_default_parameter_type(::FixValueFeedforward, _) = FixValueParameter
get_optimization_container_key(ff::FixValueFeedforward) = ff.optimization_container_key
