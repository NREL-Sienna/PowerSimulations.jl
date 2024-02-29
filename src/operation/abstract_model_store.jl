abstract type AbstractModelStore end

# Required methods for subtypes:
# = initialize_storage!
# - write_result!
# - read_results
# - write_optimizer_stats!
# - read_optimizer_stats
#
# Each subtype must have a field for each instance of STORE_CONTAINERS.

function Base.empty!(store::AbstractModelStore)
    stype = typeof(store)
    for (name, type) in zip(fieldnames(stype), fieldtypes(stype))
        val = get_data_field(store, name)
        try
            empty!(val)
        catch
            @error "Base.empty! must be customized for type $stype or skipped"
            rethrow()
        end
    end
end

get_data_field(store::AbstractModelStore, type) = getfield(store, type)

function Base.isempty(store::AbstractModelStore)
    stype = typeof(store)
    for (name, type) in zip(fieldnames(stype), fieldtypes(stype))
        val = get_data_field(store, name)
        try
            !isempty(val) && return false
        catch
            @error "Base.isempty must be customized for type $stype or skipped"
            rethrow()
        end
    end

    return true
end

function list_fields(store::AbstractModelStore, container_type::Symbol)
    return keys(get_data_field(store, container_type))
end

function write_result!(store::AbstractModelStore, key, index, array)
    field = get_store_container_type(key)
    return write_result!(store, field, key, index, array)
end

function read_results(store::AbstractModelStore, key; index = nothing)
    field = get_store_container_type(key)
    return read_results(store, field, key; index = index)
end

function list_keys(store::AbstractModelStore, container_type)
    container = get_data_field(store, container_type)
    return collect(keys(container))
end

function get_variable_value(
    store::AbstractModelStore,
    ::T,
    ::Type{U},
) where {T <: IS.VariableType, U <: Union{PSY.Component, PSY.System}}
    return get_data_field(store, :variables)[IS.VariableKey(T, U)]
end

function get_aux_variable_value(
    store::AbstractModelStore,
    ::T,
    ::Type{U},
) where {T <: IS.AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return get_data_field(store, :aux_variables)[AuxVarKey(T, U)]
end

function get_dual_value(
    store::AbstractModelStore,
    ::T,
    ::Type{U},
) where {T <: IS.ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return get_data_field(store, :duals)[IS.ConstraintKey(T, U)]
end

function get_parameter_value(
    store::AbstractModelStore,
    ::T,
    ::Type{U},
) where {T <: IS.ParameterType, U <: Union{PSY.Component, PSY.System}}
    return get_data_field(store, :parameters)[IS.ParameterKey(T, U)]
end
