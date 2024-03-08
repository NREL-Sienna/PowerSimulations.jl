abstract type OperationModelSimulationResults end
# Subtypes need to implement the following methods for SimulationProblemResults{T}
# - read_results_with_keys
# - list_aux_variable_keys
# - list_dual_keys
# - list_expression_keys
# - list_parameter_keys
# - list_variable_keys
# - load_results!

"""
Holds the results of a simulation problem for plotting or exporting.
"""
mutable struct SimulationProblemResults{T} <:
               IS.Results where {T <: OperationModelSimulationResults}
    problem::String
    base_power::Float64
    execution_path::String
    results_output_folder::String
    timestamps::StepRange{Dates.DateTime, Dates.Millisecond}
    results_timestamps::Vector{Dates.DateTime}
    values::T
    system::Union{Nothing, PSY.System}
    system_uuid::Base.UUID
    resolution::Dates.TimePeriod
    store::Union{Nothing, SimulationStore}
end

function SimulationProblemResults{T}(
    store::SimulationStore,
    model_name::AbstractString,
    problem_params::ModelStoreParams,
    sim_params::SimulationStoreParams,
    path,
    vals::T;
    results_output_path = nothing,
    system = nothing,
) where {T <: OperationModelSimulationResults}
    if results_output_path === nothing
        results_output_path = joinpath(path, "results")
    end

    time_steps = range(
        sim_params.initial_time;
        length = problem_params.num_executions * sim_params.num_steps,
        step = problem_params.interval,
    )
    return SimulationProblemResults{T}(
        model_name,
        problem_params.base_power,
        path,
        results_output_path,
        time_steps,
        Vector{Dates.DateTime}(),
        vals,
        system,
        problem_params.system_uuid,
        get_resolution(problem_params),
        store isa HdfSimulationStore ? nothing : store,
    )
end

get_model_name(res::SimulationProblemResults) = res.problem
get_system(res::SimulationProblemResults) = res.system
get_resolution(res::SimulationProblemResults) = res.resolution
get_execution_path(res::SimulationProblemResults) = res.execution_path
get_model_base_power(res::SimulationProblemResults) = res.base_power
get_system_uuid(results::PSI.SimulationProblemResults) = results.system_uuid
IS.get_timestamp(result::SimulationProblemResults) = result.results_timestamps
get_interval(res::SimulationProblemResults) = res.timestamps.step
IS.get_base_power(result::SimulationProblemResults) = result.base_power

get_results_timestamps(result::SimulationProblemResults) = result.results_timestamps
function set_results_timestamps!(
    result::SimulationProblemResults,
    results_timestamps::Vector{Dates.DateTime},
)
    result.results_timestamps = results_timestamps
end

list_result_keys(res::SimulationProblemResults, ::IS.AuxVarKey) = list_aux_variable_keys(res)
list_result_keys(res::SimulationProblemResults, ::IS.ConstraintKey) = list_dual_keys(res)
list_result_keys(res::SimulationProblemResults, ::IS.ExpressionKey) =
    list_expression_keys(res)
list_result_keys(res::SimulationProblemResults, ::IS.ParameterKey) =
    list_parameter_keys(res)
list_result_keys(res::SimulationProblemResults, ::IS.VariableKey) = list_variable_keys(res)

get_cached_results(res::SimulationProblemResults, ::Type{<:IS.AuxVarKey}) =
    get_cached_aux_variables(res)
get_cached_results(res::SimulationProblemResults, ::Type{<:IS.ConstraintKey}) =
    get_cached_duals(res)
get_cached_results(res::SimulationProblemResults, ::Type{<:IS.ExpressionKey}) =
    get_cached_expressions(res)
get_cached_results(res::SimulationProblemResults, ::Type{<:IS.ParameterKey}) =
    get_cached_parameters(res)
get_cached_results(res::SimulationProblemResults, ::Type{<:IS.VariableKey}) =
    get_cached_variables(res)
get_cached_results(
    res::SimulationProblemResults,
    ::Type{<:IS.OptimizationContainerKey} = OptimizationContainerKey,
) =
    merge(  # PERF: could be done lazily
        get_cached_aux_variables(res),
        get_cached_duals(res),
        get_cached_expressions(res),
        get_cached_parameters(res),
        get_cached_variables(res),
    )

"""
Return an array of variable names (strings) that are available for reads.
"""
list_variable_names(res::SimulationProblemResults) =
    encode_keys_as_strings(list_variable_keys(res))

