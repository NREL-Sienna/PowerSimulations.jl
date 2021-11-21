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

"""
Update parameter function for TimeSeriesParameters in an OperationModel
"""
function update_parameter_values!(
    model::OperationModel,
    ::ParameterKey{T, U},
) where {T <: TimeSeriesParameter, U <: PSY.Device}
    TimerOutputs.@timeit RUN_SIMULATION_TIMER "$T $U Parameter Update" begin
        optimization_container = PSI.get_optimization_container(model)
        parameter_array = PSI.get_parameter_array(optimization_container, T(), U)
        parameter_attributes = get_parameter_attributes(optimization_container, T(), U)
        update_parameter_values!(parameter_array, parameter_attributes, U, model)
        _gen_parameter_update_event(
            parameter_attributes,
            T,
            U,
            get_current_timestamp(model),
            get_name(model),
        )
    end
    return
end

function _gen_parameter_update_event(
    attributes::TimeSeriesAttributes,
    parameter_type::Type{<:ParameterType},
    device_type::Type{<:PSY.Device},
    timestamp::Dates.DateTime,
    model_name,
)
    IS.@record :execution ParameterUpdateEvent(
        parameter_type,
        device_type,
        attributes.name,
        timestamp,
        model_name,
    )
end

###################### Methods to update Parameters from Variable Values ###################
function update_parameter_values!(
    model::OperationModel,
    ::ParameterKey{T, U},
) where {T <: VariableValueParameter, U <: PSY.Device} end

function _gen_parameter_update_event(
    ::ParameterAttributes,
    ::Type{<:ParameterType},
    ::Type{<:PSY.Device},
    ::String,
    ::Dates.DateTime,
    ::Any,
)
    return
end
