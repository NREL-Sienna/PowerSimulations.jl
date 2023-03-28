function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{St, D},
    network_model::NetworkModel{S},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    add_variables!(container, ActivePowerInVariable, devices, D())
    add_variables!(container, ActivePowerOutVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())
    add_variables!(container, EnergyVariable, devices, D())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, D())
    end

    initial_conditions!(container, devices, D())

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{St, D},
    network_model::NetworkModel{S},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        EnergyCapacityConstraint,
        EnergyVariable,
        devices,
        model,
        network_model,
    )

    # Energy Balanace limits
    add_constraints!(container, EnergyBalanceConstraint, devices, model, network_model)

    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{St, D},
    network_model::NetworkModel{S},
) where {
    St <: PSY.Storage,
    D <: AbstractStorageFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(St, sys)

    add_variables!(container, ActivePowerInVariable, devices, D())
    add_variables!(container, ActivePowerOutVariable, devices, D())
    add_variables!(container, EnergyVariable, devices, D())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, D())
    end

    initial_conditions!(container, devices, D())

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{St, D},
    network_model::NetworkModel{S},
) where {
    St <: PSY.Storage,
    D <: AbstractStorageFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(St, sys)

    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        EnergyCapacityConstraint,
        EnergyVariable,
        devices,
        model,
        network_model,
    )

    # Energy Balanace limits
    add_constraints!(container, EnergyBalanceConstraint, devices, model, network_model)

    add_feedforward_constraints!(container, model, devices)

    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{St, EnergyTarget},
    network_model::NetworkModel{S},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    add_variables!(container, ActivePowerInVariable, devices, EnergyTarget())
    add_variables!(container, ActivePowerOutVariable, devices, EnergyTarget())
    add_variables!(container, ReactivePowerVariable, devices, EnergyTarget())
    add_variables!(container, EnergyVariable, devices, EnergyTarget())
    add_variables!(container, EnergyShortageVariable, devices, EnergyTarget())
    add_variables!(container, EnergySurplusVariable, devices, EnergyTarget())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, EnergyTarget())
    end

    add_parameters!(container, EnergyTargetTimeSeriesParameter, devices, model)

    initial_conditions!(container, devices, EnergyTarget())

    add_expressions!(container, ProductionCostExpression, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{St, EnergyTarget},
    network_model::NetworkModel{S},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        EnergyCapacityConstraint,
        EnergyVariable,
        devices,
        model,
        network_model,
    )

    # Energy Balanace limits
    add_constraints!(container, EnergyBalanceConstraint, devices, model, network_model)
    add_constraints!(container, EnergyTargetConstraint, devices, model, network_model)
    add_feedforward_constraints!(container, model, devices)

    objective_function!(container, devices, model, S)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{St, EnergyTarget},
    network_model::NetworkModel{S},
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(St, sys)

    add_variables!(container, ActivePowerInVariable, devices, EnergyTarget())
    add_variables!(container, ActivePowerOutVariable, devices, EnergyTarget())
    add_variables!(container, EnergyVariable, devices, EnergyTarget())
    add_variables!(container, EnergyShortageVariable, devices, EnergyTarget())
    add_variables!(container, EnergySurplusVariable, devices, EnergyTarget())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, EnergyTarget())
    end

    add_parameters!(container, EnergyTargetTimeSeriesParameter, devices, model)

    initial_conditions!(container, devices, EnergyTarget())

    add_expressions!(container, ProductionCostExpression, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{St, EnergyTarget},
    network_model::NetworkModel{S},
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(St, sys)

    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        EnergyCapacityConstraint,
        EnergyVariable,
        devices,
        model,
        network_model,
    )

    # Energy Balanace limits
    add_constraints!(container, EnergyBalanceConstraint, devices, model, network_model)
    add_constraints!(container, EnergyTargetConstraint, devices, model, network_model)
    add_feedforward_constraints!(container, model, devices)

    objective_function!(container, devices, model, S)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{St, BatteryAncillaryServices},
    network_model::NetworkModel{S},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    add_variables!(container, ActivePowerInVariable, devices, BatteryAncillaryServices())
    add_variables!(container, ActivePowerOutVariable, devices, BatteryAncillaryServices())
    add_variables!(container, ReactivePowerVariable, devices, BatteryAncillaryServices())
    add_variables!(container, EnergyVariable, devices, BatteryAncillaryServices())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, BatteryAncillaryServices())
    end

    initial_conditions!(container, devices, BatteryAncillaryServices())

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerVariable,
        devices,
        model,
        network_model,
    )
    if has_service_model(model)
        add_expressions!(container, ReserveRangeExpressionLB, devices, model)
        add_expressions!(container, ReserveRangeExpressionUB, devices, model)
    end
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{St, BatteryAncillaryServices},
    network_model::NetworkModel{S},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        EnergyCapacityConstraint,
        EnergyVariable,
        devices,
        model,
        network_model,
    )

    # Energy Balanace limits
    add_constraints!(container, EnergyBalanceConstraint, devices, model, network_model)
    if has_service_model(model)
        add_constraints!(
            container,
            ReserveEnergyCoverageConstraint,
            devices,
            model,
            network_model,
        )
        add_constraints!(container, RangeLimitConstraint, devices, model, network_model)
    end
    add_feedforward_constraints!(container, model, devices)

    add_constraint_dual!(container, sys, model)

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{St, BatteryAncillaryServices},
    network_model::NetworkModel{S},
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(St, sys)

    add_variables!(container, ActivePowerInVariable, devices, BatteryAncillaryServices())
    add_variables!(container, ActivePowerOutVariable, devices, BatteryAncillaryServices())
    add_variables!(container, EnergyVariable, devices, BatteryAncillaryServices())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, BatteryAncillaryServices())
    end

    initial_conditions!(container, devices, BatteryAncillaryServices())

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )
    if has_service_model(model)
        add_expressions!(container, ReserveRangeExpressionLB, devices, model)
        add_expressions!(container, ReserveRangeExpressionUB, devices, model)
    end
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{St, BatteryAncillaryServices},
    network_model::NetworkModel{S},
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(St, sys)

    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        EnergyCapacityConstraint,
        EnergyVariable,
        devices,
        model,
        network_model,
    )

    # Energy Balanace limits
    add_constraints!(container, EnergyBalanceConstraint, devices, model, network_model)
    if has_service_model(model)
        add_constraints!(
            container,
            ReserveEnergyCoverageConstraint,
            devices,
            model,
            network_model,
        )
        add_constraints!(container, RangeLimitConstraint, devices, model, network_model)
    end

    add_feedforward_constraints!(container, model, devices)

    add_constraint_dual!(container, sys, model)

    return
end
