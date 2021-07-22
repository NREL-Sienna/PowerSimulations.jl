# JDNOTE: This might be merged with the structs in simulation_store
mutable struct SimulationInfo
    number::Int
    name::Symbol
    executions::Int
    execution_count::Int
    caches::Set{CacheKey}
    end_of_interval_step::Int
    chronolgy_dict::Dict{Int, <:FeedForwardChronology}
    requires_rebuild::Bool
    sequence_uuid::Base.UUID
end

struct TimeSeriesCacheKey
    component_uuid::Base.UUID
    time_series_type::Type{<:IS.TimeSeriesData}
    name::String
end

mutable struct ProblemInternal
    container::OptimizationContainer
    status::BuildStatus
    run_status::RunStatus
    base_conversion::Bool
    output_dir::Union{Nothing, String}
    simulation_info::Union{Nothing, SimulationInfo}
    time_series_cache::Dict{TimeSeriesCacheKey, <:IS.TimeSeriesCache}
    ext::Dict{String, Any}
    console_level::Base.CoreLogging.LogLevel
    file_level::Base.CoreLogging.LogLevel
end

function ProblemInternal(container::OptimizationContainer; ext = Dict{String, Any}())
    return ProblemInternal(
        container,
        BuildStatus.EMPTY,
        RunStatus.READY,
        true,
        nothing,
        nothing,
        Dict{TimeSeriesCacheKey, IS.TimeSeriesCache}(),
        ext,
        Logging.Warn,
        Logging.Info,
    )
end

function configure_logging(internal::ProblemInternal, file_mode)
    return IS.configure_logging(
        console = true,
        console_stream = stderr,
        console_level = internal.console_level,
        file = true,
        filename = joinpath(internal.output_dir, PROBLEM_BUILD_LOG_FILENAME),
        file_level = internal.file_level,
        file_mode = file_mode,
        tracker = nothing,
        set_global = false,
    )
end