"""
Return an array of dual names (strings) that are available for reads.
"""
list_dual_names(res::SimulationProblemResults) =
    encode_keys_as_strings(list_dual_keys(res))

"""
Return an array of parmater names (strings) that are available for reads.
"""
list_parameter_names(res::SimulationProblemResults) =
    encode_keys_as_strings(list_parameter_keys(res))

"""
Return an array of auxillary variable names (strings) that are available for reads.
"""
list_aux_variable_names(res::SimulationProblemResults) =
    encode_keys_as_strings(list_aux_variable_keys(res))

"""
Return an array of expression names (strings) that are available for reads.
"""
list_expression_names(res::SimulationProblemResults) =
    encode_keys_as_strings(list_expression_keys(res))

"""
Return a reference to a StepRange of available timestamps.
"""
get_timestamps(result::SimulationProblemResults) = result.timestamps

"""
Return the system used for the problem. If the system hasn't already been deserialized or
set with [`set_system!`](@ref) then deserialize and store it.

If the simulation was configured to serialize all systems to file then the returned system
will include all data. If that was not configured then the returned system will include
all data except time series data.
"""
function get_system!(results::SimulationProblemResults; kwargs...)
    !isnothing(results.system) && return results.system

    file = joinpath(
        results.execution_path,
        "problems",
        results.problem,
        make_system_filename(results.system_uuid),
    )

    # This flag should remain unpublished because it should never be needed
    # by the general audience.
    if !get(kwargs, :use_h5_system, false) && isfile(file)
        system = PSY.System(file; time_series_read_only = true)
        @info "De-serialized the system from files."
    else
        system = _deserialize_system(results, results.store)
    end

    results.system = system
    return results.system
end

function _deserialize_system(results::SimulationProblemResults, ::Nothing)
    open_store(
        HdfSimulationStore,
        joinpath(get_execution_path(results), "data_store"),
        "r",
    ) do store
        system = deserialize_system(store, results.system_uuid)
        @info "De-serialized the system from the simulation store. The system does " *
              "not include time series data."
        return system
    end
end

function _deserialize_system(::SimulationProblemResults, ::InMemorySimulationStore)
    # This should never be necessary because the system is guaranteed to be in memory.
    error("Deserializing a system from the InMemorySimulationStore is not supported.")
end

"""
Set the system in the results instance.

Throws InvalidValue if the system UUID is incorrect.

# Arguments

  - `results::SimulationProblemResults`: Results object
  - `system::AbstractString`: Path to the system json file

# Examples

```julia
julia > set_system!(res, "my_path/system_data.json")
```
"""
function set_system!(results::SimulationProblemResults, system::AbstractString)
    set_system!(results, System(system))
end

function set_system!(results::SimulationProblemResults, system::PSY.System)
    sys_uuid = IS.get_uuid(system)
    if sys_uuid != results.system_uuid
        throw(
            IS.InvalidValue(
                "System mismatch. $sys_uuid does not match the stored value of $(results.system_uuid)",
            ),
        )
    end

    results.system = system
    return
end

function _deserialize_key(
    ::Type{<:OptimizationContainerKey},
    results::SimulationProblemResults,
    name::AbstractString,
)
    !haskey(results.values.container_key_lookup, name) && error("$name is not stored")
    return results.values.container_key_lookup[name]
end

function _deserialize_key(
    ::Type{T},
    results::SimulationProblemResults,
    args...,
) where {T <: OptimizationContainerKey}
    return make_key(T, args...)
end

get_container_fields(x::SimulationProblemResults) =
    (:aux_variables, :duals, :expressions, :parameters, :variables)

function _validate_keys(existing_keys, result_keys)
    diff = setdiff(result_keys, existing_keys)
    if !isempty(diff)
        throw(IS.InvalidValue("These keys are not stored: $diff"))
    end
    return
end

