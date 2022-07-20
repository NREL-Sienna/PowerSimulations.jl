function check_folder_integrity(folder::String)
    folder_files = readdir(folder)
    alien_files = setdiff(folder_files, KNOWN_SIMULATION_PATHS)
    if isempty(alien_files)
        return true
    else
        @warn "Unrecognized simulation files: $(sort(alien_files))"
    end
    if "data_store" ∉ folder_files
        error("The file path doesn't contain any data_store folder")
    end
    return false
end

function _fill_result_value_container(fields)
    return FieldResultsByTime(x => ResultsByTime() for x in fields)
end

struct SimulationResults
    path::String
    params::SimulationStoreParams
    decision_problem_results::Dict{
        String,
        SimulationProblemResults{DecisionModelSimulationResults},
    }
    emulation_problem_results::SimulationProblemResults{EmulationModelSimulationResults}
    store::Union{Nothing, SimulationStore}
end

"""
Construct SimulationResults from a simulation output directory.

# Arguments

  - `path::AbstractString`: Simulation output directory
  - `execution::AbstractString`: Execution number. Default is the most recent.
  - `ignore_status::Bool`: If true, return results even if the simulation failed.
"""
function SimulationResults(path::AbstractString, execution=nothing; ignore_status=false)
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
    _check_status(status, ignore_status)

    if !check_folder_integrity(execution_path)
        @warn "The results folder $(execution_path) is not consistent with the default folder structure. " *
              "This can lead to errors or unwanted results."
    end

    simulation_store_path = joinpath(execution_path, "data_store")
    check_file_integrity(simulation_store_path)

    return open_store(HdfSimulationStore, simulation_store_path, "r") do store
        decision_problem_results =
            Dict{String, SimulationProblemResults{DecisionModelSimulationResults}}()
        sim_params = get_params(store)
        container_key_lookup = get_container_key_lookup(store)
        for (name, problem_params) in sim_params.decision_models_params
            name = string(name)
            problem_result = SimulationProblemResults(
                DecisionModel,
                store,
                name,
                problem_params,
                sim_params,
                execution_path,
                container_key_lookup,
            )
            decision_problem_results[name] = problem_result
        end

        emulation_result = SimulationProblemResults(
            EmulationModel,
            store,
            string(first(keys(sim_params.emulation_model_params))),
            first(values(sim_params.emulation_model_params)),
            sim_params,
            execution_path,
            container_key_lookup,
        )

        return SimulationResults(
            execution_path,
            sim_params,
            decision_problem_results,
            emulation_result,
            nothing,
        )
    end
end

"""
Construct SimulationResults from a simulation.
"""
function SimulationResults(sim::Simulation; ignore_status=false, kwargs...)
    _check_status(get_simulation_status(sim), ignore_status)
    store = get_simulation_store(sim)
    execution_path = get_simulation_dir(sim)
    decision_problem_results =
        Dict{String, SimulationProblemResults{DecisionModelSimulationResults}}()
    sim_params = get_params(store)
    models = get_models(sim)
    container_key_lookup = get_container_key_lookup(store)
    for (name, problem_params) in sim_params.decision_models_params
        model = get_simulation_model(models, name)
        name = string(name)
        problem_result = SimulationProblemResults(
            DecisionModel,
            store,
            name,
            problem_params,
            sim_params,
            execution_path,
            container_key_lookup,
            system=get_system(model),
        )
        decision_problem_results[name] = problem_result
    end

    emulation_model = get_emulation_model(models)
    emulation_results = SimulationProblemResults(
        EmulationModel,
        store,
        string(first(keys(sim_params.emulation_model_params))),
        first(values(sim_params.emulation_model_params)),
        sim_params,
        execution_path,
        container_key_lookup,
        system=isnothing(emulation_model) ? nothing : get_system(emulation_model),
    )

    return SimulationResults(
        execution_path,
        sim_params,
        decision_problem_results,
        emulation_results,
        store,
    )
end

function Base.empty!(res::SimulationResults)
    foreach(empty!, values(res.decision_problem_results))
    empty!(res.emulation_problem_results)
end

Base.isempty(res::SimulationResults) = all(isempty, values(res.decision_problem_results))
Base.length(res::SimulationResults) =
    mapreduce(length, +, values(res.decision_problem_results))
get_exports_folder(x::SimulationResults) = joinpath(x.path, "exports")

function get_decision_problem_results(results::SimulationResults, problem)
    if !haskey(results.decision_problem_results, problem)
        throw(IS.InvalidValue("$problem is not stored"))
    end

    return results.decision_problem_results[problem]
end

function get_emulation_problem_results(results::SimulationResults)
    return results.emulation_problem_results
end

