"""
All events subtyped from this need to be recorded under :simulation_status.
"""
abstract type AbstractSimulationStatusEvent <: IS.AbstractRecorderEvent end

struct SimulationStepEvent <: AbstractSimulationStatusEvent
    common::IS.RecorderEventCommon
    simulation_time::Dates.DateTime
    step::Int
    status::String
end

function SimulationStepEvent(
    simulation_time::Dates.DateTime,
    step::Int,
    status::AbstractString,
)
    return SimulationStepEvent(
        IS.RecorderEventCommon("SimulationStepEvent"),
        simulation_time,
        step,
        status,
    )
end

struct SimulationStageEvent <: AbstractSimulationStatusEvent
    common::IS.RecorderEventCommon
    simulation_time::Dates.DateTime
    step::Int
    stage::Int
    status::String
end

function SimulationStageEvent(
    simulation_time::Dates.DateTime,
    step::Int,
    stage::Int,
    status::AbstractString,
)
    return SimulationStageEvent(
        IS.RecorderEventCommon("SimulationStageEvent"),
        simulation_time,
        step,
        stage,
        status,
    )
end

struct InitialConditionUpdateEvent <: IS.AbstractRecorderEvent
    common::IS.RecorderEventCommon
    simulation_time::Dates.DateTime
    initial_condition_type::String
    device_type::String
    device_name::String
    previous_value::Float64
    val::Float64
    stage_number::Int
end

function InitialConditionUpdateEvent(
    simulation_time,
    key::ICKey,
    ic::InitialCondition,
    val::Float64,
    previous_value::Float64,
    stage_number::Int,
)
    return InitialConditionUpdateEvent(
        IS.RecorderEventCommon("InitialConditionUpdateEvent"),
        simulation_time,
        string(key.ic_type),
        string(key.device_type),
        device_name(ic),
        val,
        previous_value,
        stage_number,
    )
end

struct ParameterUpdateEvent <: IS.AbstractRecorderEvent
    common::IS.RecorderEventCommon
    category::String
    simulation_time::Dates.DateTime
    parameter_type::String
    device_name::String
    previous_value::Float64
    val::Float64
    stage_number::Int
    source::Int
end

function ParameterUpdateEvent(
    category::String,
    simulation_time::Dates.DateTime,
    update_ref::UpdateRef{JuMP.VariableRef},
    device_name::String,
    val::Float64,
    previous_value::Float64,
    destination_stage::Stage,
    source_stage::Stage,
)
    return ParameterUpdateEvent(
        IS.RecorderEventCommon("ParameterUpdateEvent"),
        category,
        simulation_time,
        string(update_ref.access_ref),
        device_name,
        previous_value,
        val,
        get_number(destination_stage),
        get_number(source_stage),
    )
end

function get_simulation_step_range(filename::AbstractString, step::Int)
    events = IS.list_recorder_events(SimulationStepEvent, filename, x -> x.step == step)
    if length(events) != 2
        throw(ArgumentError("$filename does not have two SimulationStepEvents for step = $step"))
    end

    if events[1].status != "start" || events[2].status != "done"
        throw(ArgumentError("$filename does not contain start and done events for step = $step"))
    end

    return (start = events[1].simulation_time, done = events[2].simulation_time)
end

function get_simulation_stage_range(filename::AbstractString, step::Int, stage::Int)
    events = IS.list_recorder_events(
        SimulationStageEvent,
        filename,
        x -> x.step == step && x.stage == stage,
    )
    if length(events) != 2
        throw(ArgumentError("$filename does not have two SimulationStageEvent for step = $step stage = $stage"))
    end

    if events[1].status != "start" || events[2].status != "done"
        throw(ArgumentError("$filename does not contain start and done events for step = $step stage = $stage"))
    end

    return (start = events[1].simulation_time, done = events[2].simulation_time)
end

function _filter_by_type_range!(events::Vector{<:IS.AbstractRecorderEvent}, time_range)
    filter!(
        x -> x.simulation_time >= time_range.start && x.simulation_time <= time_range.done,
        events,
    )
end

function _get_recorder_filename(output_dir, recorder_name)
    return joinpath(output_dir, "recorder", recorder_name * ".log")
end

function _get_simulation_status_recorder_filename(output_dir)
    return _get_recorder_filename(output_dir, "simulation_status")
end

function _get_simulation_recorder_filename(output_dir)
    return _get_recorder_filename(output_dir, "simulation")
end

"""
    list_simulation_events(
        ::Type{T},
        output_dir::AbstractString,
        filter_func::Union{Nothing, Function} = nothing;
        step = nothing,
        stage = nothing,
    ) where {T <: IS.AbstractRecorderEvent}

List simulation events of type T in a simulation output directory.

# Arguments
- `output_dir::AbstractString`: Simulation output directory
- `filter_func::Union{Nothing, Function} = nothing`: Refer to [`show_simulation_events`](@ref).
- `step::Int = nothing`: Filter events by step. Required if stage is passed.
- `stage::Int = nothing`: Filter events by stage.
"""
function list_simulation_events(
    ::Type{T},
    output_dir::AbstractString,
    filter_func::Union{Nothing, Function} = nothing;
    step = nothing,
    stage = nothing,
) where {T <: IS.AbstractRecorderEvent}
    if isnothing(step) && !isnothing(stage)
        throw(ArgumentError("step is required if stage is passed"))
    end

    recorder_file = _get_simulation_recorder_filename(output_dir)
    events = IS.list_recorder_events(T, recorder_file, filter_func)

    if !isnothing(step)
        recorder_file = _get_simulation_status_recorder_filename(output_dir)
        step_range = get_simulation_step_range(recorder_file, step)
        _filter_by_type_range!(events, step_range)
    end

    if !isnothing(stage)
        recorder_file = _get_simulation_status_recorder_filename(output_dir)
        stage_range = get_simulation_stage_range(recorder_file, step, stage)
        _filter_by_type_range!(events, stage_range)
    end

    return events
