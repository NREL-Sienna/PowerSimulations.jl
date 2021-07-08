"""
Construct model for HydroGen with FixedOutput Formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::DeviceModel{H, FixedOutput},
    ::Type{S},
) where {H <: PSY.HydroGen, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    nodal_expression!(
        container,
        devices,
        ActivePowerTimeSeriesParameter("max_active_power"),
    )
    nodal_expression!(
        container,
        devices,
        ReactivePowerTimeSeriesParameter("max_active_power"),
    )

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::DeviceModel{H, FixedOutput},
    ::Type{S},
) where {H <: PSY.HydroGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    nodal_expression!(
        container,
        devices,
        ActivePowerTimeSeriesParameter("max_active_power"),
    )

    return
end

"""
Construct model for HydroGen with RunOfRiver Dispatch Formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, D},
    ::Type{S},
) where {
    H <: PSY.HydroGen,
    D <: AbstractHydroDispatchFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with RunOfRiver Dispatch Formulation
with only Active Power.
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, D},
    ::Type{S},
) where {
    H <: PSY.HydroGen,
    D <: AbstractHydroDispatchFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirBudget Dispatch Formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirBudget},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerVariable, devices, HydroDispatchReservoirBudget())
    add_variables!(
        container,
        ReactivePowerVariable,
        devices,
        HydroDispatchReservoirBudget(),
    )

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Energy Budget Constraint
    energy_budget_constraints!(container, devices, model, S, get_feedforward(model))

    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirBudget Dispatch Formulation
with only Active Power.
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirBudget},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerVariable, devices, HydroDispatchReservoirBudget())

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Energy Budget Constraint
    energy_budget_constraints!(container, devices, model, S, get_feedforward(model))

    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirStorage Dispatch Formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirStorage},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerVariable, devices, HydroDispatchReservoirStorage())
    add_variables!(
        container,
        ReactivePowerVariable,
        devices,
        HydroDispatchReservoirStorage(),
    )
    add_variables!(container, EnergyVariable, devices, HydroDispatchReservoirStorage())
    add_variables!(
        container,
        WaterSpillageVariable,
        devices,
        HydroDispatchReservoirStorage(),
    )
    add_variables!(
        container,
        EnergyShortageVariable,
        devices,
        HydroDispatchReservoirStorage(),
    )
    add_variables!(
        container,
        EnergySurplusVariable,
        devices,
        HydroDispatchReservoirStorage(),
    )

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Initial Conditions
    add_initial_condition!(
        container,
        devices,
        HydroDispatchReservoirStorage(),
        InitialEnergyLevel,
        EnergyVariable,
    )
    # Energy Balance Constraint
    add_constraints!(
        container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_target_constraint!(container, devices, model, S, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirStorage Dispatch Formulation
with only Active Power
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirStorage},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables

    add_variables!(container, ActivePowerVariable, devices, HydroDispatchReservoirStorage())
    add_variables!(container, EnergyVariable, devices, HydroDispatchReservoirStorage())
    add_variables!(
        container,
        WaterSpillageVariable,
        devices,
        HydroDispatchReservoirStorage(),
    )
    add_variables!(
        container,
        EnergyShortageVariable,
        devices,
        HydroDispatchReservoirStorage(),
    )
    add_variables!(
        container,
        EnergySurplusVariable,
        devices,
        HydroDispatchReservoirStorage(),
    )
    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Initial Conditions
    add_initial_condition!(
        container,
        devices,
        HydroDispatchReservoirStorage(),
        InitialEnergyLevel,
        EnergyVariable,
    )
    # Energy Balance Constraint
    add_constraints!(
        container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_target_constraint!(container, devices, model, S, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with RunOfRiver Commitment Formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, D},
    ::Type{S},
) where {H <: PSY.HydroGen, D <: HydroCommitmentRunOfRiver, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())
    add_variables!(container, OnVariable, devices, D())

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commit_hydro_active_power_ub!(container, devices, model, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with RunOfRiver Commitment Formulation
with only Active Power.
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, D},
    ::Type{S},
) where {
    H <: PSY.HydroGen,
    D <: HydroCommitmentRunOfRiver,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, OnVariable, devices, D())

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commit_hydro_active_power_ub!(container, devices, model, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirBudget Commitment Formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, D},
    ::Type{S},
) where {H <: PSY.HydroGen, D <: HydroCommitmentReservoirBudget, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())
    add_variables!(container, OnVariable, devices, D())

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    # Energy Budget Constraint
    energy_budget_constraints!(container, devices, model, S, get_feedforward(model))

    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirBudget Commitment Formulation
