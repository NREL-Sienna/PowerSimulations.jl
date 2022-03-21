function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.RegulationDevice{T}, U},
    ::Type{AreaBalancePowerModel},
) where {T <: PSY.StaticInjection, U <: DeviceLimitedRegulation}
    devices = get_available_components(get_component_type(model), sys)
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        AreaBalancePowerModel,
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
    ::ModelConstructStage,
    model::DeviceModel{PSY.RegulationDevice{T}, DeviceLimitedRegulation},
    ::Type{AreaBalancePowerModel},
) where {T <: PSY.StaticInjection}
    devices = get_available_components(get_component_type(model), sys)

    add_constraints!(
        container,
        RegulationLimitsConstraint,
        DeltaActivePowerUpVariable,
        devices,
        model,
        AreaBalancePowerModel,
    )

    add_constraints!(container, RampLimitConstraint, devices, model, AreaBalancePowerModel)
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
    model::DeviceModel{PSY.RegulationDevice{T}, U},
    ::Type{AreaBalancePowerModel},
) where {T <: PSY.StaticInjection, U <: ReserveLimitedRegulation}
    devices = get_available_components(get_component_type(model), sys)
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        AreaBalancePowerModel,
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
    ::ModelConstructStage,
    model::DeviceModel{PSY.RegulationDevice{T}, ReserveLimitedRegulation},
    ::Type{AreaBalancePowerModel},
) where {T <: PSY.StaticInjection}
    devices = get_available_components(get_component_type(model), sys)

    add_constraints!(
        container,
        RegulationLimitsConstraint,
        DeltaActivePowerUpVariable,
        devices,
        model,
        AreaBalancePowerModel,
    )

    add_constraints!(container, ParticipationAssignmentConstraint, devices, model, S)
    objective_function!(container, devices, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.RegulationDevice{T}, FixedOutput},
    ::Type{AreaBalancePowerModel},
) where {T <: PSY.StaticInjection}
    devices = get_available_components(get_component_type(model), sys)
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        S,
    )
    return
end

function construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ModelConstructStage,
    ::DeviceModel{PSY.RegulationDevice{T}, FixedOutput},
    ::Type{AreaBalancePowerModel},
) where {T <: PSY.StaticInjection}
    # There is no-op under FixedOutput formulation
    return
end