end

function list_simulation_events(
    ::Type{T},
    output_dir::AbstractString,
    filter_func::Union{Nothing, Function} = nothing;
    kwargs...,
) where {T <: AbstractSimulationStatusEvent}
    recorder_file = _get_simulation_status_recorder_filename(output_dir)
    return IS.list_recorder_events(T, recorder_file, filter_func)
end

"""
    show_simulation_events(
        ::Type{T},
        output_dir::AbstractString,
        filter_func::Union{Nothing,Function} = nothing;
        step = nothing,
        stage = nothing,
        wall_time = false,
        kwargs...,
    ) where { T <: IS.AbstractRecorderEvent}

Show all simulation events of type T in a simulation output directory.

# Arguments
- `::Type{T}`: Recorder event type
- `output_dir::AbstractString`: Simulation output directory
- `filter_func::Union{Nothing, Function} = nothing`: Refer to [`show_recorder_events`](@ref).
- `step::Int = nothing`: Filter events by step. Required if stage is passed.
- `stage::Int = nothing`: Filter events by stage.
- `wall_time = false`: If true, show the wall_time timestamp.
"""
function show_simulation_events(
    ::Type{T},
    output_dir::AbstractString,
    filter_func::Union{Nothing, Function} = nothing;
    step = nothing,
    stage = nothing,
    wall_time = false,
    kwargs...,
) where {T <: IS.AbstractRecorderEvent}
    show_simulation_events(
        stdout,
        T,
        output_dir,
        filter_func;
        step = step,
        stage = stage,
        wall_time = wall_time,
        kwargs...,
    )
end

function show_simulation_events(
    ::Type{T},
    output_dir::AbstractString,
    filter_func::Union{Nothing, Function} = nothing;
    wall_time = false,
    kwargs...,
) where {T <: AbstractSimulationStatusEvent}
    show_simulation_events(
        stdout,
        T,
        output_dir,
        filter_func;
        wall_time = wall_time,
        kwargs...,
    )
end

function show_simulation_events(
    io::IO,
    ::Type{T},
    output_dir::AbstractString,
    filter_func::Union{Nothing, Function} = nothing;
    wall_time = false,
    kwargs...,
) where {T <: AbstractSimulationStatusEvent}
    events = list_simulation_events(T, output_dir, filter_func)
    show_recorder_events(io, events, filter_func; wall_time = wall_time, kwargs...)
end

function show_simulation_events(
    io::IO,
    ::Type{T},
    output_dir::AbstractString,
    filter_func::Union{Nothing, Function} = nothing;
    step = nothing,
    stage = nothing,
    wall_time = false,
    kwargs...,
) where {T <: IS.AbstractRecorderEvent}
    events = list_simulation_events(T, output_dir, filter_func; step = step, stage = stage)
    show_recorder_events(io, events, filter_func; wall_time = wall_time, kwargs...)
end

"""
    show_recorder_events(
        ::Type{T},
        filename::AbstractString,
        filter_func::Union{Nothing, Function} = nothing;
        wall_time = false,
        kwargs...,
    ) where {T <: IS.AbstractRecorderEvent}

Show the events of type T in a recorder file.

# Arguments
- `::Type{T}`: Recorder event type
- `filename::AbstractString`: recorder filename
- `filter_func::Union{Nothing, Function} = nothing`: Optional function that accepts an event
   of type T and returns a Bool. Apply this function to each event and only return events
   where the result is true.
- `wall_time = false`: If true, show the wall_time timestamp.
"""
function show_recorder_events(
    ::Type{T},
    filename::AbstractString,
    filter_func::Union{Nothing, Function} = nothing;
    wall_time = false,
    kwargs...,
) where {T <: IS.AbstractRecorderEvent}
    show_recorder_events(stdout, T, filename, filter_func; wall_time = wall_time, kwargs...)
end

function show_recorder_events(
    io::IO,
    ::Type{T},
    filename::AbstractString,
    filter_func::Union{Nothing, Function} = nothing;
    wall_time = false,
    kwargs...,
) where {T <: IS.AbstractRecorderEvent}
    if wall_time
        IS.show_recorder_events(io, T, filename, filter_func)
    else
        # This will not display the first column, 'timestamp'.
        f_c(data, i) = i > 1
        IS.show_recorder_events(io, filename, filter_func; filters_col = (f_c,), kwargs...)
    end
end

function show_recorder_events(
    io::IO,
    events::Vector{T},
    filter_func::Union{Nothing, Function} = nothing;
    wall_time = false,
    kwargs...,
) where {T <: IS.AbstractRecorderEvent}
    if wall_time
        IS.show_recorder_events(io, events; kwargs...)
    else
        # This will not display the first column, 'timestamp'.
        f_c(data, i) = i > 1
        IS.show_recorder_events(io, events; filters_col = (f_c,), kwargs...)
    end
end
