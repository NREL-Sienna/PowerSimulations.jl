struct TimeSeriesCacheKey
    component_uuid::Base.UUID
    time_series_type::Type{<:IS.TimeSeriesData}
    name::String
end

mutable struct SimulationInfo
    number::Int
    name::Symbol
    caches::Set{CacheKey}
    end_of_interval_step::Int
    # JD: Will probably go away
    chronolgy_dict::Dict{Int, <:FeedForwardChronology}
    requires_rebuild::Bool
    sequence_uuid::Base.UUID
end

mutable struct ModelInternal
    container::OptimizationContainer
    status::BuildStatus
    run_status::RunStatus
    base_conversion::Bool
    executions::Int
    execution_count::Int
    output_dir::Union{Nothing, String}
    simulation_info::Union{Nothing, SimulationInfo}
    time_series_cache::Dict{TimeSeriesCacheKey, <:IS.TimeSeriesCache}
    ext::Dict{String, Any}
    console_level::Base.CoreLogging.LogLevel
    file_level::Base.CoreLogging.LogLevel
    # TODO: Marge all structs (ModelInternal, ModelStoreParams and SimulationInternal) to a single Internal Struct
    store_parameters::Union{Nothing, ModelStoreParams}
end

function ModelInternal(container::OptimizationContainer; ext = Dict{String, Any}())
    return ModelInternal(
        container,
        BuildStatus.EMPTY,
        RunStatus.READY,
        true,
        0,
        0,
        nothing,
        nothing,
        Dict{TimeSeriesCacheKey, IS.TimeSeriesCache}(),
        ext,
        Logging.Warn,
        Logging.Info,
        nothing,
    )
end

function configure_logging(internal::ModelInternal, file_mode)
    return IS.configure_logging(
        console = true,
        console_stream = stderr,
        console_level = internal.console_level,
        file = true,
        filename = joinpath(internal.output_dir, PROBLEM_LOG_FILENAME),
        file_level = internal.file_level,
        file_mode = file_mode,
        tracker = nothing,
        set_global = false,
    )
end
