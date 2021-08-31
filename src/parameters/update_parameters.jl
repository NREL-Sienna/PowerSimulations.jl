"""
Update parameter function for TimeSeriesParameters in an OperationModel
"""
function update_parameter_values!(model::OperationModel, ::T, ::Type{U}) where {T <: TimeSeriesParameter, U <: PSY.Device}

end



######################### TimeSeries Data Updating###########################################
function update_parameter!(
    container::ParameterContainer,
    model::DecisionModel,
    sim::Simulation,
) where {T <: PSY.Component}
    TimerOutputs.@timeit RUN_SIMULATION_TIMER "ts_update_parameter!" begin
        components = get_available_components(T, model.sys)
        initial_forecast_time = get_simulation_time(sim, get_simulation_number(model))
        horizon = length(get_time_steps(model.internal.container))
        for d in components
            ts_vector = get_time_series_values!(
                PSY.Deterministic,
                model,
                d,
                get_data_name(param_reference),
                initial_forecast_time,
                horizon,
                ignore_scaling_factors = true,
            )
            component_name = PSY.get_name(d)
            for (ix, val) in enumerate(get_parameter_array(container)[component_name, :])
                value = ts_vector[ix]
                JuMP.set_value(val, value)
            end
        end
    end

    return
end

function update_parameter!(
    param_reference::UpdateRef{T},
    container::ParameterContainer,
    model::DecisionModel,
    sim::Simulation,
) where {T <: PSY.Service}
    TimerOutputs.@timeit RUN_SIMULATION_TIMER "ts_update_parameter!" begin
        components = get_available_components(T, model.sys)
        initial_forecast_time = get_simulation_time(sim, get_simulation_number(model))
        horizon = length(get_time_steps(model.internal.container))
        param_array = get_parameter_array(container)
        for ix in axes(param_array)[1]
            service = PSY.get_component(T, model.sys, ix)
            ts_vector = get_time_series_values!(
                PSY.Deterministic,
                model,
                service,
                get_data_name(param_reference),
                initial_forecast_time,
                horizon,
                ignore_scaling_factors = true,
            )
            for (jx, value) in enumerate(ts_vector)
                JuMP.set_value(get_parameter_array(container)[ix, jx], value)
            end
        end
    end

    return
end

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
