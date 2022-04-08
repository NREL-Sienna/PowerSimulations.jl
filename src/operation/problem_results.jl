# This needs renaming to avoid collision with the DecionModelResults/EmulationModelResults
mutable struct ProblemResults <: IS.Results
    base_power::Float64
    timestamps::StepRange{Dates.DateTime, Dates.Millisecond}
    system::Union{Nothing, PSY.System}
    system_uuid::Base.UUID
    aux_variable_values::Dict{AuxVarKey, DataFrames.DataFrame}
    variable_values::Dict{VariableKey, DataFrames.DataFrame}
    dual_values::Dict{ConstraintKey, DataFrames.DataFrame}
    parameter_values::Dict{ParameterKey, DataFrames.DataFrame}
    expression_values::Dict{ExpressionKey, DataFrames.DataFrame}
    optimizer_stats::DataFrames.DataFrame
    optimization_container_metadata::OptimizationContainerMetadata
    model_type::String
    output_dir::String
end

list_aux_variable_keys(res::ProblemResults) = collect(keys(res.aux_variable_values))
list_aux_variable_names(res::ProblemResults) =
    encode_keys_as_strings(keys(res.aux_variable_values))
list_variable_keys(res::ProblemResults) = collect(keys(res.variable_values))
list_variable_names(res::ProblemResults) = encode_keys_as_strings(keys(res.variable_values))
list_parameter_keys(res::ProblemResults) = collect(keys(res.parameter_values))
list_parameter_names(res::ProblemResults) =
    encode_keys_as_strings(keys(res.parameter_values))
list_dual_keys(res::ProblemResults) = collect(keys(res.dual_values))
list_dual_names(res::ProblemResults) = encode_keys_as_strings(keys(res.dual_values))
list_expression_keys(res::ProblemResults) = collect(keys(res.expression_values))
list_expression_names(res::ProblemResults) =
    encode_keys_as_strings(keys(res.expression_values))
get_timestamps(res::ProblemResults) = res.timestamps
get_model_base_power(res::ProblemResults) = res.base_power
get_dual_values(res::ProblemResults) = res.dual_values
get_expression_values(res::ProblemResults) = res.expression_values
get_variable_values(res::ProblemResults) = res.variable_values
get_aux_variable_values(res::ProblemResults) = res.aux_variable_values
get_total_cost(res::ProblemResults) = get_objective_value(res)
get_optimizer_stats(res::ProblemResults) = res.optimizer_stats
get_parameter_values(res::ProblemResults) = res.parameter_values
get_resolution(res::ProblemResults) = res.timestamps.step
get_system(res::ProblemResults) = res.system
get_forecast_horizon(res::ProblemResults) = length(get_timestamps(res))

function get_objective_value(res::ProblemResults, execution=1)
    return res.optimizer_stats[execution, :objective_value]
end

"""
Construct ProblemResults from a solved DecisionModel.
"""
function ProblemResults(model::DecisionModel)
    status = get_run_status(model)
    status != RunStatus.SUCCESSFUL && error("problem was not solved successfully: $status")

    model_store = get_store(model)

    if isempty(model_store)
        error("Model Solved as part of a Simulation.")
    end

    timestamps = get_timestamps(model)
    optimizer_stats = to_dataframe(get_optimizer_stats(model))

    aux_variable_values =
        Dict(x => read_aux_variable(model, x) for x in list_aux_variable_keys(model))
    variable_values = Dict(x => read_variable(model, x) for x in list_variable_keys(model))
    dual_values = Dict(x => read_dual(model, x) for x in list_dual_keys(model))
    parameter_values =
        Dict(x => read_parameter(model, x) for x in list_parameter_keys(model))
    expression_values =
        Dict(x => read_expression(model, x) for x in list_expression_keys(model))

    sys = get_system(model)

    return ProblemResults(
        get_problem_base_power(model),
        timestamps,
        sys,
        IS.get_uuid(sys),
        aux_variable_values,
        variable_values,
        dual_values,
        parameter_values,
        expression_values,
        optimizer_stats,
        get_metadata(get_optimization_container(model)),
        IS.strip_module_name(typeof(model)),
        mkpath(joinpath(get_output_dir(model), "results")),
    )
end

