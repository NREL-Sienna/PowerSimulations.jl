function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{St, D},
    ::Type{S},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    # Variables
    add_variables!(container, ActivePowerInVariable, devices, D())
    add_variables!(container, ActivePowerOutVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())
    add_variables!(container, EnergyVariable, devices, D())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, D())
    end
    # Initial Conditions
    initial_conditions!(container, devices, D())

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerVariable,
        devices,
        model,
        S,
    )
    add_feedforward_arguments!(container, model, devices)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{St, D},
    ::Type{S},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    # Constraints
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
    )
    energy_capacity_constraints!(container, devices, model, S)
    add_feedforward_constraints!(container, model, devices)

    # Energy Balanace limits
    add_constraints!(container, EnergyBalanceConstraint, devices, model, S)

    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{St, D},
    ::Type{S},
) where {
    St <: PSY.Storage,
    D <: AbstractStorageFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(St, sys)

    # Variables
    add_variables!(container, ActivePowerInVariable, devices, D())
    add_variables!(container, ActivePowerOutVariable, devices, D())
    add_variables!(container, EnergyVariable, devices, D())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, D())
    end
    # Initial Conditions
    initial_conditions!(container, devices, D())

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )
    add_feedforward_arguments!(container, model, devices)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{St, D},
    ::Type{S},
) where {
    St <: PSY.Storage,
    D <: AbstractStorageFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(St, sys)
    # Constraints
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    energy_capacity_constraints!(container, devices, model, S)
    add_feedforward_constraints!(container, model, devices)

    # Energy Balanace limits
    add_constraints!(container, EnergyBalanceConstraint, devices, model, S)

    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{St, EnergyTarget},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    # Variables
    add_variables!(container, ActivePowerInVariable, devices, EnergyTarget())
    add_variables!(container, ActivePowerOutVariable, devices, EnergyTarget())
    add_variables!(container, ReactivePowerVariable, devices, EnergyTarget())
    add_variables!(container, EnergyVariable, devices, EnergyTarget())
    add_variables!(container, EnergyShortageVariable, devices, EnergyTarget())
    add_variables!(container, EnergySurplusVariable, devices, EnergyTarget())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, EnergyTarget())
    end

    # Parameters
    add_parameters!(container, EnergyTargetTimeSeriesParameter(), devices, model)

    # Initial Conditions
    initial_conditions!(container, devices, EnergyTarget())

    #Cost Expression
    add_expressions!(container, ProductionCostExpression, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerVariable,
        devices,
        model,
        S,
    )
    add_feedforward_arguments!(container, model, devices)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{St, EnergyTarget},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    # Constraints
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
    )
    energy_capacity_constraints!(container, devices, model, S)
    add_feedforward_constraints!(container, model, devices)

    # Energy Balanace limits
    add_constraints!(container, EnergyBalanceConstraint, devices, model, S)
    add_constraints!(container, EnergyTargetConstraint, devices, model, S)

    # Cost Function
    cost_function!(container, devices, model, S)
    add_constraint_dual!(container, sys, model)

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{St, EnergyTarget},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(St, sys)

    # Variables
    add_variables!(container, ActivePowerInVariable, devices, EnergyTarget())
    add_variables!(container, ActivePowerOutVariable, devices, EnergyTarget())
    add_variables!(container, EnergyVariable, devices, EnergyTarget())
    add_variables!(container, EnergyShortageVariable, devices, EnergyTarget())
    add_variables!(container, EnergySurplusVariable, devices, EnergyTarget())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, EnergyTarget())
    end

    # Parameters
    add_parameters!(container, EnergyTargetTimeSeriesParameter(), devices, model)

    # Initial Conditions
    initial_conditions!(container, devices, EnergyTarget())

    #Cost Expression
    add_expressions!(container, ProductionCostExpression, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )
    add_feedforward_arguments!(container, model, devices)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{St, EnergyTarget},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(St, sys)

    # Constraints
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    energy_capacity_constraints!(container, devices, model, S)
    add_feedforward_constraints!(container, model, devices)

    # Energy Balanace limits
    add_constraints!(container, EnergyBalanceConstraint, devices, model, S)
    add_constraints!(container, EnergyTargetConstraint, devices, model, S)

    # Cost Function
    cost_function!(container, devices, model, S)

    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{St, BatteryAncillaryServices},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    # Variables
    add_variables!(container, ActivePowerInVariable, devices, BatteryAncillaryServices())
    add_variables!(container, ActivePowerOutVariable, devices, BatteryAncillaryServices())
    add_variables!(container, ReactivePowerVariable, devices, BatteryAncillaryServices())
    add_variables!(container, EnergyVariable, devices, BatteryAncillaryServices())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, BatteryAncillaryServices())
    end
    # Initial Conditions
    initial_conditions!(container, devices, BatteryAncillaryServices())

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerVariable,
        devices,
        model,
        S,
    )
    if has_service_model(model)
        add_expressions!(container, ReserveRangeExpressionLB, devices, model)
        add_expressions!(container, ReserveRangeExpressionUB, devices, model)
    end
    add_feedforward_arguments!(container, model, devices)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{St, BatteryAncillaryServices},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    # Constraints
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
    )
    energy_capacity_constraints!(container, devices, model, S)
    add_feedforward_constraints!(container, model, devices)

    # Energy Balanace limits
    add_constraints!(container, EnergyBalanceConstraint, devices, model, S)
    if has_service_model(model)
        add_constraints!(container, ReserveEnergyConstraint, devices, model, S)
        add_constraints!(container, RangeLimitConstraint, devices, model, S)
    end
    add_constraint_dual!(container, sys, model)

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{St, BatteryAncillaryServices},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(St, sys)

    # Variables
    add_variables!(container, ActivePowerInVariable, devices, BatteryAncillaryServices())
    add_variables!(container, ActivePowerOutVariable, devices, BatteryAncillaryServices())
    add_variables!(container, EnergyVariable, devices, BatteryAncillaryServices())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, BatteryAncillaryServices())
    end
    # Initial Conditions
    initial_conditions!(container, devices, BatteryAncillaryServices())

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )
    if has_service_model(model)
        add_expressions!(container, ReserveRangeExpressionLB, devices, model)
        add_expressions!(container, ReserveRangeExpressionUB, devices, model)
    end
    add_feedforward_arguments!(container, model, devices)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{St, BatteryAncillaryServices},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(St, sys)

    # Constraints
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    energy_capacity_constraints!(container, devices, model, S)
    add_feedforward_constraints!(container, model, devices)

    # Energy Balanace limits
    add_constraints!(container, EnergyBalanceConstraint, devices, model, S)
    if has_service_model(model)
        add_constraints!(container, ReserveEnergyConstraint, devices, model, S)
        add_constraints!(container, RangeLimitConstraint, devices, model, S)
    end
    add_constraint_dual!(container, sys, model)

    return
end