with only Active Power.
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, D},
    ::Type{S},
) where {
    H <: PSY.HydroGen,
    D <: HydroCommitmentReservoirBudget,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, OnVariable, devices, D())

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    # Energy Budget Constraint
    energy_budget_constraints!(container, devices, model, S, get_feedforward(model))

    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirStorage Commitment Formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroCommitmentReservoirStorage},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(
        container,
        ActivePowerVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(
        container,
        ReactivePowerVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(container, OnVariable, devices, HydroCommitmentReservoirStorage())
    add_variables!(container, EnergyVariable, devices, HydroCommitmentReservoirStorage())
    add_variables!(
        container,
        WaterSpillageVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(
        container,
        EnergyShortageVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(
        container,
        EnergySurplusVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Initial Conditions
    add_initial_condition!(
        container,
        devices,
        HydroCommitmentReservoirStorage(),
        InitialEnergyLevel,
        EnergyVariable,
    )
    # Energy Balance Constraint
    add_constraints!(
        container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_target_constraint!(container, devices, model, S, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirStorage Dispatch Formulation
with only Active Power
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroCommitmentReservoirStorage},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(
        container,
        ActivePowerVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(container, OnVariable, devices, HydroCommitmentReservoirStorage())
    add_variables!(container, EnergyVariable, devices, HydroCommitmentReservoirStorage())
    add_variables!(
        container,
        WaterSpillageVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(
        container,
        EnergyShortageVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(
        container,
        EnergySurplusVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Initial Conditions
    add_initial_condition!(
        container,
        devices,
        HydroCommitmentReservoirStorage(),
        InitialEnergyLevel,
        EnergyVariable,
    )

    # Energy Balance Constraint
    add_constraints!(
        container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_target_constraint!(container, devices, model, S, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroPumpedStorage with PumpedStorage Dispatch Formulation
with only Active Power
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchPumpedStorage},
    ::Type{S},
) where {H <: PSY.HydroPumpedStorage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerInVariable, devices, HydroDispatchPumpedStorage())
    add_variables!(container, ActivePowerOutVariable, devices, HydroDispatchPumpedStorage())
    add_variables!(container, EnergyVariableUp, devices, HydroDispatchPumpedStorage())
    add_variables!(container, EnergyVariableDown, devices, HydroDispatchPumpedStorage())
    add_variables!(container, WaterSpillageVariable, devices, HydroDispatchPumpedStorage())

    # Constraints
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Initial Conditions
    add_initial_condition!(
        container,
        devices,
        HydroDispatchPumpedStorage(),
        InitialEnergyLevelUp,
        EnergyVariableUp,
    )
    add_initial_condition!(
        container,
        devices,
        HydroDispatchPumpedStorage(),
        InitialEnergyLevelDown,
        EnergyVariableDown,
    )

    # Energy Balanace limits
    add_constraints!(
        container,
        EnergyBalanceConstraint,
        EnergyVariableUp,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        EnergyBalanceConstraint,
        EnergyVariableDown,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroPumpedStorage with PumpedStorage Dispatch Formulation with
reservation constraint with only Active Power
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchPumpedStoragewReservation},
    ::Type{S},
) where {H <: PSY.HydroPumpedStorage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(
        container,
        ActivePowerInVariable,
        devices,
        HydroDispatchPumpedStoragewReservation(),
    )
    add_variables!(
        container,
        ActivePowerOutVariable,
        devices,
        HydroDispatchPumpedStoragewReservation(),
    )
    add_variables!(
        container,
        EnergyVariableUp,
        devices,
        HydroDispatchPumpedStoragewReservation(),
    )
    add_variables!(
        container,
        EnergyVariableDown,
        devices,
        HydroDispatchPumpedStoragewReservation(),
    )
    add_variables!(
        container,
        WaterSpillageVariable,
        devices,
        HydroDispatchPumpedStoragewReservation(),
    )
    add_variables!(
        container,
        ReservationVariable,
        devices,
        HydroDispatchPumpedStoragewReservation(),
    )

    # Constraints
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Initial Conditions
    add_initial_condition!(
        container,
        devices,
        HydroDispatchPumpedStoragewReservation(),
        InitialEnergyLevelUp,
        EnergyVariableUp,
    )
    add_initial_condition!(
        container,
        devices,
        HydroDispatchPumpedStoragewReservation(),
        InitialEnergyLevelDown,
        EnergyVariableDown,
    )
    # Energy Balanace limits
    add_constraints!(
        container,
        EnergyBalanceConstraint,
        EnergyVariableUp,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        EnergyBalanceConstraint,
        EnergyVariableDown,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, nothing)

    return
end