"""
Return the final values for the requested variables for each time step for a problem.

Decision problem results are returned in a Dict{String, Dict{DateTime, DataFrame}}.

Emulation problem results are returned in a Dict{String, DataFrame}.

Limit the data sizes returned by specifying `initial_time` and `count` for decision problems
or `start_time` and `len` for emulation problems.

If the Julia process is started with multiple threads, the code will read the variables in
parallel.

See also [`load_results!`](@ref) to preload data into memory.

# Arguments

  - `variables::Vector{Union{String, Tuple}}`: Variable name as a string or a Tuple with
    variable type and device type. If not provided then return all variables.
  - `initial_time::Dates.DateTime`: Initial time of the requested results. Decision problems
    only.
  - `count::Int`: Number of results. Decision problems only.
  - `start_time::Dates.DateTime`: Start time of the requested results. Emulation problems
    only.
  - `len::Int`: Number of rows in each DataFrame. Emulation problems only.

# Examples

```julia
julia > variables_as_strings =
    ["ActivePowerVariable__ThermalStandard", "ActivePowerVariable__RenewableDispatch"]
julia > variables_as_types =
    [(ActivePowerVariable, ThermalStandard), (ActivePowerVariable, RenewableDispatch)]
julia > read_realized_variables(results, variables_as_strings)
julia > read_realized_variables(results, variables_as_types)
```
"""
function read_realized_variables(res::SimulationProblemResults; kwargs...)
    return read_realized_variables(res, list_variable_keys(res); kwargs...)
end

function read_realized_variables(
    res::SimulationProblemResults,
    variables::Vector{Tuple{DataType, DataType}};
    kwargs...,
)
    return read_realized_variables(
        res,
        [VariableKey(x...) for x in variables];
        kwargs...,
    )
end

function read_realized_variables(
    res::SimulationProblemResults,
    variables::Vector{<:AbstractString};
    kwargs...,
)
    return read_realized_variables(
        res,
        [_deserialize_key(VariableKey, res, x) for x in variables];
        kwargs...,
    )
end

function read_realized_variables(
    res::SimulationProblemResults,
    variables::Vector{<:OptimizationContainerKey};
    kwargs...,
)
    result_values = read_results_with_keys(res, variables; kwargs...)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

"""
Return the final values for the requested variable for each time step for a problem.

Decision problem results are returned in a Dict{DateTime, DataFrame}.

Emulation problem results are returned in a DataFrame.

Limit the data sizes returned by specifying `initial_time` and `count` for decision problems
or `start_time` and `len` for emulation problems.

See also [`load_results!`](@ref) to preload data into memory.

# Arguments

  - `variable::Union{String, Tuple}`: Variable name as a string or a Tuple with
    variable type and device type.
  - `initial_time::Dates.DateTime`: Initial time of the requested results. Decision problems
    only.
  - `count::Int`: Number of results. Decision problems only.
  - `start_time::Dates.DateTime`: Start time of the requested results. Emulation problems
    only.
  - `len::Int`: Number of rows in each DataFrame. Emulation problems only.

# Examples

```julia
julia > read_realized_variable(results, "ActivePowerVariable__ThermalStandard")
julia > read_realized_variable(results, (ActivePowerVariable, ThermalStandard))
```
"""
function read_realized_variable(
    res::SimulationProblemResults,
    variable::AbstractString;
    kwargs...,
)
    return first(
        values(
            read_realized_variables(
                res,
                [_deserialize_key(VariableKey, res, variable)];
                kwargs...,
            ),
        ),
    )
end

function read_realized_variable(res::SimulationProblemResults, variable...; kwargs...)
    return first(
        values(read_realized_variables(res, [VariableKey(variable...)]; kwargs...)),
    )
end

"""
Return the final values for the requested auxiliary variables for each time step for a problem.

Refer to [`read_realized_aux_variables`](@ref) for help and examples.
"""
function read_realized_aux_variables(res::SimulationProblemResults; kwargs...)
    return read_realized_aux_variables(
        res,
        list_aux_variable_keys(res);
        kwargs...,
    )
end

function read_realized_aux_variables(
    res::SimulationProblemResults,
    aux_variables::Vector{Tuple{DataType, DataType}};
    kwargs...,
)
    return read_realized_aux_variables(
        res,
        [AuxVarKey(x...) for x in aux_variables];
        kwargs...,
    )
end

function read_realized_aux_variables(
    res::SimulationProblemResults,
    aux_variables::Vector{<:AbstractString};
    kwargs...,
)
    return read_realized_aux_variables(
        res,
        [_deserialize_key(AuxVarKey, res, x) for x in aux_variables];
        kwargs...,
    )
end

function read_realized_aux_variables(
    res::SimulationProblemResults,
    aux_variables::Vector{<:OptimizationContainerKey};
    kwargs...,
)
    result_values = read_results_with_keys(res, aux_variables; kwargs...)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

