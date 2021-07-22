struct ProblemResults <: PSIResults
    base_power::Float64
    timestamps::StepRange{Dates.DateTime, Dates.Millisecond}
    system::Union{Nothing, PSY.System}
    variable_values::Dict{VariableKey, DataFrames.DataFrame}
    dual_values::Dict{ConstraintKey, DataFrames.DataFrame}
    parameter_values::Dict{ParameterKey, DataFrames.DataFrame}
    optimizer_stats::OptimizerStats
    container::OptimizationContainer
    output_dir::String
end

list_variable_names(res::ProblemResults) = encode_keys_as_strings(keys(res.variable_values))
list_parameter_names(res::ProblemResults) =
    encode_keys_as_strings(keys(res.parameter_values))
list_dual_names(res::ProblemResults) = encode_keys_as_strings(keys(res.dual_values))
get_timestamps(res::ProblemResults) = res.timestamps
get_model_base_power(res::ProblemResults) = res.base_power
get_objective_value(res::ProblemResults) = res.optimizer_stats.objective_value
get_dual_values(res::ProblemResults) = res.dual_values
get_variable_values(res::ProblemResults) = res.variable_values
IS.get_total_cost(res::ProblemResults) = get_objective_value(res)
IS.get_optimizer_stats(res::ProblemResults) = res.optimizer_stats
get_parameter_values(res::ProblemResults) = res.parameter_values
IS.get_resolution(res::ProblemResults) = res.timestamps.step
get_system(res::ProblemResults) = res.system

function ProblemResults(model::DecisionModel)
    status = get_run_status(model)
    status != RunStatus.SUCCESSFUL && error("problem was not solved successfully: $status")

    container = get_optimization_container(model)
    variables = read_variables(container)
    duals = read_duals(container)
    parameters = read_parameters(container)
    timestamps = get_timestamps(model)
    optimizer_stats = OptimizerStats(model)

    for df in Iterators.flatten(((values(variables), values(duals), values(parameters))))
        DataFrames.insertcols!(df, 1, :DateTime => timestamps)
    end

    return ProblemResults(
        get_problem_base_power(model),
        timestamps,
        model.sys,
        variables,
        duals,
        parameters,
        optimizer_stats,
        container,
        mkpath(joinpath(get_output_dir(model), "results")),
    )
end

"""
Exports all results from the operations problem.
"""
function export_results(results::ProblemResults; kwargs...)
    exports = ProblemResultsExport(
        "DecisionProblem",
        store_all_duals = true,
        store_all_parameters = true,
        store_all_variables = true,
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
        df = to_dataframe(results.optimizer_stats)
        export_result(file_type, joinpath(results.output_dir, "optimizer_stats.csv"), df)
    end

    @info "Exported ProblemResults to $(results.output_dir)"
end

function read_variable(res::ProblemResults, args...)
    key = VariableKey(args...)
    !haskey(res.variable_values, key) && error("$args is not stored")
    return res.variable_values[key]
end

function read_parameter(res::ProblemResults, args...)
    key = ParameterKey(args...)
    !haskey(res.parameter_values, key) && error("$args is not stored")
    return res.parameter_values[key]
end

function read_dual(res::ProblemResults, args...)
    key = ConstraintKey(args...)
    !haskey(res.dual_values, key) && error("$args is not stored")
    return res.dual_values[key]
end

function read_optimizer_stats(res::ProblemResults)
    data = get_optimizer_stats(res)
    stats = [to_namedtuple(data)]
    return DataFrames.DataFrame(stats)
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

_get_keys(::Type{ConstraintKey}, res, ::Nothing) = collect(keys(res.dual_values))
_get_keys(::Type{ParameterKey}, res, ::Nothing) = collect(keys(res.parameter_values))
_get_keys(::Type{VariableKey}, res, ::Nothing) = collect(keys(res.variable_values))

#=
function _read_realized_results(
    result_values::Dict{<:OptimizationContainerKey, DataFrames.DataFrame},
    container_keys::Union{Nothing, Vector{<:OptimizationContainerKey}},
)
    existing_keys = collect(keys(result_values))
    container_keys = isnothing(container_keys) ? existing_keys : container_keys
    _validate_keys(existing_keys, container_keys)
    return Dict(encode_key_string(k) => v for (k, v) in result_values if k in container_keys)
end

function _read_results(
    result_values::Dict{<:OptimizationContainerKey, DataFrames.DataFrame},
    container_keys::Union{Nothing, Vector{<:OptimizationContainerKey}},
    initial_time::Dates.DateTime,
)
    realized_results = _read_realized_results(result_values, container_keys)
    results = FieldResultsByTime()
    for (key, df) in realized_results
        results[encode_key_as_string(key)] = ResultsByTime(initial_time => df)
    end
    return results
end

function read_realized_variables(
    res::ProblemResults;
    variable_keys::Union{Vector{Tuple}, Nothing} = nothing,
)
    if variable_keys !== nothing
        variable_keys = [VariableKey(x...) for x in variable_keys]
    end
    return _read_realized_results(res.variable_values, variable_keys)
end

function read_realized_parameters(
    res::ProblemResults;
    parameter_keys::Union{Vector{Tuple}, Nothing} = nothing,
)
    if parameter_keys !== nothing
        parameter_keys = [ParameterKey(x...) for x in parameter_keys]
    end
    return _read_realized_results(res.parameter_values, parameter_keys)
end

function read_realized_duals(
    res::ProblemResults;
    dual_keys::Union{Vector{Tuple}, Nothing} = nothing,
)
    if dual_keys !== nothing
        dual_keys = [ConstraintKey(x...) for x in dual_keys]
    end
    return _read_realized_results(res.dual_values, dual_keys)
end

=#
