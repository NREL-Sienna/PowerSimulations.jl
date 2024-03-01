function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.RegulationDevice{T}, U},
    network_model::NetworkModel{AreaBalancePowerModel},
) where {T <: PSY.StaticInjection, U <: DeviceLimitedRegulation}
    devices = get_available_components(get_component_type(model), sys)
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        network_model,
    )

    add_variables!(container, DeltaActivePowerUpVariable, devices, U())
    add_variables!(container, DeltaActivePowerDownVariable, devices, U())
    add_variables!(container, AdditionalDeltaActivePowerUpVariable, devices, U())
    add_variables!(container, AdditionalDeltaActivePowerDownVariable, devices, U())
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::IS.ModelConstructStage,
    model::DeviceModel{PSY.RegulationDevice{T}, DeviceLimitedRegulation},
    network_model::NetworkModel{AreaBalancePowerModel},
) where {T <: PSY.StaticInjection}
    devices = get_available_components(get_component_type(model), sys)

    add_constraints!(
        container,
        RegulationLimitsConstraint,
        DeltaActivePowerUpVariable,
        devices,
        model,
        network_model,
    )

    add_constraints!(container, RampLimitConstraint, devices, model, network_model)
    add_constraints!(
        container,
        ParticipationAssignmentConstraint,
        devices,
        model,
        network_model,
    )
    objective_function!(container, devices, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.RegulationDevice{T}, U},
    network_model::NetworkModel{AreaBalancePowerModel},
) where {T <: PSY.StaticInjection, U <: ReserveLimitedRegulation}
    devices = get_available_components(get_component_type(model), sys)
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        network_model,
    )

    add_variables!(container, DeltaActivePowerUpVariable, devices, U())
    add_variables!(container, DeltaActivePowerDownVariable, devices, U())
    add_variables!(container, AdditionalDeltaActivePowerUpVariable, devices, U())
    add_variables!(container, AdditionalDeltaActivePowerDownVariable, devices, U())
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::IS.ModelConstructStage,
    model::DeviceModel{PSY.RegulationDevice{T}, ReserveLimitedRegulation},
    network_model::NetworkModel{AreaBalancePowerModel},
) where {T <: PSY.StaticInjection}
    devices = get_available_components(get_component_type(model), sys)

    add_constraints!(
        container,
        RegulationLimitsConstraint,
        DeltaActivePowerUpVariable,
        devices,
        model,
        network_model,
    )

    add_constraints!(
        container,
        ParticipationAssignmentConstraint,
        devices,
        model,
        AreaBalancePowerModel,
    )
    objective_function!(container, devices, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.RegulationDevice{<:PSY.StaticInjection}, FixedOutput},
    network_model::NetworkModel{AreaBalancePowerModel},
)
    devices = get_available_components(get_component_type(model), sys)
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        network_model,
    )
    return
end

function construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::IS.ModelConstructStage,
    ::DeviceModel{PSY.RegulationDevice{<:PSY.StaticInjection}, FixedOutput},
    network_model::NetworkModel{AreaBalancePowerModel},
)
    # There is no-op under FixedOutput formulation
    return
end
