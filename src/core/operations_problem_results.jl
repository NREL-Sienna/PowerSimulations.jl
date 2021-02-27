struct OperationsProblemResults <: PSIResults
    base_power::Float64
    variable_values::Dict{Symbol, DataFrames.DataFrame}
    dual_values::Dict{Symbol, DataFrames.DataFrame}
    parameter_values::Dict{Symbol, DataFrames.DataFrame}
    optimizer_stats::OptimizerStats
    output_dir::String
end

get_existing_variables(res::OperationsProblemResults) = keys(get_variables(res))
get_existing_parameters(res::OperationsProblemResults) = keys(IS.get_parameters(res))
get_existing_duals(res::OperationsProblemResults) = keys(get_duals(res))
get_model_base_power(res::OperationsProblemResults) = res.base_power
get_objective_value(res::OperationsProblemResults) = res.optimizer_stats.objective_value
IS.get_variables(res::OperationsProblemResults) = res.variable_values
IS.get_total_cost(res::OperationsProblemResults) = res.total_cost
IS.get_optimizer_stats(res::OperationsProblemResults) = res.optimizer_stats
get_duals(res::OperationsProblemResults) = res.dual_values
IS.get_parameters(res::OperationsProblemResults) = res.parameter_values

function OperationsProblemResults(problem::OperationsProblem)
    status = get_run_status(problem)
    status != RunStatus.SUCCESSFUL && error("problem was not solved successfully: $status")

    container = get_optimization_container(problem)
    variables = read_variables(container)
    duals = read_duals(container)
    parameters = read_parameters(container)
    timestamps = get_timestamps(problem)
    optimizer_stats = OptimizerStats(problem)

    for df in Iterators.flatten(((values(variables), values(duals), values(parameters))))
        DataFrames.insertcols!(df, 1, :DateTime => timestamps)
    end

    return OperationsProblemResults(
        get_problem_base_power(problem),
        variables,
        duals,
        parameters,
        optimizer_stats,
        mkpath(joinpath(get_output_dir(problem), "results")),
        timestamps
    )
end

"""
Exports all results from the operations problem.
"""
function export_results(results::OperationsProblemResults; kwargs...)
    all_fields = Set(["all"])
    exports = ProblemResultsExport(
        "OperationsProblem",
        variables = all_fields,
        duals = all_fields,
        parameters = all_fields,
    )
    export_results(results, exports; kwargs...)
end

function export_results(
    results::OperationsProblemResults,
    exports::ProblemResultsExport;
    file_type = CSV.File,
)
    file_type != CSV.File && error("only CSV.File is currently supported")
    export_path = mkpath(joinpath(results.output_dir, "variables"))
    for (name, df) in results.variable_values
        if should_export_variable(exports, name)
            export_result(file_type, export_path, name, df)
        end
    end

    export_path = mkpath(joinpath(results.output_dir, "duals"))
    for (name, df) in results.dual_values
        if should_export_dual(exports, name)
            export_result(file_type, export_path, name, df)
        end
    end

    export_path = mkpath(joinpath(results.output_dir, "parameters"))
    for (name, df) in results.parameter_values
        if should_export_parameter(exports, name)
            export_result(file_type, export_path, name, df)
        end
    end

    if exports.optimizer_stats
        df = to_dataframe(results.optimizer_stats)
        export_result(file_type, joinpath(results.output_dir, "optimizer_stats.csv"), df)
    end

    @info "Exported OperationsProblemResults to $(results.output_dir)"
end

# TODO:
# - Handle PER-UNIT conversion of variables according to type
# - Enconde Variable/Parameter/Dual from other inputs to avoid passing Symbol

function get_variable_value(res::OperationsProblemResults, key::Symbol)
    var_result = get(res.variable_values, key, nothing)
    if var_result === nothing
        throw(IS.ConflictingInputsError("No variable with key $(key) has been found."))
    end
    return var_result
end

function _find_duals(variables::Array)
    duals = []
    for i in 1:length(variables)
        if occursin("dual", String.(variables[i]))
            duals = vcat(duals, variables[i])
        end
    end
    return duals
end

function _find_params(variables::Array)
    params = []
    for i in 1:length(variables)
        if occursin("parameter", String.(variables[i]))
            params = vcat(params, variables[i])
        end
    end
    return params
end

function write_to_CSV(res::OperationsProblemResults, save_path::String)
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

function write_optimizer_stats(res::OperationsProblemResults, directory::AbstractString)
    data = to_dict(res.optimizer_stats)
    JSON.write(joinpath(directory, "optimizer_stats.json"), JSON.json(data))
end

function read_variables(
    problem::OperationsProblem,
    names::Union{Vector{Symbol}, Nothing} = nothing,
)
    variables = get_variables(problem)
end
