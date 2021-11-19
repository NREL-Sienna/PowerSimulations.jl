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

struct ProblemExecutionEvent <: AbstractSimulationStatusEvent
    common::IS.RecorderEventCommon
    simulation_time::Dates.DateTime
    step::Int
    model::Int
    status::String
end

function ProblemExecutionEvent(
    simulation_time::Dates.DateTime,
    step::Int,
    model::Int,
    status::AbstractString,
)
    return ProblemExecutionEvent(
        IS.RecorderEventCommon("ProblemExecutionEvent"),
        simulation_time,
        step,
        model,
        status,
    )
end

struct InitialConditionUpdateEvent <: IS.AbstractRecorderEvent
    common::IS.RecorderEventCommon
    execution_timestamp::Dates.DateTime
    initial_condition_type::String
    device_type::String
    device_name::String
    new_value::Float64
    previous_value::Float64
    model_number::Int
end

function InitialConditionUpdateEvent(
    simulation_time,
    ic::InitialCondition,
    previous_value::Float64,
    model_number::Int,
)
    return InitialConditionUpdateEvent(
        IS.RecorderEventCommon("InitialConditionUpdateEvent"),
        simulation_time,
        string(get_ic_type(ic)),
        string(get_component_type(ic)),
        get_component_name(ic),
        get_condition(ic),
        previous_value,
        model_number,
    )
end

struct ParameterUpdateEvent <: IS.AbstractRecorderEvent
    common::IS.RecorderEventCommon
    execution_timestamp::Dates.DateTime
    parameter_type::String
    device_type::String
    tag::String
    model_name::String
end

function ParameterUpdateEvent(
    parameter_type::Type{<:ParameterType},
    device_type::Type{<:PSY.Device},
    tag::String,
    execution_timestamp::Dates.DateTime,
    model_name,
)
    return ParameterUpdateEvent(
        IS.RecorderEventCommon("ParameterUpdateEvent"),
        execution_timestamp,
        string(parameter_type),
        string(device_type),
        tag,
        string(model_name),
    )
end

struct StateUpdateEvent <: IS.AbstractRecorderEvent
    common::IS.RecorderEventCommon
    execution_timestamp::Dates.DateTime
    entry_type::String
    component_type::String
    model_name::String
end

function StateUpdateEvent(
    entry_type::DataType,
    component_type::DataType,
    execution_timestamp::Dates.DateTime,
    model_name,
)
    return StateUpdateEvent(
        IS.RecorderEventCommon("StateUpdateEvent"),
        execution_timestamp,
        string(entry_type),
        string(component_type),
        string(model_name),
    )
end

function StateUpdateEvent(
    key::OptimizationContainerKey,
    execution_timestamp::Dates.DateTime,
    model_name,
)
    return StateUpdateEvent(
        get_entry_type(key),
        get_component_type(key),
        execution_timestamp,
        model_name,
    )
end

function get_simulation_step_range(filename::AbstractString, step::Int)
    events = IS.list_recorder_events(SimulationStepEvent, filename, x -> x.step == step)
    if length(events) != 2
        throw(
            ArgumentError(
                "$filename does not have two SimulationStepEvents for step = $step",
            ),
        )
    end

    if events[1].status != "start" || events[2].status != "done"
        throw(
            ArgumentError(
                "$filename does not contain start and done events for step = $step",
            ),
        )
    end

    return (start = events[1].simulation_time, done = events[2].simulation_time)
end

function get_simulation_model_range(filename::AbstractString, step::Int, model::Int)
    events = IS.list_recorder_events(
        ProblemExecutionEvent,
        filename,
        x -> x.step == step && x.model == model,
    )
    if length(events) != 2
        throw(
            ArgumentError(
                "$filename does not have two ProblemExecutionEvent for step = $step model = $model",
            ),
        )
    end

    if events[1].status != "start" || events[2].status != "done"
        throw(
            ArgumentError(
                "$filename does not contain start and done events for step = $step model = $model",
            ),
        )
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
        model = nothing,
    ) where {T <: IS.AbstractRecorderEvent}

List simulation events of type T in a simulation output directory.

# Arguments
- `output_dir::AbstractString`: Simulation output directory
- `filter_func::Union{Nothing, Function} = nothing`: Refer to [`show_simulation_events`](@ref).
- `step::Int = nothing`: Filter events by step. Required if model is passed.
- `model::Int = nothing`: Filter events by model.
"""
function list_simulation_events(
    ::Type{T},
    output_dir::AbstractString,
    filter_func::Union{Nothing, Function} = nothing;
    step = nothing,
    model = nothing,
) where {T <: IS.AbstractRecorderEvent}
    if model !== nothing && step === nothing
        throw(ArgumentError("step is required if model is passed"))
    end

    recorder_file = _get_simulation_recorder_filename(output_dir)
    events = IS.list_recorder_events(T, recorder_file, filter_func)

    if step !== nothing
        recorder_file = _get_simulation_status_recorder_filename(output_dir)
        step_range = get_simulation_step_range(recorder_file, step)
        _filter_by_type_range!(events, step_range)
    end

    if model !== nothing
        recorder_file = _get_simulation_status_recorder_filename(output_dir)
        model_range = get_simulation_model_range(recorder_file, step, model)
        _filter_by_type_range!(events, model_range)
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
        model = nothing,
        wall_time = false,
        kwargs...,
    ) where { T <: IS.AbstractRecorderEvent}

Show all simulation events of type T in a simulation output directory.

# Arguments
- `::Type{T}`: Recorder event type
- `output_dir::AbstractString`: Simulation output directory
- `filter_func::Union{Nothing, Function} = nothing`: Refer to [`show_recorder_events`](@ref).
- `step::Int = nothing`: Filter events by step. Required if model is passed.
- `model::Int = nothing`: Filter events by model.
- `wall_time = false`: If true, show the wall_time timestamp.
"""
function show_simulation_events(
    ::Type{T},
    output_dir::AbstractString,
    filter_func::Union{Nothing, Function} = nothing;
    step = nothing,
    model = nothing,
    wall_time = false,
    kwargs...,
) where {T <: IS.AbstractRecorderEvent}
    show_simulation_events(
        stdout,
        T,
        output_dir,
        filter_func;
        step = step,
        model = model,
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
    model = nothing,
    wall_time = false,
    kwargs...,
) where {T <: IS.AbstractRecorderEvent}
    events = list_simulation_events(T, output_dir, filter_func; step = step, model = model)
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
        IS.show_recorder_events(
            io,
            T,
            filename,
            filter_func;
            filters_col = (f_c,),
            kwargs...,
        )
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
