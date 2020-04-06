struct SimulationStepEvent <: IS.AbstractRecorderEvent
    common::IS.RecorderEventCommon
    step::Int
    state::String
end

function SimulationStepEvent(step::Int, state::AbstractString)
    return SimulationStepEvent(IS.RecorderEventCommon("SimulationStepEvent"), step, state)
end

struct SimulationStageEvent <: IS.AbstractRecorderEvent
    common::IS.RecorderEventCommon
    step::Int
    stage::Int
    state::String
end

function SimulationStageEvent(step::Int, stage::Int, state::AbstractString)
    return SimulationStageEvent(
        IS.RecorderEventCommon("SimulationStageEvent"),
        step,
        stage,
        state,
    )
end

struct InitialConditionUpdateEvent <: IS.AbstractRecorderEvent
    common::IS.RecorderEventCommon
    initial_condition_type::String
    device_type::String
    device_name::String
    val::Float64
    stage_number::Int
end

function InitialConditionUpdateEvent(
    key::ICKey,
    ic::InitialCondition,
    val::Float64,
    stage_number::Int,
)
    return InitialConditionUpdateEvent(
        IS.RecorderEventCommon("InitialConditionUpdateEvent"),
        string(key.ic_type),
        string(key.device_type),
        device_name(ic),
        val,
        stage_number,
    )
end

function get_simulation_step_range(filename::AbstractString, step::Int)
    events = IS.list_recorder_events(SimulationStepEvent, filename, x -> x.step == step)
    if length(events) != 2
        throw(IS.DataFormatError("$filename does not have two SimulationStepEvents for step = $step"))
    end

    if events[1].state != "start" || events[2].state != "done"
        throw(IS.DataFormatError("$filename does not contain start and done events for step = $step"))
    end

    return (start = IS.get_timestamp(events[1]), done = IS.get_timestamp(events[2]))
end

function get_simulation_stage_range(filename::AbstractString, step::Int, stage::Int)
    events = IS.list_recorder_events(
        SimulationStageEvent,
        filename,
        x -> x.step == step && x.stage == stage,
    )
    if length(events) != 2
        throw(IS.DataFormatError("$filename does not have two SimulationStageEvent for step = $step stage = $stage"))
    end

    if events[1].state != "start" || events[2].state != "done"
        throw(IS.DataFormatError("$filename does not contain start and done events for step = $step stage = $stage"))
    end

    return (start = IS.get_timestamp(events[1]), done = IS.get_timestamp(events[2]))
end

function _filter_by_type_range!(events::Vector{<:IS.AbstractRecorderEvent}, time_range)
    filter!(
        x ->
            IS.get_timestamp(x) >= time_range.start &&
            IS.get_timestamp(x) <= time_range.done,
        events,
    )
end

function _get_recorder_filename(directory, sim_name, recorder_name)
    return joinpath(directory, sim_name, recorder_name * "_recorder.log")
end

function _get_simulation_states_recorder_filename(directory, sim_name)
    return _get_recorder_filename(directory, sim_name, "simulation_states")
end

function _get_simulation_recorder_filename(directory, sim_name)
    return _get_recorder_filename(directory, sim_name, "simulation")
end

"""
List simulation events of type T that occur within the given step.
"""
function list_simulation_events(
    ::Type{T},
    results_directory::AbstractString,
    simulation_name::AbstractString,
    step::Int,
    filter_func::Union{Nothing, Function} = nothing,
) where {T <: IS.AbstractRecorderEvent}
    step_range = get_simulation_step_range(
        _get_simulation_states_recorder_filename(results_directory, simulation_name),
        step,
    )
    events = IS.list_recorder_events(
        T,
        _get_simulation_recorder_filename(results_directory, simulation_name),
        filter_func,
    )
    _filter_by_type_range!(events, step_range)
    return events
end

"""
List simulation events of type T that occur within the given step and stage.
"""
function list_simulation_events(
    ::Type{T},
    results_directory::AbstractString,
    simulation_name::AbstractString,
    step::Int,
    stage::Int,
    filter_func::Union{Nothing, Function} = nothing,
) where {T <: IS.AbstractRecorderEvent}
    stage_range = get_simulation_stage_range(
        _get_simulation_states_recorder_filename(results_directory, simulation_name),
        step,
        stage,
    )
    events = IS.list_recorder_events(
        T,
        _get_simulation_recorder_filename(results_directory, simulation_name),
        filter_func,
    )
    _filter_by_type_range!(events, stage_range)
    return events
end

"""
Show simulation events of type T that occur within the given step.
"""
function show_simulation_events(
    ::Type{T},
    results_directory::AbstractString,
    simulation_name::AbstractString,
    step::Int,
    filter_func::Union{Nothing, Function} = nothing;
    kwargs...,
) where {T <: IS.AbstractRecorderEvent}
    show_simulation_events(
        stdout,
        T,
        results_directory,
        simulation_name,
        step,
        filter_func;
        kwargs...,
    )
end

function show_simulation_events(
    io::IO,
    ::Type{T},
    results_directory::AbstractString,
    simulation_name::AbstractString,
    step::Int,
    filter_func::Union{Nothing, Function} = nothing;
    kwargs...,
) where {T <: IS.AbstractRecorderEvent}
    events =
        list_simulation_events(T, results_directory, simulation_name, step, filter_func)
    IS.show_recorder_events(io, events; kwargs...)
end

"""
Show simulation events of type T that occur within the given step and stage.
"""
function show_simulation_events(
    ::Type{T},
    results_directory::AbstractString,
    simulation_name::AbstractString,
    step::Int,
    stage::Int,
    filter_func::Union{Nothing, Function} = nothing;
    kwargs...,
) where {T <: IS.AbstractRecorderEvent}
    show_simulation_events(
        stdout,
        T,
        results_directory,
        simulation_name,
        step,
        stage,
        filter_func;
        kwargs...,
    )
end

function show_simulation_events(
    io::IO,
    ::Type{T},
    results_directory::AbstractString,
    simulation_name::AbstractString,
    step::Int,
    stage::Int,
    filter_func::Union{Nothing, Function} = nothing;
    kwargs...,
) where {T <: IS.AbstractRecorderEvent}
    events = list_simulation_events(
        T,
        results_directory,
        simulation_name,
        step,
        stage,
        filter_func,
    )
    IS.show_recorder_events(io, events; kwargs...)
end
