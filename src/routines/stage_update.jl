#########################TimeSeries Data Updating###########################################
function update_parameter!(
    param_reference::UpdateRef{T},
    container::ParameterContainer,
    stage::Stage,
    sim::Simulation,
) where {T <: PSY.Component}
    devices = PSY.get_components(T, stage.sys)
    initial_forecast_time = get_simulation_time(sim, get_number(stage))
    horizon = length(model_time_steps(stage.internal.psi_container))
    for d in devices
        forecast = PSY.get_forecast(
            PSY.Deterministic,
            d,
            initial_forecast_time,
            get_accessor_func(param_reference),
            horizon,
        )
        ts_vector = TS.values(PSY.get_data(forecast))
        device_name = PSY.get_name(d)
        for (ix, val) in enumerate(container.array[device_name, :])
            value = ts_vector[ix]
            JuMP.fix(val, value)
        end
    end

    return
end

"""Updates the forecast parameter value"""
function update_parameter!(
    param_reference::UpdateRef{JuMP.VariableRef},
    container::ParameterContainer,
    stage::Stage,
    sim::Simulation,
)
    param_array = get_parameter_array(container)
    for (k, ref) in stage.internal.chronolgy_dict
        feedforward_update(ref, param_reference, param_array, stage, get_stage(sim, k))
    end

    return
end

function _update_initial_conditions!(stage::Stage, sim::Simulation)
    ini_cond_chronology = sim.sequence.ini_cond_chronology
    for (k, v) in get_initial_conditions(stage.internal.psi_container)
        initial_condition_update!(stage, k, ini_cond_chronology, sim)
    end
    return
end

function _update_parameters(stage::Stage, sim::Simulation)
    for container in iterate_parameter_containers(stage.internal.psi_container)
        update_parameter!(container.update_ref, container, stage, sim)
    end
    return
end

""" Required update stage function call"""
# Is possible this function needs a better name
function _update_stage!(stage::Stage, sim::Simulation)
    _update_parameters(stage, sim)
    _update_initial_conditions!(stage, sim)
    return
end

#############################Interfacing Functions##########################################
## These are the functions that the user will have to implement to update a custom stage ###
""" Generic Stage update function for most problems with no customization"""
function update_stage!(
    stage::Stage{M},
    sim::Simulation,
) where {M <: AbstractOperationsProblem}
    _update_stage!(stage, sim)
    return
end
