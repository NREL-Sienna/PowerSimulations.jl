# So far just the EmulationStore is implemented.

"""
Stores results data for one EmulationModel
"""
mutable struct DecisionModelOptimizerResults <: AbstractModelOptimizerResults
    duals::Dict{ConstraintKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    parameters::Dict{ParameterKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    variables::Dict{VariableKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    aux_variables::Dict{AuxVarKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    expressions::Dict{ExpressionKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
end

function DecisionModelOptimizerResults()
    return DecisionModelOptimizerResults(
        Dict{
            ConstraintKey,
            Dict{ConstraintKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}},
        }(),
        Dict{
            ParameterKey,
            Dict{ParameterKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}},
        }(),
        Dict{
            VariableKey,
            Dict{VariableKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}},
        }(),
        Dict{
            AuxVarKey,
            Dict{ConstraintKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}},
        }(),
        Dict{
            AuxVarKey,
            Dict{ExpressionKey, OrderedDict{Dates.DateTime, DataFrames.DataFrame}},
        }(),
    )
end

"""
Stores results data for one EmulationModel
"""
mutable struct EmulationModelOptimizerResults <: AbstractModelOptimizerResults
    last_recorded_row::Int
    duals::Dict{ConstraintKey, DataFrames.DataFrame}
    parameters::Dict{ParameterKey, DataFrames.DataFrame}
    variables::Dict{VariableKey, DataFrames.DataFrame}
    aux_variables::Dict{AuxVarKey, DataFrames.DataFrame}
    expressions::Dict{ExpressionKey, DataFrames.DataFrame}
end

function EmulationModelOptimizerResults()
    return EmulationModelOptimizerResults(
        0,
        Dict{ConstraintKey, DataFrames.DataFrame}(),
        Dict{ParameterKey, DataFrames.DataFrame}(),
        Dict{VariableKey, DataFrames.DataFrame}(),
        Dict{AuxVarKey, DataFrames.DataFrame}(),
        Dict{ExpressionKey, DataFrames.DataFrame}(),
    )
end

"""
Stores simulation data in memory
"""
mutable struct InMemoryModelStore{T <: AbstractModelOptimizerResults}
    data::T
    optimizer_stats::OrderedDict{Int, OptimizerStats}
end

function InMemoryModelStore(::Type{T}) where {T <: AbstractModelOptimizerResults}
    return InMemoryModelStore(T(), OrderedDict{Int, OptimizerStats}())
end

# TBD: Implementation depending on what the call need is. Needs to make sure it is safe.
# Possible use case: Call Run on EmulationModel without calling build again
function Base.empty!(
    store::InMemoryModelStore{T},
) where {T <: AbstractModelOptimizerResults}
    store.data = T()
    @debug "Emptied the store with data T"
end

Base.isopen(store::InMemoryModelStore) = true
Base.close(store::InMemoryModelStore) = nothing
Base.flush(store::InMemoryModelStore) = nothing

function write_optimizer_stats!(store::InMemoryModelStore, stats::OptimizerStats, execution)
    store.optimizer_stats[execution] = stats
    return
end

function read_optimizer_stats(store::InMemoryModelStore)
    stats = [to_namedtuple(x) for x in values(store.optimizer_stats)]
    return DataFrames.DataFrame(stats)
end

# Not sure if needed
# function open_store(
#     func::Function,
#     ::Type{InMemoryModelStore},
#     ::AbstractString,  # Unused. Need to match the interface.
#     mode = nothing,
#     filename = nothing,
# )
#     store = InMemoryModelStore()
#     return func(store)
# end

function initialize_storage!(
    store::InMemoryModelStore,
    container::OptimizationContainer,
    params::ModelStoreParams,
)
    @debug "initialize_storage"

    num_of_executions = get_num_executions(params)
    for type in STORE_CONTAINERS
        field_containers = getfield(container, type)
        store_container = getfield(store.data, type)
        for (key, field_container) in field_containers
            container_axes = axes(field_container)
            @debug "Adding $(encode_key_as_string(key)) to InMemoryModelStore"
            if length(container_axes) == 2
                if type == STORE_CONTAINER_PARAMETERS
                    column_names = string.(get_parameter_array(field_container).axes[1])
                else
                    column_names = string.(axes(field_container)[1])
                end
                store_container[key] = DataFrames.DataFrame(
                    OrderedDict(c => fill(NaN, num_of_executions) for c in column_names),
                )
            elseif length(container_axes) == 1
                store_container[key] = DataFrames.DataFrame(
                    encode_key_as_string(key) => fill(NaN, num_of_executions),
                )
            else
                error("Container structure for $(encode_key_as_string(key)) not supported")
            end
        end
    end

    store.optimizer_stats = OrderedDict{Dates.DateTime, OptimizerStats}()
    @debug "Initialized optimizer_stats_datasets $(get_name(model))"
end

function list_keys(store::InMemoryModelStore, container_type)
    container = getfield(store.data, container_type)
    return collect(keys(container))
end

function write_result!(
    store::InMemoryModelStore,
    container_type,
    key,
    execution,
    array,
    columns = nothing,
)
    container = getfield(store.data, container_type)
    df = axis_array_to_dataframe(array, columns)
    container[key][execution, :] = df[1, :]
    return
end

function read_results(store::InMemoryModelStore, container_type, key)
    return read_results(DataFrames.DataFrame, store, container_type, key)
end

function read_results(
    ::Type{DataFrames.DataFrame},
    store::InMemoryModelStore,
    container_type,
    key,
)
    container = getfield(store.data, container_type)
    # Return a copy because callers may mutate it.
    return copy(container[key], copycols = true)
end

function get_variable(
    store::InMemoryModelStore,
    ::T,
    ::Type{U},
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    return store.data.variables[VariableKey(T, U)]
end

function get_aux_variable(
    store::InMemoryModelStore,
    ::T,
    ::Type{U},
) where {T <: AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return store.data.aux_variables[AuxVarKey(T, U)]
end

function get_dual(
    store::InMemoryModelStore,
    ::T,
    ::Type{U},
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return store.data.duals[ConstraintKey(T, U)]
end

function get_parameter(
    store::InMemoryModelStore,
    ::T,
    ::Type{U},
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return store.data.parameters[ParameterKey(T, U)]
end
