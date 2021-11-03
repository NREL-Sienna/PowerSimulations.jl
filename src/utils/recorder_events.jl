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
    problem::Int
    status::String
end

function ProblemExecutionEvent(
    simulation_time::Dates.DateTime,
    step::Int,
    problem::Int,
    status::AbstractString,
)
    return ProblemExecutionEvent(
        IS.RecorderEventCommon("ProblemExecutionEvent"),
        simulation_time,
        step,
        problem,
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
    problem_number::Int
end

function InitialConditionUpdateEvent(
    simulation_time,
    ic::InitialCondition,
    previous_value::Float64,
    problem_number::Int,
)
    return InitialConditionUpdateEvent(
        IS.RecorderEventCommon("InitialConditionUpdateEvent"),
        simulation_time,
        string(get_ic_type(ic)),
        string(get_component_type(ic)),
        get_component_name(ic),
        get_condition(ic),
        previous_value,
        problem_number,
    )
end

struct ParameterUpdateEvent <: IS.AbstractRecorderEvent
    common::IS.RecorderEventCommon
    execution_timestamp::Dates.DateTime
    parameter_type::String
    device_type::String
    tag::String
    problem_number::Int
end

function ParameterUpdateEvent(
    parameter_type::Type{<:ParameterType},
    device_type::Type{<:PSY.Device},
    tag::String,
    execution_timestamp::Dates.DateTime,
    problem_number::Int,
)
    return ParameterUpdateEvent(
        IS.RecorderEventCommon("ParameterUpdateEvent"),
        execution_timestamp,
        string(parameter_type),
        string(device_type),
        tag,
        problem_number,
    )
end

struct FeedforwardUpdateEvent <: IS.AbstractRecorderEvent
    common::IS.RecorderEventCommon
    category::String
    simulation_time::Dates.DateTime
    parameter_type::String
    device_name::String
    previous_value::Float64
    val::Float64
    problem_number::Int
    source::Int
end

function FeedforwardUpdateEvent(
    category::String,
    simulation_time::Dates.DateTime,
    parameter::VariableValueParameter,
    device_name::String,
    val::Float64,
    previous_value::Float64,
    destination_model::DecisionModel,
    source_model::DecisionModel,
)
    return FeedforwardUpdateEvent(
        IS.RecorderEventCommon("FeedforwardUpdateEvent"),
        category,
        simulation_time,
        parameter,
        device_name,
        previous_value,
        val,
        get_simulation_number(destination_problem),
        get_simulation_number(source_problem),
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

function get_simulation_problem_range(filename::AbstractString, step::Int, problem::Int)
    events = IS.list_recorder_events(
        ProblemExecutionEvent,
        filename,
        x -> x.step == step && x.problem == problem,
    )
    if length(events) != 2
        throw(
            ArgumentError(
                "$filename does not have two ProblemExecutionEvent for step = $step problem = $problem",
            ),
        )
    end

    if events[1].status != "start" || events[2].status != "done"
        throw(
            ArgumentError(
                "$filename does not contain start and done events for step = $step problem = $problem",
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
        problem = nothing,
    ) where {T <: IS.AbstractRecorderEvent}

List simulation events of type T in a simulation output directory.

# Arguments
- `output_dir::AbstractString`: Simulation output directory
- `filter_func::Union{Nothing, Function} = nothing`: Refer to [`show_simulation_events`](@ref).
- `step::Int = nothing`: Filter events by step. Required if problem is passed.
- `problem::Int = nothing`: Filter events by problem.
"""
function list_simulation_events(
    ::Type{T},
    output_dir::AbstractString,
    filter_func::Union{Nothing, Function} = nothing;
    step = nothing,
    problem = nothing,
) where {T <: IS.AbstractRecorderEvent}
    if problem !== nothing && step === nothing
        throw(ArgumentError("step is required if problem is passed"))
    end

    recorder_file = _get_simulation_recorder_filename(output_dir)
    events = IS.list_recorder_events(T, recorder_file, filter_func)

    if step !== nothing
        recorder_file = _get_simulation_status_recorder_filename(output_dir)
        step_range = get_simulation_step_range(recorder_file, step)
        _filter_by_type_range!(events, step_range)
    end

    if problem !== nothing
        recorder_file = _get_simulation_status_recorder_filename(output_dir)
        problem_range = get_simulation_problem_range(recorder_file, step, problem)
        _filter_by_type_range!(events, problem_range)
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
        problem = nothing,
        wall_time = false,
        kwargs...,
    ) where { T <: IS.AbstractRecorderEvent}

Show all simulation events of type T in a simulation output directory.

# Arguments
- `::Type{T}`: Recorder event type
- `output_dir::AbstractString`: Simulation output directory
- `filter_func::Union{Nothing, Function} = nothing`: Refer to [`show_recorder_events`](@ref).
- `step::Int = nothing`: Filter events by step. Required if problem is passed.
- `problem::Int = nothing`: Filter events by problem.
- `wall_time = false`: If true, show the wall_time timestamp.
"""
function show_simulation_events(
    ::Type{T},
    output_dir::AbstractString,
    filter_func::Union{Nothing, Function} = nothing;
    step = nothing,
    problem = nothing,
    wall_time = false,
    kwargs...,
) where {T <: IS.AbstractRecorderEvent}
    show_simulation_events(
        stdout,
        T,
        output_dir,
        filter_func;
        step = step,
        problem = problem,
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
    problem = nothing,
    wall_time = false,
    kwargs...,
) where {T <: IS.AbstractRecorderEvent}
    events =
        list_simulation_events(T, output_dir, filter_func; step = step, problem = problem)
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
