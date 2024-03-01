struct DatasetContainer{T}
    duals::Dict{IS.ConstraintKey, T}
    aux_variables::Dict{IS.AuxVarKey, T}
    variables::Dict{IS.VariableKey, T}
    parameters::Dict{IS.ParameterKey, T}
    expressions::Dict{IS.ExpressionKey, T}
end

function DatasetContainer{T}() where {T <: AbstractDataset}
    return DatasetContainer(
        Dict{IS.ConstraintKey, T}(),
        Dict{IS.AuxVarKey, T}(),
        Dict{IS.VariableKey, T}(),
        Dict{IS.ParameterKey, T}(),
        Dict{IS.ExpressionKey, T}(),
    )
end

function Base.empty!(container::DatasetContainer)
    for field in fieldnames(DatasetContainer)
        field_dict = getfield(container, field)
        for val in values(field_dict)
            empty!(val)
        end
    end
    @debug "Emptied the store" _group = LOG_GROUP_SIMULATION_STORE
    return
end

function get_duals_values(container::DatasetContainer{InMemoryDataset})
    return container.duals
end

function get_aux_variables_values(container::DatasetContainer{InMemoryDataset})
    return container.aux_variables
end

function get_variables_values(container::DatasetContainer{InMemoryDataset})
    return container.variables
end

function get_parameters_values(container::DatasetContainer{InMemoryDataset})
    return container.parameters
end

function get_expression_values(container::DatasetContainer{InMemoryDataset})
    return container.expressions
end

function get_duals_values(::DatasetContainer{HDF5Dataset})
    error("Operation not allowed on a HDF5Dataset.")
end

function get_aux_variables_values(::DatasetContainer{HDF5Dataset})
    error("Operation not allowed on a HDF5Dataset.")
end

function get_variables_values(::DatasetContainer{HDF5Dataset})
    error("Operation not allowed on a HDF5Dataset.")
end

function get_parameters_values(::DatasetContainer{HDF5Dataset})
    error("Operation not allowed on a HDF5Dataset.")
end

function get_expression_values(::DatasetContainer{HDF5Dataset})
    error("Operation not allowed on a HDF5Dataset.")
end

function get_dataset_keys(container::DatasetContainer)
    return Iterators.flatten(
        keys(getfield(container, f)) for f in fieldnames(DatasetContainer)
    )
end

function get_dataset(container::DatasetContainer, key::IS.OptimizationContainerKey)
    datasets = getfield(container, get_store_container_type(key))
    return datasets[key]
end

function set_dataset!(
    container::DatasetContainer{T},
    key::IS.OptimizationContainerKey,
    val::T,
) where {T <: AbstractDataset}
    datasets = getfield(container, get_store_container_type(key))
    datasets[key] = val
    return
end

function has_dataset(container::DatasetContainer, key::IS.OptimizationContainerKey)
    datasets = getfield(container, get_store_container_type(key))
    return haskey(datasets, key)
end

function get_dataset(
    container::DatasetContainer,
    ::T,
    ::Type{U},
) where {T <: IS.ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return get_dataset(container, IS.ConstraintKey(T, U))
end

function get_dataset(
    container::DatasetContainer,
    ::T,
    ::Type{U},
) where {T <: IS.VariableType, U <: Union{PSY.Component, PSY.System}}
    return get_dataset(container, IS.VariableKey(T, U))
end

function get_dataset(
    container::DatasetContainer,
    ::T,
    ::Type{U},
) where {T <: IS.AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return get_dataset(container, IS.AuxVarKey(T, U))
end

function get_dataset(
    container::DatasetContainer,
    ::T,
    ::Type{U},
) where {T <: IS.ParameterType, U <: Union{PSY.Component, PSY.System}}
    return get_dataset(container, IS.ParameterKey(T, U))
end

function get_dataset(
    container::DatasetContainer,
    ::T,
    ::Type{U},
) where {T <: IS.ExpressionType, U <: Union{PSY.Component, PSY.System}}
    return get_dataset(container, IS.ExpressionKey(T, U))
end

function get_dataset_values(container::DatasetContainer, key::IS.OptimizationContainerKey)
    return get_dataset(container, key).values
end

function get_dataset_values(
    container::DatasetContainer,
    ::T,
    ::Type{U},
) where {T <: IS.ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return get_dataset_values(container, IS.ConstraintKey(T, U))
end

function get_dataset_values(
    container::DatasetContainer,
    ::T,
    ::Type{U},
) where {T <: IS.VariableType, U <: Union{PSY.Component, PSY.System}}
    return get_dataset_values(container, IS.VariableKey(T, U))
end

function get_dataset_values(
    container::DatasetContainer,
    ::T,
    ::Type{U},
) where {T <: IS.AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return get_dataset_values(container, IS.AuxVarKey(T, U))
end

function get_dataset_values(
    container::DatasetContainer,
    ::T,
    ::Type{U},
) where {T <: IS.ExpressionType, U <: Union{PSY.Component, PSY.System}}
    return get_dataset_values(container, IS.ExpressionKey(T, U))
end

function get_dataset_values(
    container::DatasetContainer,
    key::IS.OptimizationContainerKey,
    date::Dates.DateTime,
)
    return get_dataset_value(get_dataset(container, key), date)
end

function get_last_recorded_row(
    container::DatasetContainer,
    key::IS.OptimizationContainerKey,
)
    return get_last_recorded_row(get_dataset(container, key))
end

"""
Return the timestamp from the data used in the last update
"""
function get_update_timestamp(container::DatasetContainer, key::IS.OptimizationContainerKey)
    return get_update_timestamp(get_dataset(container, key))
end

"""
Return the timestamp from most recent data row updated in the dataset. This value may not be the same as the result from `get_update_timestamp`
"""
function get_last_updated_timestamp(
    container::DatasetContainer,
    key::IS.OptimizationContainerKey,
)
    return get_last_updated_timestamp(get_dataset(container, key))
end

function get_last_update_value(
    container::DatasetContainer,
    key::IS.OptimizationContainerKey,
)
    return get_last_recorded_value(get_dataset(container, key))
end

function set_dataset_values!(
    container::DatasetContainer,
    key::IS.OptimizationContainerKey,
    index::Int,
    vals,
)
    set_value!(get_dataset(container, key), vals, index)
    return
end
