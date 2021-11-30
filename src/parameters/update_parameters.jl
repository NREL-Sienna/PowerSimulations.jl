function update_parameter_values!(
    ::AbstractArray{T},
    ::NoAttributes,
    args...,
) where {T <: Union{Float64, PJ.ParameterRef}} end

######################## Methods to update Parameters from Time Series #####################
function update_parameter_values!(
    param_array::AbstractArray{PJ.ParameterRef},
    attributes::TimeSeriesAttributes{T},
    ::Type{U},
    model::DecisionModel,
    state,
) where {T <: PSY.AbstractDeterministic, U <: PSY.Device}
    initial_forecast_time = get_current_time(model) # Function not well defined for DecisionModels
    horizon = get_time_steps(get_optimization_container(model))[end]
    components = get_available_components(U, get_system(model))
    for component in components
        ts_vector = get_time_series_values!(
            T,
            model,
            component,
            get_name(attributes),
            initial_forecast_time,
            horizon,
        )
        for (ix, parameter) in enumerate(param_array[PSY.get_name(component), :])
            JuMP.set_value(parameter, ts_vector[ix])
        end
    end
end

function update_parameter_values(
    param_array::AbstractArray{Float64},
    attributes::TimeSeriesAttributes{T},
    ::Type{U},
    model::DecisionModel,
    state,
) where {T <: PSY.AbstractDeterministic, U <: PSY.Device}
    initial_forecast_time = get_current_time(model) # Function not well defined for DecisionModels
    horizon = get_time_steps(get_container(model))[end]
    components = get_available_components(U, get_system(model))
    for component in components
        ts_vector = get_time_series_values!(
            T,
            model,
            component,
            get_name(attributes),
            initial_forecast_time,
            horizon,
        )
        param_array[PSY.get_name(component), :] .= ts_vector
    end
    return
end

function update_parameter_values!(
    param_array::AbstractArray{PJ.ParameterRef},
    attributes::TimeSeriesAttributes{T},
    ::Type{U},
    model::EmulationModel,
    state,
) where {T <: PSY.SingleTimeSeries, U <: PSY.Device}
    initial_forecast_time = get_current_time(model)
    components = get_available_components(U, get_system(model))
    for component in components
        # Note: This interface reads one single value per component at a time.
        ts_vector = get_time_series_values!(
            T,
            model,
            component,
            get_name(attributes),
            initial_forecast_time,
        )
        JuMP.set_value(param_array[PSY.get_name(component), 1], ts_vector[1])
    end
    return
end

function update_parameter_values(
    param_array::AbstractArray{Float64},
    attributes::TimeSeriesAttributes{T},
    ::Type{U},
    model::EmulationModel,
    state,
) where {T <: PSY.SingleTimeSeries, U <: PSY.Device}
    initial_forecast_time = get_current_time(model)
    # TODO: Can we avoid calling get_available_components and cache the component to avoid the filtering in PSY.get_components
    components = get_available_components(U, get_system(model))
    for component in components
        # Note: This interface reads one single value per component at a time.
        ts_vector = get_time_series_values!(
            T,
            model,
            component,
            get_name(attributes),
            initial_forecast_time,
        )
        param_array[PSY.get_name(component), 1] = ts_vector[1]
    end
    return
end

function update_parameter_values!(
    param_array::AbstractArray{PJ.ParameterRef},
    attributes::VariableValueAttributes,
    ::Type{<:PSY.Component},
    model::DecisionModel,
    state,
)
    current_time = get_current_time(model)
    state_data = get_decision_state_data(state, get_attribute_key(attributes))
    values = get_values(state_data)
    component_names, time = axes(param_array)
    resolution = get_resolution(model)
    # TODO: check if this is the most performant way to find the common indices
    state_timestamps = get_timestamps(state_data)
    max_state_index = length(state_timestamps)
    state_data_index = findlast(state_timestamps .<= current_time)
    sim_timestamps = range(current_time, step = resolution, length = time[end])
    for name in component_names, t in time
        time_stamp_ix = min(max_state_index, state_data_index + 1)
        @debug "parameter horizon is over the step" max_state_index > state_data_index + 1
        if state_timestamps[time_stamp_ix] < sim_timestamps[t]
            state_data_index = time_stamp_ix
        end
        JuMP.set_value(param_array[name, t], values[state_data_index, name])
    end
    return
end

function update_parameter_values!(
    param_array::AbstractArray{Float64},
    attributes::VariableValueAttributes,
    ::Type{<:PSY.Component},
    model::DecisionModel,
    state,
)
    current_time = get_current_time(model)
    state_data = get_decision_state_data(state, get_attribute_key(attributes))
    values = get_values(state_data)
    component_names, time = axes(param_array)
    resolution = get_resolution(model)
    # TODO: check if this is the most performant way to find the common indices
    state_timestamps = get_timestamps(state_data)
    max_state_index = length(state_timestamps)
    state_data_index = findlast(state_timestamps .<= current_time)
    sim_timestamps = range(current_time, step = resolution, length = time[end])
    for name in component_names, t in time
        time_stamp_ix = min(max_state_index, state_data_index + 1)
        @debug "parameter horizon is over the step" max_state_index > state_data_index + 1
        if state_timestamps[time_stamp_ix] < sim_timestamps[t]
            state_data_index = time_stamp_ix
        end
        param_array[name, t] = values[state_data_index, name]
    end
    return
end

"""
Update parameter function an OperationModel
"""
function update_parameter_values!(
    model::OperationModel,
    ::ParameterKey{T, U},
    input::Any,
) where {T <: ParameterType, U <: PSY.Device}
    TimerOutputs.@timeit RUN_SIMULATION_TIMER "$T $U Parameter Update" begin
        optimization_container = get_optimization_container(model)
        parameter_array = get_parameter_array(optimization_container, T(), U)
        parameter_attributes = get_parameter_attributes(optimization_container, T(), U)
        update_parameter_values!(parameter_array, parameter_attributes, U, model, input)
        IS.@record :execution ParameterUpdateEvent(
            T,
            U,
            parameter_attributes,
            get_current_timestamp(model),
            get_name(model),
        )
    end
    return
end
