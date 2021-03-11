"""
Construct model for HydroGen with FixedOutput Formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, FixedOutput},
    ::Type{S},
) where {H <: PSY.HydroGen, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    nodal_expression!(optimization_container, devices, S)

    return
end

"""
Construct model for HydroGen with RunOfRiver Dispatch Formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
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
    add_variables!(optimization_container, ActivePowerVariable, devices, D())
    add_variables!(optimization_container, ReactivePowerVariable, devices, D())

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with RunOfRiver Dispatch Formulation
with only Active Power.
"""
function construct_device!(
    optimization_container::OptimizationContainer,
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
    add_variables!(optimization_container, ActivePowerVariable, devices, D())

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirBudget Dispatch Formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirBudget},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(
        optimization_container,
        ActivePowerVariable,
        devices,
        HydroDispatchReservoirBudget(),
    )
    add_variables!(
        optimization_container,
        ReactivePowerVariable,
        devices,
        HydroDispatchReservoirBudget(),
    )

    # Energy Budget Constraint
    energy_budget_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirBudget Dispatch Formulation
with only Active Power.
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirBudget},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(
        optimization_container,
        ActivePowerVariable,
        devices,
        HydroDispatchReservoirBudget(),
    )

    # Energy Budget Constraint
    energy_budget_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirStorage Dispatch Formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirStorage},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(
        optimization_container,
        ActivePowerVariable,
        devices,
        HydroDispatchReservoirStorage(),
    )
    add_variables!(
        optimization_container,
        ReactivePowerVariable,
        devices,
        HydroDispatchReservoirStorage(),
    )
    add_variables!(
        optimization_container,
        EnergyVariable,
        devices,
        HydroDispatchReservoirStorage(),
    )
    add_variables!(
        optimization_container,
        SpillageVariable,
        devices,
        HydroDispatchReservoirStorage(),
    )
    add_variables!(optimization_container, EnergyShortageVariable, devices, HydroDispatchReservoirStorage())
    add_variables!(optimization_container, EnergySurplusVariable, devices, HydroDispatchReservoirStorage())

    # Initial Conditions
    storage_energy_initial_condition!(
        optimization_container,
        devices,
        HydroDispatchPumpedStorage(),
    )
    # Energy Balance Constraint
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_target_constraint!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirStorage Dispatch Formulation
with only Active Power
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirStorage},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(
        optimization_container,
        ActivePowerVariable,
        devices,
        HydroDispatchReservoirStorage(),
    )
    add_variables!(
        optimization_container,
        EnergyVariable,
        devices,
        HydroDispatchReservoirStorage(),
    )
    add_variables!(
        optimization_container,
        SpillageVariable,
        devices,
        HydroDispatchReservoirStorage(),
    )
    add_variables!(optimization_container, EnergyShortageVariable, devices, HydroDispatchReservoirStorage())
    add_variables!(optimization_container, EnergySurplusVariable, devices, HydroDispatchReservoirStorage())

    # Initial Conditions
    storage_energy_initial_condition!(
        optimization_container,
        devices,
        HydroDispatchPumpedStorage(),
    )
    # Energy Balance Constraint
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    energy_target_constraint!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with RunOfRiver Commitment Formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, D},
    ::Type{S},
) where {H <: PSY.HydroGen, D <: HydroCommitmentRunOfRiver, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices, D())
    add_variables!(optimization_container, ReactivePowerVariable, devices, D())
    add_variables!(optimization_container, OnVariable, devices, D())

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commit_hydro_active_power_ub!(
        optimization_container,
        devices,
        model,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with RunOfRiver Commitment Formulation
with only Active Power.
"""
function construct_device!(
    optimization_container::OptimizationContainer,
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
    add_variables!(optimization_container, ActivePowerVariable, devices, D())
    add_variables!(optimization_container, OnVariable, devices, D())

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commit_hydro_active_power_ub!(
        optimization_container,
        devices,
        model,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirBudget Commitment Formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, D},
    ::Type{S},
) where {H <: PSY.HydroGen, D <: HydroCommitmentReservoirBudget, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices, D())
    add_variables!(optimization_container, ReactivePowerVariable, devices, D())
    add_variables!(optimization_container, OnVariable, devices, D())

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    # Energy Budget Constraint
    energy_budget_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirBudget Commitment Formulation
