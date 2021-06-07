# TODO: make a unit test that checks for this.

abstract type OptimizationContainerKey end
abstract type VariableType end
abstract type AuxVariableType end

function encode_key(key::OptimizationContainerKey)
    return encode_symbol(get_component_type(key), get_entry_type(key), key.meta)
end

function encode_symbol(
    ::Type{T},
    ::Type{U},
    meta::String = CONTAINER_KEY_EMPTY_META,
) where {T <: PSY.Component, U}
    meta_ = isempty(meta) ? meta : "_" * meta
    T_ = replace(replace(IS.strip_module_name(T), "{" => "_"), "}" => "")
    return "$(IS.strip_module_name(string(U)))_$(T_)" * meta_
end

abstract type AbstractAffectFeedForward end

abstract type AbstractCache end
abstract type FeedForwardChronology end

get_trigger(val::FeedForwardChronology) = val.trigger

abstract type AbstractOperationsProblem end
abstract type PowerSimulationsOperationsProblem <: AbstractOperationsProblem end
