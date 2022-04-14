struct EmulationModelSimulationResults <: OperationModelSimulationResults
    variables::Dict{OptimizationContainerKey, DataFrames.DataFrame}
    duals::Dict{OptimizationContainerKey, DataFrames.DataFrame}
    parameters::Dict{OptimizationContainerKey, DataFrames.DataFrame}
    aux_variables::Dict{OptimizationContainerKey, DataFrames.DataFrame}
    expressions::Dict{OptimizationContainerKey, DataFrames.DataFrame}
    container_key_lookup::Dict{String, OptimizationContainerKey}
end

function SimulationProblemResults(
    ::Type{EmulationModel},
    store::SimulationStore,
    model_name::AbstractString,
    problem_params::ModelStoreParams,
    sim_params::SimulationStoreParams,
    path,
    container_key_lookup;
    kwargs...,
)
    variables = list_emulation_model_keys(store, STORE_CONTAINER_VARIABLES)
    parameters = list_emulation_model_keys(store, STORE_CONTAINER_PARAMETERS)
    duals = list_emulation_model_keys(store, STORE_CONTAINER_DUALS)
    aux_variables = list_emulation_model_keys(store, STORE_CONTAINER_AUX_VARIABLES)
    expressions = list_emulation_model_keys(store, STORE_CONTAINER_EXPRESSIONS)

    return SimulationProblemResults{EmulationModelSimulationResults}(
        store,
        model_name,
        problem_params,
        sim_params,
        path,
        EmulationModelSimulationResults(
            Dict(x => DataFrames.DataFrame() for x in variables),
            Dict(x => DataFrames.DataFrame() for x in duals),
            Dict(x => DataFrames.DataFrame() for x in parameters),
            Dict(x => DataFrames.DataFrame() for x in aux_variables),
            Dict(x => DataFrames.DataFrame() for x in expressions),
            container_key_lookup,
        );
        kwargs...,
    )
end

function Base.empty!(res::SimulationProblemResults{EmulationModelSimulationResults})
    for container in _get_containers(res)
        for df in values(container)
            empty!(df)
        end
    end
end

function Base.isempty(res::SimulationProblemResults{EmulationModelSimulationResults})
    for container in _get_containers(res)
        for df in values(container)
            if !isempty(df)
                return false
            end
        end
    end

    return true
end

function Base.length(res::SimulationProblemResults{EmulationModelSimulationResults})
    count_not_empty = 0
    for container in _get_containers(res)
        for df in values(container)
            if !isempty(df)
                count_not_empty += 1
            end
        end
    end

    return count_not_empty
end

function _get_store_value(
    res::SimulationProblemResults{EmulationModelSimulationResults},
    container_keys::Vector{<:OptimizationContainerKey},
    ::Nothing;
    start_time=nothing,
    len=nothing,
)
    simulation_store_path = joinpath(get_execution_path(res), "data_store")
    return open_store(HdfSimulationStore, simulation_store_path, "r") do store
        _get_store_value(res, container_keys, store, start_time=start_time, len=len)
    end
end

function _get_store_value(
    res::SimulationProblemResults{EmulationModelSimulationResults},
    container_keys::Vector{<:OptimizationContainerKey},
    store::SimulationStore;
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Nothing, Int}=nothing,
)
    base_power = res.base_power
    results = Dict{OptimizationContainerKey, DataFrames.DataFrame}()
    for key in container_keys
        start_time, _len, resolution = _check_offsets(res, key, store, start_time, len)
        start_index = (start_time - first(res.timestamps)) ÷ resolution + 1
        df = read_results(store, key, index=start_index, len=_len)
        if convert_result_to_natural_units(key)
            df .*= base_power
        end
        time_col = range(start_time, length=_len, step=res.resolution)
        DataFrames.insertcols!(df, 1, :DateTime => time_col)
        results[key] = df
    end

    return results
end

function _check_offsets(
    res::SimulationProblemResults{EmulationModelSimulationResults},
    key,
    store,
    start_time,
    len,
)
    dataset_size = get_emulation_model_dataset_size(store, key)
    resolution =
        (last(res.timestamps) - first(res.timestamps) + res.resolution) ÷ dataset_size[1]
    if isnothing(start_time)
        start_time = first(res.timestamps)
    elseif start_time < first(res.timestamps) || start_time > last(res.timestamps)
        throw(
            IS.InvalidValue(
                "start_time = $start_time is not in the results range $(res.timestamps)",
            ),
        )
    elseif (start_time - first(res.timestamps)) % resolution != Dates.Millisecond(0)
        throw(
            IS.InvalidValue(
                "start_time = $start_time is not a multiple of resolution = $resolution",
            ),
        )
    end

    if isnothing(len)
        len = (last(res.timestamps) + resolution - start_time) ÷ resolution
    elseif start_time + resolution * len > last(res.timestamps) + res.resolution
        throw(
            IS.InvalidValue(
                "len = $len resolution = $resolution exceeds the results range $(res.timestamps)",
            ),
        )
    end

    return start_time, len, resolution