"""
Construct ProblemResults from a solved EmulationModel.
"""
function ProblemResults(model::EmulationModel)
    status = get_run_status(model)
    status != RunStatus.SUCCESSFUL && error("problem was not solved successfully: $status")

    model_store = get_store(model)

    if isempty(model_store)
        error("Model Solved as part of a Simulation.")
    end

    aux_variables =
        Dict(x => read_aux_variable(model, x) for x in list_aux_variable_keys(model))
    variables = Dict(x => read_variable(model, x) for x in list_variable_keys(model))
    duals = Dict(x => read_dual(model, x) for x in list_dual_keys(model))
    parameters = Dict(x => read_parameter(model, x) for x in list_parameter_keys(model))
    expression = Dict(x => read_expression(model, x) for x in list_expression_keys(model))
    optimizer_stats = read_optimizer_stats(model)
    initial_time = get_initial_time(model)
    container = get_optimization_container(model)
    sys = get_system(model)

    return ProblemResults(
        get_problem_base_power(model),
        StepRange(initial_time, get_resolution(model), initial_time),
        sys,
        IS.get_uuid(sys),
        aux_variables,
        variables,
        duals,
        parameters,
        expression,
        optimizer_stats,
        get_metadata(container),
        IS.strip_module_name(typeof(model)),
        mkpath(joinpath(get_output_dir(model), "results")),
    )
end

"""
Exports all results from the operations problem.
"""
function export_results(results::ProblemResults; kwargs...)
    exports = ProblemResultsExport(
        "Problem",
        store_all_duals=true,
        store_all_parameters=true,
        store_all_variables=true,
        store_all_aux_variables=true,
    )
    return export_results(results, exports; kwargs...)
end

function export_results(
    results::ProblemResults,
    exports::ProblemResultsExport;
    file_type=CSV.File,
)
    file_type != CSV.File && error("only CSV.File is currently supported")
    export_path = mkpath(joinpath(results.output_dir, "variables"))
    for (key, df) in results.variable_values
        if should_export_variable(exports, key)
            export_result(file_type, export_path, key, df)
        end
    end

    export_path = mkpath(joinpath(results.output_dir, "aux_variables"))
    for (key, df) in results.aux_variable_values
        if should_export_aux_variable(exports, key)
            export_result(file_type, export_path, key, df)
        end
    end

    export_path = mkpath(joinpath(results.output_dir, "duals"))
    for (key, df) in results.dual_values
        if should_export_dual(exports, key)
            export_result(file_type, export_path, key, df)
        end
    end

    export_path = mkpath(joinpath(results.output_dir, "parameters"))
    for (key, df) in results.parameter_values
        if should_export_parameter(exports, key)
            export_result(file_type, export_path, key, df)
        end
    end

    export_path = mkpath(joinpath(results.output_dir, "expressions"))
    for (key, df) in results.expression_values
        if should_export_expression(exports, key)
            export_result(file_type, export_path, key, df)
        end
    end

    if exports.optimizer_stats
        export_result(
            file_type,
            joinpath(results.output_dir, "optimizer_stats.csv"),
            results.optimizer_stats,
        )
    end

    @info "Exported ProblemResults to $(results.output_dir)"
end

function _deserialize_key(
    ::Type{<:OptimizationContainerKey},
    results::ProblemResults,
    name::AbstractString,
)
    return deserialize_key(results.optimization_container_metadata, name)
end

function _deserialize_key(
    ::Type{T},
    ::ProblemResults,
    args...,
) where {T <: OptimizationContainerKey}
    return make_key(T, args...)
end

read_optimizer_stats(res::ProblemResults) = res.optimizer_stats

"""
Set the system in the results instance.

Throws InvalidValue if the system UUID is incorrect.
"""
function set_system!(res::ProblemResults, system::PSY.System)
    sys_uuid = IS.get_uuid(system)
    if sys_uuid != res.system_uuid
        throw(
            IS.InvalidValue(
                "System mismatch. $sys_uuid does not match the stored value of $(res.system_uuid)",
            ),
        )
    end

    res.system = system
    return
end

const _PROBLEM_RESULTS_FILENAME = "problem_results.bin"

"""
Serialize the results to a binary file.

It is recommended that `directory` be the directory that contains a serialized
OperationModel. That will allow automatic deserialization of the PowerSystems.System.
The `ProblemResults` instance can be deserialized with `ProblemResults(directory)`.
"""
function serialize_results(res::ProblemResults, directory::AbstractString)
    mkpath(directory)
    filename = joinpath(directory, _PROBLEM_RESULTS_FILENAME)
    isfile(filename) && rm(filename)
    Serialization.serialize(filename, _copy_for_serialization(res))
    @info "Serialize ProblemResults to $filename"