"""
Return the problem names in the simulation.
"""
list_decision_problems(results::SimulationResults) =
    collect(keys(results.decision_problem_results))

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
  "decision_models": [
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
    if results.store isa InMemorySimulationStore
        export_results(results, exports, results.store)
    else
        simulation_store_path = joinpath(results.path, "data_store")
        open_store(HdfSimulationStore, simulation_store_path, "r") do store
            export_results(results, exports, store)
        end
    end
    return
end

function export_results(results::SimulationResults, exports, store::SimulationStore)
    if !(exports isa SimulationResultsExport)
        exports = SimulationResultsExport(exports, results.params)
    end

    file_type = get_export_file_type(exports)

    for problem_results in values(results.decision_problem_results)
        problem_exports = get_problem_exports(exports, problem_results.problem)
        path =
            exports.path === nothing ? problem_results.results_output_folder : exports.path
        for timestamp in get_timestamps(problem_results)
            !should_export(exports, timestamp) && continue

            export_path = mkpath(joinpath(path, problem_results.problem, "variables"))
            for name in list_variable_names(problem_results)
                if should_export_variable(problem_exports, name)
                    dfs = read_variable(
                        problem_results,
                        name;
                        initial_time=timestamp,
                        count=1,
                        store=store,
                    )
                    export_result(file_type, export_path, name, timestamp, dfs[timestamp])
                end
            end

            export_path = mkpath(joinpath(path, problem_results.problem, "aux_variables"))
            for name in list_aux_variable_names(problem_results)
                if should_export_aux_variable(problem_exports, name)
                    dfs = read_aux_variable(
                        problem_results,
                        name;
                        initial_time=timestamp,
                        count=1,
                        store=store,
                    )
                    export_result(file_type, export_path, name, timestamp, dfs[timestamp])
                end
            end

            export_path = mkpath(joinpath(path, problem_results.problem, "parameters"))
            for name in list_parameter_names(problem_results)
                if should_export_parameter(problem_exports, name)
                    dfs = read_parameter(
                        problem_results,
                        name;
                        initial_time=timestamp,
                        count=1,
                        store=store,
                    )
                    export_result(file_type, export_path, name, timestamp, dfs[timestamp])
                end
            end

            export_path = mkpath(joinpath(path, problem_results.problem, "duals"))
            for name in list_dual_names(problem_results)
                if should_export_dual(problem_exports, name)
                    dfs = read_dual(
                        problem_results,
                        name;
                        initial_time=timestamp,
                        count=1,
                        store=store,
                    )
                    export_result(file_type, export_path, name, timestamp, dfs[timestamp])
                end
            end
        end

        export_path = mkpath(joinpath(path, problem_results.problem, "expression"))
        for name in list_expression_names(problem_results)
            if should_export_expression(problem_exports, name)
                dfs = read_expression(
                    problem_results,
                    name;
                    initial_time=timestamp,
                    count=1,
                    store=store,
                )
                export_result(file_type, export_path, name, timestamp, dfs[timestamp])
            end
        end

        if problem_exports.optimizer_stats
            export_path = joinpath(path, problem_results.problem, "optimizer_stats.csv")
            df = read_optimizer_stats(problem_results, store=store)
            export_result(file_type, export_path, df)
        end
    end
    return
end

function export_result(
    ::Type{CSV.File},
    path,
    key::OptimizationContainerKey,
    timestamp::Dates.DateTime,
    df::DataFrames.DataFrame,
)
    name = encode_key_as_string(key)
    export_result(CSV.File, path, name, timestamp, df)
    return
end

function export_result(
    ::Type{CSV.File},
    path,
    name::AbstractString,
    timestamp::Dates.DateTime,
    df::DataFrames.DataFrame,
)
    filename = joinpath(path, name * "_" * convert_for_path(timestamp) * ".csv")
    export_result(CSV.File, filename, df)
    return
end

function export_result(
    ::Type{CSV.File},
    path,
    key::OptimizationContainerKey,
    df::DataFrames.DataFrame,
)
    name = encode_key_as_string(key)
    export_result(CSV.File, path, name, df)
    return
end

function export_result(
    ::Type{CSV.File},
    path,
    name::AbstractString,
    df::DataFrames.DataFrame,
)
    filename = joinpath(path, name * ".csv")
    export_result(CSV.File, filename, df)
    return
end

function export_result(::Type{CSV.File}, filename, df::DataFrames.DataFrame)
    open(filename, "w") do io
        CSV.write(io, df)
    end

    @debug "Exported $filename"
    return
end

function _check_status(status::RunStatus, ignore_status)
    status == RunStatus.SUCCESSFUL && return

    if ignore_status
        @warn "Simulation was not successful: $status. Results may not be valid."
    else
        error(
            "Simulation was not successful: status = $status. Set ignore_status = true to override.",
        )
    end
    return
end
