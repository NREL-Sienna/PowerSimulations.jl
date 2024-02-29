struct TimeSeriesCacheKey
    component_uuid::Base.UUID
    time_series_type::Type{<:IS.TimeSeriesData}
    name::String
    multiplier_id::Int
end

# TODO: Marge all structs (ModelInternal, ModelStoreParams and SimulationInfo) to a single Internal Struct

mutable struct SimulationInfo
    number::Int
    sequence_uuid::Base.UUID
end

mutable struct ModelInternal{T <: IS.AbstractModelContainer}
    container::T
    ic_model_container::Union{Nothing, T}
    status::BuildStatus
    run_status::RunStatus
    base_conversion::Bool
    executions::Int
    execution_count::Int
    output_dir::Union{Nothing, String}
    simulation_info::Union{Nothing, SimulationInfo}
    time_series_cache::Dict{TimeSeriesCacheKey, <:IS.TimeSeriesCache}
    recorders::Vector{Symbol}
    console_level::Base.CoreLogging.LogLevel
    file_level::Base.CoreLogging.LogLevel
    store_parameters::Union{Nothing, ModelStoreParams}
    ext::Dict{String, Any}
end

function ModelInternal(
    container::T;
    ext = Dict{String, Any}(),
    recorders = [],
) where {T <: IS.AbstractModelContainer}
    return ModelInternal{T}(
        container,
        nothing,
        BuildStatus.EMPTY,
        RunStatus.READY,
        true,
        1, #Default executions is 1. The model will be run at least once
        0,
        nothing,
        nothing,
        Dict{TimeSeriesCacheKey, IS.TimeSeriesCache}(),
        recorders,
        Logging.Warn,
        Logging.Info,
        nothing,
        ext,
    )
end

function add_recorder!(internal::ModelInternal, recorder::Symbol)
    push!(internal.recorders, recorder)
    return
end

get_recorders(internal::ModelInternal) = internal.recorders

function configure_logging(internal::ModelInternal, file_mode)
    return IS.configure_logging(;
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