"""
Return the final values for the requested auxiliary variable for each time step for a problem.

Refer to [`read_realized_variable`](@ref) for help and examples.
"""
function read_realized_aux_variable(
    res::SimulationProblemResults,
    aux_variable::AbstractString;
    kwargs...,
)
    return first(
        values(
            read_realized_aux_variables(
                res,
                [_deserialize_key(AuxVarKey, res, aux_variable)];
                kwargs...,
            ),
        ),
    )
end

function read_realized_aux_variable(
    res::SimulationProblemResults,
    aux_variable...;
    kwargs...,
)
    return first(
        values(
            read_realized_aux_variables(res, [AuxVarKey(aux_variable...)]; kwargs...),
        ),
    )
end

"""
Return the final values for the requested parameters for each time step for a problem.

Refer to [`read_realized_parameters`](@ref) for help and examples.
"""
function read_realized_parameters(res::SimulationProblemResults; kwargs...)
    return read_realized_parameters(res, list_parameter_keys(res); kwargs...)
end

function read_realized_parameters(
    res::SimulationProblemResults,
    parameters::Vector{Tuple{DataType, DataType}};
    kwargs...,
)
    return read_realized_parameters(
        res,
        [ParameterKey(x...) for x in parameters];
        kwargs...,
    )
end

function read_realized_parameters(
    res::SimulationProblemResults,
    parameters::Vector{<:AbstractString};
    kwargs...,
)
    return read_realized_parameters(
        res,
        [_deserialize_key(ParameterKey, res, x) for x in parameters];
        kwargs...,
    )
end

function read_realized_parameters(
    res::SimulationProblemResults,
    parameters::Vector{<:OptimizationContainerKey};
    kwargs...,
)
    result_values = read_results_with_keys(res, parameters; kwargs...)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

"""
Return the final values for the requested parameter for each time step for a problem.

Refer to [`read_realized_variable`](@ref) for help and examples.
"""
function read_realized_parameter(
    res::SimulationProblemResults,
    parameter::AbstractString;
    kwargs...,
)
    return first(
        values(
            read_realized_parameters(
                res,
                [_deserialize_key(ParameterKey, res, parameter)];
                kwargs...,
            ),
        ),
    )
end

function read_realized_parameter(res::SimulationProblemResults, parameter...; kwargs...)
    return first(
        values(read_realized_parameters(res, [ParameterKey(parameter...)]; kwargs...)),
    )
end

"""
Return the final values for the requested duals for each time step for a problem.

Refer to [`read_realized_duals`](@ref) for help and examples.
"""
function read_realized_duals(res::SimulationProblemResults; kwargs...)
    return read_realized_duals(res, list_dual_keys(res); kwargs...)
end

function read_realized_duals(
    res::SimulationProblemResults,
    duals::Vector{Tuple{DataType, DataType}};
    kwargs...,
)
    return read_realized_duals(res, [ConstraintKey(x...) for x in duals]; kwargs...)
end

function read_realized_duals(
    res::SimulationProblemResults,
    duals::Vector{<:AbstractString};
    kwargs...,
)
    return read_realized_duals(
        res,
        [_deserialize_key(ConstraintKey, res, x) for x in duals];
        kwargs...,
    )
end

function read_realized_duals(
    res::SimulationProblemResults,
    duals::Vector{<:OptimizationContainerKey};
    kwargs...,
)
    result_values = read_results_with_keys(res, duals; kwargs...)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

"""
Return the final values for the requested dual for each time step for a problem.

Refer to [`read_realized_variable`](@ref) for help and examples.
"""
function read_realized_dual(res::SimulationProblemResults, dual::AbstractString; kwargs...)
    return first(
        values(
            read_realized_duals(
                res,
                [_deserialize_key(ConstraintKey, res, dual)];
                kwargs...,
            ),
        ),
    )
end

function read_realized_dual(res::SimulationProblemResults, dual...; kwargs...)
    return first(values(read_realized_duals(res, [ConstraintKey(dual...)]; kwargs...)))
end

"""
Return the final values for the requested expressions for each time step for a problem.

Refer to [`read_realized_expressions`](@ref) for help and examples.
"""
function read_realized_expressions(res::SimulationProblemResults; kwargs...)
    return read_realized_expressions(res, list_expression_keys(res); kwargs...)
end

function read_realized_expressions(
    res::SimulationProblemResults,
    expressions::Vector{Tuple{DataType, DataType}};
    kwargs...,
)
    return read_realized_expressions(
        res,
        [ExpressionKey(x...) for x in expressions];
        kwargs...,
    )
end