end

function read_aux_variables_with_keys(
    res::SimulationProblemResults{EmulationModelSimulationResults},
    aux_variables::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Nothing, Int}=nothing,
)
    return _read_aux_variables(res, aux_variables, nothing, start_time, len)
end

function _read_aux_variables(
    res::SimulationProblemResults{EmulationModelSimulationResults},
    aux_variable_keys,
    store,
    start_time=nothing,
    len=nothing,
)
    isempty(aux_variable_keys) &&
        return Dict{OptimizationContainerKey, DataFrames.DataFrame}()
    if store === nothing && res.store !== nothing
        # In this case we have an InMemorySimulationStore.
        store = res.store
    end

    _validate_keys(keys(get_aux_variables(res)), aux_variable_keys)
    keys_with_values = Set((k for (k, v) in get_aux_variables(res) if !isempty(v)))
    if isempty(setdiff(aux_variable_keys, keys_with_values))
        @debug "reading aux_variables from SimulationsResults"
        vals = filter(p -> (p.first ∈ aux_variable_keys), get_aux_variables(res))
    else
        @debug "reading aux_variables from data store"
        vals =
            _get_store_value(res, aux_variable_keys, store, start_time=start_time, len=len)
    end
    return vals
end

function _read_expressions(
    res::SimulationProblemResults{EmulationModelSimulationResults},
    expression_keys,
    store,
    start_time=nothing,
    len=nothing,
)
    isempty(expression_keys) &&
        return Dict{OptimizationContainerKey, DataFrames.DataFrame}()
    if store === nothing && res.store !== nothing
        # In this case we have an InMemorySimulationStore.
        store = res.store
    end

    _validate_keys(keys(get_expressions(res)), expression_keys)
    keys_with_values = Set((k for (k, v) in get_expressions(res) if !isempty(v)))
    if isempty(setdiff(expression_keys, keys_with_values))
        @debug "reading expressions from SimulationsResults"
        vals = filter(p -> (p.first ∈ expression_keys), get_expressions(res))
    else
        @debug "reading expressions from data store"
        vals = _get_store_value(res, expression_keys, store, start_time=start_time, len=len)
    end
    return vals
end

function read_duals_with_keys(
    res::SimulationProblemResults{EmulationModelSimulationResults},
    duals::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Nothing, Int}=nothing,
)
    return _read_duals(res, duals, nothing, start_time, len)
end

function _read_duals(
    res::SimulationProblemResults{EmulationModelSimulationResults},
    dual_keys,
    store,
    start_time=nothing,
    len=nothing,
)
    isempty(dual_keys) && return Dict{OptimizationContainerKey, DataFrames.DataFrame}()
    if store === nothing && res.store !== nothing
        # In this case we have an InMemorySimulationStore.
        store = res.store
    end

    _validate_keys(keys(get_duals(res)), dual_keys)
    keys_with_values = Set((k for (k, v) in get_duals(res) if !isempty(v)))
    if isempty(setdiff(dual_keys, keys_with_values))
        @debug "reading duals from SimulationsResults"
        vals = filter(p -> (p.first ∈ dual_keys), get_duals(res))
    else
        @debug "reading duals from data store"
        vals = _get_store_value(res, dual_keys, store, start_time=start_time, len=len)
    end
    return vals
end

function read_expressions_with_keys(
    res::SimulationProblemResults{EmulationModelSimulationResults},
    expressions::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Nothing, Int}=nothing,
)
    return _read_expressions(res, expressions, nothing, start_time, len)
end

function read_parameters_with_keys(
    res::SimulationProblemResults{EmulationModelSimulationResults},
    parameters::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Nothing, Int}=nothing,
)
    return _read_parameters(res, parameters, nothing, start_time, len)
end