end

"""
Construct a ProblemResults instance from a serialized directory.

If the directory contains a serialized PowerSystems.System then it will deserialize that
system and add it to the results. Otherwise, it is up to the caller to call
[`set_system!`](@ref) on the returned instance to restore it.
"""
function ProblemResults(directory::AbstractString)
    filename = joinpath(directory, _PROBLEM_RESULTS_FILENAME)
    if !isfile(filename)
        error("No results file exists in $directory")
    end

    results = Serialization.deserialize(filename)
    possible_sys_file = joinpath(directory, make_system_filename(results.system_uuid))
    if isfile(possible_sys_file)
        set_system!(results, PSY.System(possible_sys_file))
    else
        @info "$directory does not contain a serialized System, skipping deserialization."
    end

    return results
end

function _copy_for_serialization(res::ProblemResults)
    return ProblemResults(
        res.base_power,
        res.timestamps,
        nothing,
        res.system_uuid,
        res.aux_variable_values,
        res.variable_values,
        res.dual_values,
        res.parameter_values,
        res.expression_values,
        res.optimizer_stats,
        res.optimization_container_metadata,
        res.model_type,
        res.output_dir,
    )
end

function _read_results(
    result_values::Dict{<:OptimizationContainerKey, DataFrames.DataFrame},
    container_keys,
    timestamps,
    time_ids,
    base_power,
)
    existing_keys = keys(result_values)
    container_keys = container_keys === nothing ? existing_keys : container_keys
    _validate_keys(existing_keys, container_keys)
    results = Dict{OptimizationContainerKey, DataFrames.DataFrame}()
    for (k, v) in result_values
        if k in container_keys
            results[k] =
                convert_result_to_natural_units(k) ? v[time_ids, :] .* base_power :
                v[time_ids, :]
            DataFrames.insertcols!(results[k], 1, :DateTime => timestamps)
        end
    end
    return results
end

function _process_timestamps(
    res::ProblemResults,
    start_time::Union{Nothing, Dates.DateTime},
    len::Union{Int, Nothing},
)
    if start_time === nothing
        start_time = first(get_timestamps(res))
    elseif start_time ∉ get_timestamps(res)
        throw(IS.InvalidValue("start_time not in result timestamps"))
    end

    if startswith(res.model_type, "EmulationModel{")
        def_len = DataFrames.nrow(get_optimizer_stats(res))
        requested_range =
            collect(findfirst(x -> x >= start_time, get_timestamps(res)):def_len)
        timestamps = repeat(get_timestamps(res), def_len)
    else
        timestamps = get_timestamps(res)
        requested_range = findall(x -> x >= start_time, timestamps)
        def_len = length(requested_range)
    end
    len = len === nothing ? def_len : len
    if len > def_len
        throw(IS.InvalidValue("requested results have less than $len values"))
    end
    timestamp_ids = requested_range[1:len]
    return timestamp_ids, timestamps[timestamp_ids]
end

"""
Return the values for the requested variable key for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [load_results!](@ref) function it will read from memory.

# Arguments

  - `variable::Tuple{Type{<:VariableType}, Type{<:PSY.Component}` : Tuple with variable type and device type for the desired results
  - `start_time::Dates.DateTime` : start time of the requested results
  - `len::Int`: length of results
"""
function read_variable(res::ProblemResults, args...; kwargs...)
    key = VariableKey(args...)
    return read_variable(res, key; kwargs...)
end

function read_variable(res::ProblemResults, key::AbstractString; kwargs...)
    return read_variable(res, _deserialize_key(VariableKey, res, key); kwargs...)
end

