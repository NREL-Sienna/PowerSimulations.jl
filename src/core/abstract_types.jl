# All subtypes of AbstractAffectFeedForward must define the field affected_variables.
# TODO: make a unit test that checks for this.

abstract type OptimizationContainerKey end
abstract type VariableType end
abstract type AuxVariableType end

function encode_key(key::OptimizationContainerKey)
    return encode_symbol(key.entry_type, key.component_type, key.meta)
end

function encode_symbol(::Type{U}, ::Type{T}, meta::String = CONTAINER_KEY_EMPTY_META) where {T, U <: PSY.Component}
    meta_ = isempty(meta) ? meta : "_"*meta
    return Symbol("$(IS.strip_module_name(string(T)))_$(IS.strip_module_name(string(U)))"*meta_)
end

abstract type AbstractAffectFeedForward end

abstract type AbstractCache end
abstract type FeedForwardChronology end

get_trigger(val::FeedForwardChronology) = val.trigger

abstract type AbstractOperationsProblem end
abstract type PowerSimulationsOperationsProblem <: AbstractOperationsProblem end