function _read_parameters(
    res::SimulationProblemResults{EmulationModelSimulationResults},
    parameter_keys,
    store,
    start_time=nothing,
    len=nothing,
)
    isempty(parameter_keys) && return Dict{OptimizationContainerKey, DataFrames.DataFrame}()
    if store === nothing && res.store !== nothing
        # In this case we have an InMemorySimulationStore.
        store = res.store
    end

    _validate_keys(keys(get_parameters(res)), parameter_keys)
    keys_with_values = Set((k for (k, v) in get_parameters(res) if !isempty(v)))
    if isempty(setdiff(parameter_keys, keys_with_values))
        @debug "reading parameters from SimulationsResults"
        vals = filter(p -> (p.first ∈ parameter_keys), get_parameters(res))
    else
        @debug "reading parameters from data store"
        vals = _get_store_value(res, parameter_keys, store, start_time=start_time, len=len)
    end
    return vals
end

function read_variables_with_keys(
    res::SimulationProblemResults{EmulationModelSimulationResults},
    variables::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Nothing, Int}=nothing,
)
    return _read_variables(res, variables, nothing, start_time, len)
end

function _read_variables(
    res::SimulationProblemResults{EmulationModelSimulationResults},
    variable_keys,
    store,
    start_time=nothing,
    len=nothing,
)
    isempty(variable_keys) && return Dict{OptimizationContainerKey, DataFrames.DataFrame}()
    if store === nothing && res.store !== nothing
        # In this case we have an InMemorySimulationStore.
        store = res.store
    end

    _validate_keys(keys(get_variables(res)), variable_keys)
    keys_with_values = Set((k for (k, v) in get_variables(res) if !isempty(v)))
    if isempty(setdiff(variable_keys, keys_with_values))
        @debug "reading variables from SimulationsResults"
        # TODO: This needs to filter by start_time and len.
        vals = filter(p -> (p.first ∈ variable_keys), get_variables(res))
    else
        @debug "reading variables from data store"
        vals = _get_store_value(res, variable_keys, store, start_time=start_time, len=len)
    end
    return vals
end

"""
Load the simulation results into memory for repeated reads. Running this function twice
overwrites the previously loaded results. This is useful when loading results from remote
locations over network connections.

For each variable/parameter/dual, etc., each element must be the name encoded as a string,
like `"ActivePowerVariable__ThermalStandard"`` or a Tuple with its constituent types, like `(ActivePowerVariable, ThermalStandard)`.

# Arguments

  - `aux_variables::Vector{Union{String, Tuple}}`: Optional list of aux variables to load.
  - `duals::Vector{Union{String, Tuple}}`: Optional list of duals to load.
  - `expressions::Vector{Union{String, Tuple}}`: Optional list of expressions to load.
  - `parameters::Vector{Union{String, Tuple}}`: Optional list of parameters to load.
  - `variables::Vector{Union{String, Tuple}}`: Optional list of variables to load.
"""
function load_results!(
    res::SimulationProblemResults{EmulationModelSimulationResults};
    aux_variables=Vector{Tuple}(),
    duals=Vector{Tuple}(),
    expressions=Vector{Tuple}(),
    parameters=Vector{Tuple}(),
    variables=Vector{Tuple}(),
)
    # TODO: consider extending this to support start_time and len
    aux_variable_keys = [_deserialize_key(AuxVarKey, res, x...) for x in aux_variables]
    dual_keys = [_deserialize_key(ConstraintKey, res, x...) for x in duals]
    expression_keys = [_deserialize_key(ExpressionKey, res, x...) for x in expressions]
    parameter_keys = [_deserialize_key(ParameterKey, res, x...) for x in parameters]
    variable_keys = [_deserialize_key(VariableKey, res, x...) for x in variables]
    function merge_results(store)
        merge!(get_aux_variables(res), _read_aux_variables(res, aux_variable_keys, store))
        merge!(get_duals(res), _read_duals(res, dual_keys, store))
        merge!(get_expressions(res), _read_expressions(res, expression_keys, store))
        merge!(get_parameters(res), _read_parameters(res, parameter_keys, store))
        merge!(get_variables(res), _read_variables(res, variable_keys, store))
    end

    if res.store isa InMemorySimulationStore
        merge_results(res.store)
    else
        simulation_store_path = joinpath(res.execution_path, "data_store")
        open_store(HdfSimulationStore, simulation_store_path, "r") do store
            merge_results(store)
        end
    end

    return
end

# TODO: These aren't being written to the store.
function _read_optimizer_stats(
    res::SimulationProblemResults{EmulationModelSimulationResults},
    store::SimulationStore,
)
    return
end