function read_variable(
    res::ProblemResults,
    key::VariableKey;
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    return read_variables_with_keys(res, [key]; start_time=start_time, len=len)[key]
end

"""
Return the values for the requested variable keys for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [load_results!](@ref) function it will read from memory.

# Arguments

  - `variables::Vector{Tuple{Type{<:VariableType}, Type{<:PSY.Component}}` : Tuple with variable type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_variables(res::ProblemResults, variables; kwargs...)
    return read_variables(res, [VariableKey(x...) for x in variables]; kwargs...)
end

function read_variables(res::ProblemResults, variables::Vector{<:AbstractString}; kwargs...)
    return read_variables(
        res,
        [_deserialize_key(VariableKey, res, x) for x in variables];
        kwargs...,
    )
end

function read_variables(
    res::ProblemResults,
    variables::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    result_values = read_variables_with_keys(res, variables; start_time=start_time, len=len)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

"""
Return the values for all variables.
"""
function read_variables(res::IS.Results)
    variables = Dict(x => read_variable(res, x) for x in list_variable_names(res))
end

function read_variables_with_keys(
    res::ProblemResults,
    variables::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    (timestamp_ids, timestamps) = _process_timestamps(res, start_time, len)
    return _read_results(
        res.variable_values,
        variables,
        timestamps,
        timestamp_ids,
        get_model_base_power(res),
    )
end

"""
Return the values for the requested dual key for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [load_results!](@ref) function it will read from memory.

# Arguments

  - `dual::Tuple{Type{<:ConstraintType}, Type{<:PSY.Component}` : Tuple with dual type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_dual(res::ProblemResults, args...; kwargs...)
    key = ConstraintKey(args...)
    return read_dual(res, key; kwargs...)
end

function read_dual(res::ProblemResults, key::AbstractString; kwargs...)
    return read_dual(res, _deserialize_key(ConstraintKey, res, key); kwargs...)
end

function read_dual(
    res::ProblemResults,
    key::ConstraintKey;
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    return read_duals_with_keys(res, [key]; start_time=start_time, len=len)[key]
end

"""
Return the values for the requested dual keys for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [load_results!](@ref) function it will read from memory.

# Arguments

  - `duals::Vector{Tuple{Type{<:ConstraintType}, Type{<:PSY.Component}}` : Tuple with dual type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_duals(res::ProblemResults, duals; kwargs...)
    return read_duals(res, [ConstraintKey(x...) for x in duals]; kwargs...)
end

function read_duals(res::ProblemResults, duals::Vector{<:AbstractString}; kwargs...)
    return read_duals(
        res,
        [_deserialize_key(ConstraintKey, res, x) for x in duals];
        kwargs...,
    )
end

function read_duals(
    res::ProblemResults,
    duals::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    result_values = read_duals_with_keys(res, duals; start_time=start_time, len=len)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

"""
Return the values for all duals.
"""
function read_duals(res::IS.Results)
    duals = Dict(x => read_dual(res, x) for x in list_dual_names(res))
end

function read_duals_with_keys(
    res::ProblemResults,
    duals::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    (timestamp_ids, timestamps) = _process_timestamps(res, start_time, len)
    return _read_results(
        res.dual_values,
        duals,
        timestamps,
        timestamp_ids,
        get_model_base_power(res),
    )
end

"""
Return the values for the requested parameter key for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [load_results!](@ref) function it will read from memory.

# Arguments

  - `parameter::Tuple{Type{<:ParameterType}, Type{<:PSY.Component}` : Tuple with parameter type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_parameter(res::ProblemResults, args...; kwargs...)
    key = ParameterKey(args...)
    return read_parameter(res, key; kwargs...)
end

function read_parameter(res::ProblemResults, key::AbstractString; kwargs...)
    return read_parameter(res, _deserialize_key(ParameterKey, res, key); kwargs...)
end

function read_parameter(
    res::ProblemResults,
    key::ParameterKey;
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    return read_parameters_with_keys(res, [key]; start_time=start_time, len=len)[key]
end

"""
Return the values for the requested parameter keys for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [load_results!](@ref) function it will read from memory.

# Arguments

  - `parameters::Vector{Tuple{Type{<:ParameterType}, Type{<:PSY.Component}}` : Tuple with parameter type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_parameters(res::ProblemResults, parameters; kwargs...)
    return read_parameters(res, [ParameterKey(x...) for x in parameters]; kwargs...)
end

function read_parameters(
    res::ProblemResults,
    parameters::Vector{<:AbstractString};
    kwargs...,
)
    return read_parameters(
        res,
        [_deserialize_key(ParameterKey, res, x) for x in parameters];
        kwargs...,
    )
end

function read_parameters(
    res::ProblemResults,
    parameters::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    result_values =
        read_parameters_with_keys(res, parameters; start_time=start_time, len=len)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

"""
Return the values for all parameters.
"""
function read_parameters(res::IS.Results)
    parameters = Dict(x => read_parameter(res, x) for x in list_parameter_names(res))
end

function read_parameters_with_keys(
    res::ProblemResults,
    parameters::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    (timestamp_ids, timestamps) = _process_timestamps(res, start_time, len)
    return _read_results(
        res.parameter_values,
        parameters,
        timestamps,
        timestamp_ids,
        get_model_base_power(res),
    )
end

"""
Return the values for the requested aux_variable key for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [load_results!](@ref) function it will read from memory.

# Arguments

  - `aux_variable::Tuple{Type{<:AuxVariableType}, Type{<:PSY.Component}` : Tuple with aux_variable type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_aux_variable(res::ProblemResults, args...; kwargs...)
    key = AuxVarKey(args...)
    return read_aux_variable(res, key; kwargs...)
end

function read_aux_variable(res::ProblemResults, key::AbstractString; kwargs...)
    return read_aux_variable(res, _deserialize_key(AuxVarKey, res, key); kwargs...)
end

function read_aux_variable(
    res::ProblemResults,
    key::AuxVarKey;
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    return read_aux_variables_with_keys(res, [key]; start_time=start_time, len=len)[key]
end

"""
Return the values for the requested aux_variable keys for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [load_results!](@ref) function it will read from memory.

# Arguments

  - `aux_variables::Vector{Tuple{Type{<:AuxVariableType}, Type{<:PSY.Component}}` : Tuple with aux_variable type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_aux_variables(res::ProblemResults, aux_variables; kwargs...)
    return read_aux_variables(res, [AuxVarKey(x...) for x in aux_variables]; kwargs...)
end

function read_aux_variables(
    res::ProblemResults,
    aux_variables::Vector{<:AbstractString};
    kwargs...,
)
    return read_aux_variables(
        res,
        [_deserialize_key(AuxVarKey, res, x) for x in aux_variables];
        kwargs...,
    )
end

function read_aux_variables(
    res::ProblemResults,
    aux_variables::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    result_values =
        read_aux_variables_with_keys(res, aux_variables; start_time=start_time, len=len)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

"""
Return the values for all auxiliary variables.
"""
function read_aux_variables(res::IS.Results)
    variables = Dict(x => read_aux_variable(res, x) for x in list_aux_variable_names(res))
end

function read_aux_variables_with_keys(
    res::ProblemResults,
    aux_variables::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    (timestamp_ids, timestamps) = _process_timestamps(res, start_time, len)
    return _read_results(
        res.aux_variable_values,
        aux_variables,
        timestamps,
        timestamp_ids,
        get_model_base_power(res),
    )
end

"""
Return the values for the requested expression key for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [load_results!](@ref) function it will read from memory.

# Arguments

  - `expression::Tuple{Type{<:ExpressionType}, Type{<:PSY.Component}` : Tuple with expression type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_expression(res::ProblemResults, args...; kwargs...)
    key = ExpressionKey(args...)
    return read_expression(res, key; kwargs...)
end

function read_expression(res::ProblemResults, key::AbstractString; kwargs...)
    return read_expression(res, _deserialize_key(ExpressionKey, res, key); kwargs...)
end

function read_expression(
    res::ProblemResults,
    key::ExpressionKey;
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    return read_expressions_with_keys(res, [key]; start_time=start_time, len=len)[key]
end

"""
Return the values for the requested expression keys for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [load_results!](@ref) function it will read from memory.

# Arguments

  - `expressions::Vector{Tuple{Type{<:ExpressionType}, Type{<:PSY.Component}}` : Tuple with expression type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_expressions(res::ProblemResults; kwargs...)
    return read_expressions(res, collect(keys(res.expression_values)); kwargs...)
end

function read_expressions(res::ProblemResults, expressions; kwargs...)
    return read_expressions(res, [ExpressionKey(x...) for x in expressions]; kwargs...)
end

function read_expressions(
    res::ProblemResults,
    expressions::Vector{<:AbstractString};
    kwargs...,
)
    return read_expressions(
        res,
        [_deserialize_key(ExpressionKey, res, x) for x in expressions];
        kwargs...,
    )
end

function read_expressions(
    res::ProblemResults,
    expressions::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    result_values =
        read_expressions_with_keys(res, expressions; start_time=start_time, len=len)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

"""
Return the values for all expressions.
"""
function read_expressions(res::IS.Results)
    expressions = Dict(x => read_expression(res, x) for x in list_expression_names(res))
end

function read_expressions_with_keys(
    res::ProblemResults,
    expressions::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    (timestamp_ids, timestamps) = _process_timestamps(res, start_time, len)
    return _read_results(
        res.expression_values,
        expressions,
        timestamps,
        timestamp_ids,
        get_model_base_power(res),
    )
end

function export_realized_results(res::ProblemResults)
    save_path = mkpath(joinpath(res.output_dir, "export"))
    return export_realized_results(res, save_path)
end