with only Active Power.
"""
function construct_device!(
    optimization_container::OptimizationContainer,
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
    add_variables!(optimization_container, ActivePowerVariable, devices, D())
    add_variables!(optimization_container, OnVariable, devices, D())

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    # Energy Budget Constraint
    energy_budget_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirStorage Commitment Formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
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
        optimization_container,
        ActivePowerVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(
        optimization_container,
        ReactivePowerVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(
        optimization_container,
        OnVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(
        optimization_container,
        EnergyVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(
        optimization_container,
        SpillageVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(optimization_container, EnergyShortageVariable, devices, HydroCommitmentReservoirStorage())
    add_variables!(optimization_container, EnergySurplusVariable, devices, HydroCommitmentReservoirStorage())

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Initial Conditions
    storage_energy_initial_condition!(
        optimization_container,
        devices,
        HydroDispatchPumpedStorage(),
    )
    # Energy Balance Constraint
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_target_constraint!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirStorage Dispatch Formulation
with only Active Power
"""
function construct_device!(
    optimization_container::OptimizationContainer,
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
        optimization_container,
        ActivePowerVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(
        optimization_container,
        OnVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(
        optimization_container,
        EnergyVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(
        optimization_container,
        SpillageVariable,
        devices,
        HydroCommitmentReservoirStorage(),
    )
    add_variables!(optimization_container, EnergyShortageVariable, devices, HydroCommitmentReservoirStorage())
    add_variables!(optimization_container, EnergySurplusVariable, devices, HydroCommitmentReservoirStorage())

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Initial Conditions
    storage_energy_initial_condition!(
        optimization_container,
        devices,
        HydroDispatchPumpedStorage(),
    )
    # Energy Balance Constraint
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_target_constraint!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroPumpedStorage with PumpedStorage Dispatch Formulation
with only Active Power
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchPumpedStorage},
    ::Type{S},
) where {H <: PSY.HydroPumpedStorage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(
        optimization_container,
        ActivePowerInVariable,
        devices,
        HydroDispatchPumpedStorage(),
    )
    add_variables!(
        optimization_container,
        ActivePowerOutVariable,
        devices,
        HydroDispatchPumpedStorage(),
    )
    add_variables!(
        optimization_container,
        EnergyVariableUp,
        devices,
        HydroDispatchPumpedStorage(),
    )
    add_variables!(
        optimization_container,
        EnergyVariableDown,
        devices,
        HydroDispatchPumpedStorage(),
    )
    add_variables!(
        optimization_container,
        SpillageVariable,
        devices,
        HydroDispatchPumpedStorage(),
    )

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Initial Conditions
    storage_energy_initial_condition!(
        optimization_container,
        devices,
        HydroDispatchPumpedStorage(),
    )

    # Energy Balanace limits
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariableUp,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariableDown,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, HydroDispatchReservoirBudget, S)

    return
end

"""
Construct model for HydroPumpedStorage with PumpedStorage Dispatch Formulation with
reservation constraint with only Active Power
"""
function construct_device!(
    optimization_container::OptimizationContainer,
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
        optimization_container,
        ActivePowerInVariable,
        devices,
        HydroDispatchPumpedStoragewReservation(),
    )
    add_variables!(
        optimization_container,
        ActivePowerOutVariable,
        devices,
        HydroDispatchPumpedStoragewReservation(),
    )
    add_variables!(
        optimization_container,
        EnergyVariableUp,
        devices,
        HydroDispatchPumpedStoragewReservation(),
    )
    add_variables!(
        optimization_container,
        EnergyVariableDown,
        devices,
        HydroDispatchPumpedStoragewReservation(),
    )
    add_variables!(
        optimization_container,
        SpillageVariable,
        devices,
        HydroDispatchPumpedStoragewReservation(),
    )
    add_variables!(
        optimization_container,
        ReserveVariable,
        devices,
        HydroDispatchPumpedStoragewReservation(),
    )

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Initial Conditions
    storage_energy_initial_condition!(
        optimization_container,
        devices,
        HydroDispatchPumpedStorage(),
    )

    # Energy Balanace limits
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariableUp,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariableDown,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, HydroDispatchReservoirBudget, S)

    return
end