function read_realized_expressions(
    res::SimulationProblemResults,
    expressions::Vector{<:AbstractString};
    kwargs...,
)
    return read_realized_expressions(
        res,
        [_deserialize_key(ExpressionKey, res, x) for x in expressions];
        kwargs...,
    )
end

function read_realized_expressions(
    res::SimulationProblemResults,
    expressions::Vector{<:OptimizationContainerKey};
    kwargs...,
)
    result_values = read_results_with_keys(res, expressions; kwargs...)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

"""
Return the final values for the requested expression for each time step for a problem.

Refer to [`read_realized_variable`](@ref) for help and examples.
"""
function read_realized_expression(
    res::SimulationProblemResults,
    expression::AbstractString;
    kwargs...,
)
    return first(
        values(
            read_realized_expressions(
                res,
                [_deserialize_key(ExpressionKey, res, expression)];
                kwargs...,
            ),
        ),
    )
end

function read_realized_expression(res::SimulationProblemResults, expression...; kwargs...)
    return first(
        values(
            read_realized_expressions(res, [ExpressionKey(expression...)]; kwargs...),
        ),
    )
end

"""
Return the optimizer stats for the problem as a DataFrame.

# Accepted keywords

  - `store::SimulationStore`: a store that has been opened for reading
"""
function read_optimizer_stats(res::SimulationProblemResults; store = nothing)
    _store = isnothing(store) ? res.store : store
    return _read_optimizer_stats(res, _store)
end

function _read_optimizer_stats(res::SimulationProblemResults, ::Nothing)
    open_store(
        HdfSimulationStore,
        joinpath(get_execution_path(res), "data_store"),
        "r",
    ) do store
        _read_optimizer_stats(res, store)
    end
end

"""
Save the realized results to CSV files for all variables, paramaters, duals, auxiliary variables,
expressions, and optimizer statistics.

# Arguments

  - `res::Union{OptimizationProblemResults, SimulationProblmeResults`: Results
  - `save_path::AbstractString` : path to save results (defaults to simulation path)
"""
function export_realized_results(res::SimulationProblemResults)
    save_path = mkpath(joinpath(res.results_output_folder, "export"))
    return export_realized_results(res, save_path)
end

function export_realized_results(
    res::Union{OptimizationProblemResults, SimulationProblemResults},
    save_path::AbstractString,
)
    if !isdir(save_path)
        throw(IS.ConflictingInputsError("Specified path is not valid."))
    end
    write_data(read_results_with_keys(res, list_variable_keys(res)), save_path)
    !isempty(list_dual_keys(res)) &&
        write_data(
            read_results_with_keys(res, list_dual_keys(res)),
            save_path;
            name = "dual",
        )
    !isempty(list_parameter_keys(res)) && write_data(
        read_results_with_keys(res, list_parameter_keys(res)),
        save_path;
        name = "parameter",
    )
    !isempty(list_aux_variable_keys(res)) && write_data(
        read_results_with_keys(res, list_aux_variable_keys(res)),
        save_path;
        name = "aux_variable",
    )
    !isempty(list_expression_keys(res)) && write_data(
        read_results_with_keys(res, list_expression_keys(res)),
        save_path;
        name = "expression",
    )
    export_optimizer_stats(res, save_path)
    files = readdir(save_path)
    compute_file_hash(save_path, files)
    @info("Files written to $save_path folder.")
    return save_path
end

"""
Save the optimizer statistics to CSV or JSON

# Arguments

  - `res::Union{OptimizationProblemResults, SimulationProblmeResults`: Results
  - `directory::AbstractString` : target directory
  - `format = "CSV"` : can be "csv" or "json
"""
function export_optimizer_stats(
    res::Union{OptimizationProblemResults, SimulationProblemResults},
    directory::AbstractString;
    format = "csv",
)
    data = read_optimizer_stats(res)
    isnothing(data) && return
    if uppercase(format) == "CSV"
        CSV.write(joinpath(directory, "optimizer_stats.csv"), data)
    elseif uppercase(format) == "JSON"
        JSON.write(joinpath(directory, "optimizer_stats.json"), JSON.json(to_dict(data)))
    else
        throw(error("writing optimizer stats only supports csv or json formats"))
    end
end

# Chooses the user-passed store or results store for reading values. Either could be
# something or nothing. If both are nothing, we must open the HDF5 store.
try_resolve_store(user::SimulationStore, results::Union{Nothing, SimulationStore}) = user
try_resolve_store(user::Nothing, results::SimulationStore) = results
try_resolve_store(user::Nothing, results::Nothing) = nothing
