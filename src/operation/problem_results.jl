# This needs renaming to avoid collision with the DecionModelResults/EmulationModelResults
mutable struct ProblemResults
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
get_expressionl_values(res::ProblemResults) = res.expression_values
get_variable_values(res::ProblemResults) = res.variable_values
get_total_cost(res::ProblemResults) = get_objective_value(res)
get_optimizer_stats(res::ProblemResults) = res.optimizer_stats
get_parameter_values(res::ProblemResults) = res.parameter_values
get_resolution(res::ProblemResults) = res.timestamps.step
get_system(res::ProblemResults) = res.system

function get_objective_value(res::ProblemResults, execution = 1)
    res.optimizer_stats[execution, :objective_value]
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
        store_all_duals = true,
        store_all_parameters = true,
        store_all_variables = true,
        store_all_aux_variables = true,
    )
    export_results(results, exports; kwargs...)
end

function export_results(
    results::ProblemResults,
    exports::ProblemResultsExport;
    file_type = CSV.File,
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

function read_aux_variable(res::ProblemResults, key::AuxVarKey)
    !haskey(res.aux_variable_values, key) && error("$key is not stored")
    return res.variable_values[key]
end

function read_aux_variable(res::ProblemResults, args...)
    key = _deserialize_key(AuxVarKey, res, args...)
    return read_aux_variable(res, key)
end

function read_variable(res::ProblemResults, key::VariableKey)
    !haskey(res.variable_values, key) && error("$key is not stored")
    return res.variable_values[key]
end

function read_variable(res::ProblemResults, args...)
    key = _deserialize_key(VariableKey, res, args...)
    return read_variable(res, key)
end

function read_parameter(res::ProblemResults, key::ParameterKey)
    !haskey(res.parameter_values, key) && error("$key is not stored")
    return res.parameter_values[key]
end

function read_parameter(res::ProblemResults, args...)
    key = _deserialize_key(ParameterKey, res, args...)
    return read_parameter(res, key)
end

function read_dual(res::ProblemResults, key::ConstraintKey)
    !haskey(res.dual_values, key) && error("$key is not stored")
    return res.dual_values[key]
end

function read_dual(res::ProblemResults, args...)
    key = _deserialize_key(ConstraintKey, res, args...)
    return read_dual(res, key)
end

function read_expression(res::ProblemResults, key::ExpressionKey)
    !haskey(res.expression_values, key) && error("$key is not stored")
    return res.expression_values[key]
end

function read_expression(res::ProblemResults, args...)
    key = _deserialize_key(ExpressionKey, res, args...)
    return read_expression(res, key)
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
end

# TODO:
# - Handle PER-UNIT conversion of variables according to type

function write_to_CSV(res::ProblemResults, save_path::String)
    if !isdir(save_path)
        throw(IS.ConflictingInputsError("Specified path is not valid."))
    end
    folder_path = mkdir(
        joinpath(save_path, replace_chars("$(round(Dates.now(), Dates.Minute))", ":", "-")),
    )
    export_variables = Dict()
    for (k, v) in IS.get_variables(res)
        export_variables[k] = v
    end
    write_data(export_variables, folder_path)
    if !isempty(get_duals(res))
        write_data(get_duals(res), folder_path; duals = true)
    end
    export_parameters = Dict()
    if !isempty(IS.get_parameters(res))
        for (p, v) in IS.get_parameters(res)
            export_parameters[p] = get_model_base_power(res) .* v
        end
        write_data(export_parameters, folder_path; params = true)
    end
    write_optimizer_stats(res, folder_path)
    files = readdir(folder_path)
    compute_file_hash(folder_path, files)
    @info("Files written to $folder_path folder.")
    return
end

function write_optimizer_stats(res::ProblemResults, directory::AbstractString)
    data = to_dict(res.optimizer_stats)
    JSON.write(joinpath(directory, "optimizer_stats.json"), JSON.json(data))
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

# TODO: These are not likely needed for v015.
_get_keys(::Type{ConstraintKey}, res, ::Nothing) = collect(keys(res.dual_values))
_get_keys(::Type{ParameterKey}, res, ::Nothing) = collect(keys(res.parameter_values))
_get_keys(::Type{VariableKey}, res, ::Nothing) = collect(keys(res.variable_values))

function _read_realized_results(
    result_values::Dict{<:OptimizationContainerKey, DataFrames.DataFrame},
    container_keys,
)
    existing_keys = keys(result_values)
    container_keys = container_keys === nothing ? existing_keys : container_keys
    _validate_keys(existing_keys, container_keys)
    return Dict(
        encode_key_as_string(k) => v for (k, v) in result_values if k in container_keys
    )
end

# TODO: This is not used. Can it be deleted?
#function _read_results(
#    result_values::Dict{<:OptimizationContainerKey, DataFrames.DataFrame},
#    container_keys,
#    initial_time::Dates.DateTime,
#)
#    realized_results = _read_realized_results(result_values, container_keys)
#    results = FieldResultsByTime()
#    for (key, df) in realized_results
#        results[encode_key_as_string(key)] = ResultsByTime(initial_time => df)
#    end
#    return results
#end

function read_realized_aux_variables(res::ProblemResults, aux_variable_keys)
    return _read_realized_results(
        res.aux_variable_values,
        [AuxVarKey(x...) for x in aux_variable_keys],
    )
end

function read_realized_aux_variables(res::ProblemResults)
    return _read_realized_results(res.aux_variable_values, nothing)
end

function read_realized_variables(res::ProblemResults, variable_keys)
    return _read_realized_results(
        res.variable_values,
        [VariableKey(x...) for x in variable_keys],
    )
end

function read_realized_variables(res::ProblemResults)
    return _read_realized_results(res.variable_values, nothing)
end

function read_realized_parameters(res::ProblemResults, parameter_keys)
    return _read_realized_results(
        res.parameter_values,
        [ParameterKey(x...) for x in parameter_keys],
    )
end

function read_realized_parameters(res::ProblemResults)
    return _read_realized_results(res.parameter_values, nothing)
end

function read_realized_duals(res::ProblemResults, dual_keys)
    return _read_realized_results(res.dual_values, [ConstraintKey(x...) for x in dual_keys])
end

function read_realized_duals(res::ProblemResults)
    return _read_realized_results(res.dual_values, nothing)
end
