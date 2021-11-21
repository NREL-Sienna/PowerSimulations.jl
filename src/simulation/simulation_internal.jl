mutable struct SimulationInternal
    sim_files_dir::String
    store_dir::String
    logs_dir::String
    models_dir::String
    recorder_dir::String
    results_dir::String
    run_count::Dict{Int, Dict{Int, Int}}
    date_ref::Dict{Int, Dates.DateTime}
    status::RunStatus
    build_status::BuildStatus
    simulation_state::SimulationState
    store::Union{Nothing, SimulationStore}
    recorders::Vector{Symbol}
    console_level::Base.CoreLogging.LogLevel
    file_level::Base.CoreLogging.LogLevel
    cache_size_mib::Int
    min_cache_flush_size_mib::Int
end

function SimulationInternal(
    steps::Int,
    models::SimulationModels,
    sim_dir::String,
    name::String,
    output_dir::Union{Nothing, String},
    recorders,
    console_level::Logging.LogLevel,
    file_level::Logging.LogLevel,
    cache_size_mib = 1024,
    min_cache_flush_size_mib = MIN_CACHE_FLUSH_SIZE_MiB,
)
    count_dict = Dict{Int, Dict{Int, Int}}()

    for s in 1:steps
        count_dict[s] = Dict{Int, Int}()
        model_count = length(get_decision_models(models))
        for st in 1:model_count
            count_dict[s][st] = 0
        end
        if get_emulation_model(models) !== nothing
            count_dict[s][model_count + 1] = 0
        end
    end

    base_dir = joinpath(sim_dir, name)
    mkpath(base_dir)

    output_dir = _get_output_dir_name(base_dir, output_dir)
    simulation_dir = joinpath(base_dir, output_dir)
    if isdir(simulation_dir)
        error("$simulation_dir already exists. Delete it or pass a different output_dir.")
    end

    sim_files_dir = joinpath(simulation_dir, "simulation_files")
    store_dir = joinpath(simulation_dir, "data_store")
    logs_dir = joinpath(simulation_dir, "logs")
    models_dir = joinpath(simulation_dir, "problems")
    recorder_dir = joinpath(simulation_dir, "recorder")
    results_dir = joinpath(simulation_dir, RESULTS_DIR)

    for path in (
        simulation_dir,
        sim_files_dir,
        logs_dir,
        models_dir,
        recorder_dir,
        results_dir,
        store_dir,
    )
        mkpath(path)
    end

    unique_recorders = Set(REQUIRED_RECORDERS)
    foreach(x -> push!(unique_recorders, x), recorders)

    return SimulationInternal(
        sim_files_dir,
        store_dir,
        logs_dir,
        models_dir,
        recorder_dir,
        results_dir,
        count_dict,
        Dict{Int, Dates.DateTime}(),
        RunStatus.NOT_READY,
        BuildStatus.EMPTY,
        SimulationState(),
        nothing,
        collect(unique_recorders),
        console_level,
        file_level,
        cache_size_mib,
        min_cache_flush_size_mib,
    )
end

function _get_output_dir_name(path, output_dir)
    if output_dir !== nothing
        # The user wants a custom name.
        return output_dir
    end

    # Return the next highest integer.
    output_dir = 1
    for name in readdir(path)
        if occursin(r"^\d+$", name)
            num = parse(Int, name)
            if num >= output_dir
                output_dir = num + 1
            end
        end
    end

    return string(output_dir)
end

function configure_logging(internal::SimulationInternal, file_mode)
    return IS.configure_logging(
        console = true,
        console_stream = stderr,
        console_level = internal.console_level,
        file = true,
        filename = joinpath(internal.logs_dir, SIMULATION_LOG_FILENAME),
        file_level = internal.file_level,
        file_mode = file_mode,
        tracker = nothing,
        set_global = false,
    )
end

function register_recorders!(internal::SimulationInternal, file_mode)
    for name in internal.recorders
        IS.register_recorder!(name; mode = file_mode, directory = internal.recorder_dir)
    end
end

function unregister_recorders!(internal::SimulationInternal)
    for name in internal.recorders
        IS.unregister_recorder!(name)
    end
end
