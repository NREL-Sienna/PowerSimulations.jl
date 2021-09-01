function update_parameter_values!(
    ::AbstractArray{T},
    ::NoAttributes,
    args...,
) where {T <: Union{Float64, PJ.ParameterRef}} end

function update_parameter_values!(
    param_array::AbstractArray{PJ.ParameterRef},
    attributes::TimeSeriesAttributes{T},
    ::Type{U},
    model::DecisionModel,
) where {T <: PSY.AbstractDeterministic, U <: PSY.Device}
    initial_forecast_time = get_current_time(model) # Function not well defined for DecisionModels
    horizon = get_time_steps(get_container(model))[end]
    # TODO: Can we avoid calling get_available_components ?
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
    # TODO: Can we avoid calling get_available_components ?
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
    # TODO: Can we avoid calling get_available_components ?
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
    # TODO: Can we avoid calling get_available_components ?
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
        # TODO: Add recorder here for parameter update
        optimization_container = PSI.get_optimization_container(model)
        parameter_array = PSI.get_parameter_array(optimization_container, T(), U)
        parameter_attributes = PSI.get_parameter_attributes(optimization_container, T(), U)
        system = PSI.get_system(model)
        update_parameter_values!(parameter_array, parameter_attributes, U, model)
    end
    return
end

# Old update parameter code for reference
#=
"""Updates the forecast parameter value"""
function update_parameter!(
    param_reference::UpdateRef{JuMP.VariableRef},
    container::ParameterContainer,
    model::DecisionModel,
    sim::Simulation,
)
    param_array = get_parameter_array(container)
    simulation_info = get_simulation_info(model)
    for (k, chronology) in simulation_info.chronolgy_dict
        source_model = get_model(sim, k)
        feedforward_update!(
            problem,
            source_model,
            chronology,
            param_reference,
            param_array,
            get_current_time(sim),
        )
    end

    return
end
=#
