const FILE_STRUCT =
    ["data_store", "logs", "models_json", "recorder", "results", "simulation_files"]

struct SimulationResults <: PSIResults
    stage::String
    base_power::Float64
    execution_path::AbstractString
    results_output_folder::String
    system::Union{Nothing, PSY.System}
    available_variables::Array{Symbol}
    variable_values::Dict{Symbol, DataFrames.DataFrame}
    available_duals::Array{Symbol}
    dual_values::Dict{Symbol, Any}
    available_parameters::Array{Symbol}
    parameter_values::Dict{Symbol, DataFrames.DataFrame}
end

function check_folder_integrity(folder::String)
    folder_files = readdir(folder)
    alien_files = [f for f in folder_files if f ∉ FILE_STRUCT]
    if isempty(alien_files)
        return true
    end
    if "data_store" ∉ folder_files
        error("The file path doesn't contain any data_store folder")
    end
    return false
end

function results_pre_process(store::HdfSimulationStore, stage_name::Symbol)
    stage_results_params = Dict()
    store_params = get_params(store)
    #sim_initial_time = get_initial_time(store_params)
    stages_params = get_stages(store_params)
    if stage_name ∉ keys(stages_params)
        error("Stage with name $(stage_name) not in the simulation")
    end
    stage_params = stages_params[stage_name]
    stage_results_params["base_power"] = get_base_power(stage_params)
    stage_results_params["system_uuid"] = get_system_uuid(stage_params)
    stage_dataset = get_dataset(store, stage_name)
    stage_results_params["available_variables"] = keys(get_variables(stage_dataset))
    stage_results_params["available_params"] = keys(get_parameters(stage_dataset))
    stage_results_params["available_duals"] = keys(get_duals(stage_dataset))
    return stage_results_params
end

function results_pre_process(simulation_store_path::AbstractString, stage_name::String)
    stage_name = Symbol(stage_name)
    stage_params = nothing
    h5_store_open(simulation_store_path, "r") do store
        stage_params = results_pre_process(store, stage_name)
    end
    return stage_params
end

function SimulationResults(
    path::String,
    stage_name::String;
    execution::Union{Nothing, Int} = nothing,
    load_system::Bool = true,
    results_output_path = nothing,
)
    if execution === nothing
        execution = maximum([parse(Int, f) for f in readdir(path) if occursin(r"^\d+$", f)])
    end
    execution_path = joinpath(path, string(execution))
    if !isdir(execution_path)
        error("Execution $execution not in the simulations results")
    end
    if !check_folder_integrity(execution_path)
        @warn("The results folder $(execution_path) is not consistent with the default folder structure. This can lead to unwanted to errors or unwanted results")
    end
    simulation_store_path = joinpath(execution_path, "data_store")
    check_file_integrity(simulation_store_path)
    stage_params = results_pre_process(simulation_store_path, stage_name)

    if load_system
        sys = PSY.System(joinpath(
            execution_path,
            "simulation_files",
            "system-$(stage_params["system_uuid"]).json",
        ))
    else
        sys = nothing
    end

    if results_output_path === nothing
        results_output_path = joinpath(execution_path, "results")
    end

    return SimulationResults(
        stage_name,
        stage_params["base_power"],
        execution_path,
        results_output_path,
        sys,
        collect(stage_params["available_variables"]),
        Dict{Symbol, DataFrames.DataFrame}(),
        collect(stage_params["available_duals"]),
        Dict{Symbol, Any}(),
        collect(stage_params["available_duals"]),
        Dict{Symbol, DataFrames.DataFrame}(),
    )
end

function SimulationResults(sim::Simulation, stage_name::String)
    simulation_store_path = get_store_dir(sim)
    check_file_integrity(simulation_store_path)
    stage_params = results_pre_process(simulation_store_path, stage_name)
    sys = get_system(get_stage(sim, stage_name))
    return SimulationResults(
        stage_name,
        PSY.get_base_power(sys),
        get_simulation_dir(sim),
        get_results_dir(sim),
        sys,
        collect(stage_params["available_variables"]),
        Dict{Symbol, DataFrames.DataFrame}(),
        collect(stage_params["available_duals"]),
        Dict{Symbol, Any}(),
        collect(stage_params["available_duals"]),
        Dict{Symbol, DataFrames.DataFrame}(),
    )
end

get_model_base_power(result::SimulationResults) = result.base_power
IS.get_variables(result::SimulationResults) = result.variable_values
#IS.get_total_cost(result::SimulationResults) = result.total_cost
#IS.get_optimizer_log(results::SimulationResults) = results.optimizer_log
#IS.get_timestamp(result::SimulationResults) = result.time_stamp
get_duals(result::SimulationResults) = result.dual_values
IS.get_parameters(result::SimulationResults) = result.parameter_values
