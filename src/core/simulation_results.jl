function check_folder_integrity(folder::String)
    folder_files = readdir(folder)
    alien_files = filter(!∈(KNOWN_SIMULATION_PATHS), folder_files)
    if isempty(alien_files)
        return true
    end
    if "data_store" ∉ folder_files
        error("The file path doesn't contain any data_store folder")
    end
    return false
end

function _fill_result_value_container(fields)
    return FieldResultsByTime(x => ResultsByTime() for x in fields)
end

struct SimulationResults <: PSIResults
    path::String
    params::SimulationStoreParams
    problem_results::Dict{String, ProblemResults}
end

"""
Construct SimulationResults from a simulation output directory.

# Arguments
- `path::AbstractString`: Simulation output directory
- `execution::AbstractString`: Execution number. Default is the most recent.
- `ignore_status::Bool`: If true, return results even if the simulation failed.
"""
function SimulationResults(path::AbstractString, execution = nothing; ignore_status = false)
    # path will be either the execution_path or the directory containing all executions.
    contents = readdir(path)
    if "data_store" in contents
        execution_path = path
    else
        if execution === nothing
            executions = [parse(Int, f) for f in contents if occursin(r"^\d+$", f)]
            if isempty(executions)
                error("There are no simulation results in the path")
            end
            execution = maximum(executions)
        end
        execution_path = joinpath(path, string(execution))
        if !isdir(execution_path)
            error("Execution $execution not in the simulations results")
        end
    end

    status = deserialize_status(joinpath(execution_path, RESULTS_DIR))
    if status != RunStatus.SUCCESSFUL
        if ignore_status
            @warn "Simulation was not successful: $status. Results may not be valid."
        else
            error(
                "Simulation was not successful: status = $status. Set ignore_status = true to override.",
            )
        end
    end

    if !check_folder_integrity(execution_path)
        @warn "The results folder $(execution_path) is not consistent with the default folder structure. " *
              "This can lead to errors or unwanted results."
    end

    simulation_store_path = joinpath(execution_path, "data_store")
    check_file_integrity(simulation_store_path)

    return h5_store_open(simulation_store_path, "r") do store
        problem_results = Dict{String, ProblemResults}()
        sim_params = get_params(store)
        for (name, problem_params) in sim_params.problems
            name = string(name)
            problem_result =
                ProblemResults(store, name, problem_params, sim_params, execution_path;)
            problem_results[name] = problem_result
        end

        return SimulationResults(execution_path, sim_params, problem_results)
    end
end

"""
Construct SimulationResults from a simulation.
"""
SimulationResults(sim::Simulation; kwargs...) =
    SimulationResults(get_simulation_dir(sim); kwargs...)

Base.empty!(res::SimulationResults) = foreach(empty!, values(res.problem_results))
Base.isempty(res::SimulationResults) = all(isempty, values(res.problem_results))
Base.length(res::SimulationResults) = mapreduce(length, +, values(res.problem_results))
get_exports_folder(x::SimulationResults) = joinpath(x.path, "exports")

function get_problem_results(results::SimulationResults, problem)
    if !haskey(results.problem_results, problem)
        throw(IS.InvalidValue("$problem is not stored"))
    end

    return results.problem_results[problem]
end

"""
Return the problem names in the simulation.
"""
list_problems(results::SimulationResults) = collect(keys(results.problem_results))

"""
Export results to files in the results directory.

# Arguments
- `results::SimulationResults`: simulation results
- `exports`: SimulationResultsExport or anything that can be passed to its constructor.
  (such as Dict or path to JSON file)

An example JSON file demonstrating possible options is below. Note that `start_time`,
`end_time`, `path`, and `format` are optional.

```
{
  "problems": [
    {
      "name": "ED",
      "variables": [
        "P__ThermalStandard",
        "E__HydroEnergyReservoir"
      ],
      "parameters": [
        "all"
      ]
    },
    {
      "name": "UC",
      "variables": [
        "On__ThermalStandard"
      ],
      "parameters": [
        "all"
      ],
      "duals": [
        "all"
      ]
    }
  ],
  "start_time": "2020-01-01T04:00:00",
  "end_time": null,
  "path": null,
  "format": "csv"
}
```
"""
function export_results(results::SimulationResults, exports)
    simulation_store_path = joinpath(results.path, "data_store")
    h5_store_open(simulation_store_path, "r") do store
        export_results(results, exports, store)
    end
end

function export_results(results::SimulationResults, exports, store::SimulationStore)
    if !(exports isa SimulationResultsExport)
        exports = SimulationResultsExport(exports, results.params)
    end

    file_type = get_export_file_type(exports)

    for problem_results in values(results.problem_results)
        problem_exports = get_problem_exports(exports, problem_results.problem)
        path =
            exports.path === nothing ? problem_results.results_output_folder : exports.path
        for timestamp in get_existing_timestamps(problem_results)
            !should_export(exports, timestamp) && continue

            export_path = mkpath(joinpath(path, problem_results.problem, "variables"))
            for name in get_existing_variables(problem_results)
                if should_export_variable(problem_exports, name)
                    dfs = read_variable(
                        problem_results,
                        name;
                        initial_time = timestamp,
                        count = 1,
                        store = store,
                    )
                    export_result(file_type, export_path, name, timestamp, dfs[timestamp])
                end
            end

            export_path = mkpath(joinpath(path, problem_results.problem, "parameters"))
            for name in get_existing_parameters(problem_results)
                if should_export_parameter(problem_exports, name)
                    dfs = read_parameter(
                        problem_results,
                        name;
                        initial_time = timestamp,
                        count = 1,
                        store = store,
                    )
                    export_result(file_type, export_path, name, timestamp, dfs[timestamp])
                end
            end

            export_path = mkpath(joinpath(path, problem_results.problem, "duals"))
            for name in get_existing_duals(problem_results)
                if should_export_dual(problem_exports, name)
                    dfs = read_dual(
                        problem_results,
                        name;
                        initial_time = timestamp,
                        count = 1,
                        store = store,
                    )
                    export_result(file_type, export_path, name, timestamp, dfs[timestamp])
                end
            end
        end

        if problem_exports.optimizer_stats
            export_path = joinpath(path, problem_results.problem, "optimizer_stats.csv")
            df = read_optimizer_stats(problem_results, store = store)
            export_result(file_type, export_path, df)
        end
    end
end

function export_result(
    ::Type{CSV.File},
    path,
    name,
    timestamp::Dates.DateTime,
    df::DataFrames.DataFrame,
)
    filename = joinpath(path, string(name) * "_" * convert_for_path(timestamp) * ".csv")
    export_result(CSV.File, filename, df)
end

function export_result(::Type{CSV.File}, path, name, df::DataFrames.DataFrame)
    filename = joinpath(path, string(name) * ".csv")
    export_result(CSV.File, filename, df)
end

function export_result(
    ::Type{CSV.File},
    path,
    timestamp::Dates.DateTime,
    df::DataFrames.DataFrame,
)
    filename = joinpath(path, convert_for_path(timestamp) * ".csv")
    export_result(CSV.File, filename, df)
end

function export_result(::Type{CSV.File}, filename, df::DataFrames.DataFrame)
    open(filename, "w") do io
        CSV.write(io, df)
    end

    @debug "Exported $filename"
end
