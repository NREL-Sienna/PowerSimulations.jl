"""
Construct model for HydroGen with FixedOutput Formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, FixedOutput},
    ::Type{S},
) where {H <: PSY.HydroGen, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    nodal_expression!(psi_container, devices, S)

    return
end

"""
Construct model for HydroGen with RunOfRiver Dispatch Formulation
"""
function construct_device!(
    psi_container::PSIContainer,
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
    add_variables!(psi_container, ActivePowerVariable, devices)
    add_variables!(psi_container, ReactivePowerVariable, devices)

    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with RunOfRiver Dispatch Formulation
with only Active Power.
"""
function construct_device!(
    psi_container::PSIContainer,
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
    add_variables!(psi_container, ActivePowerVariable, devices)

    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirBudget Dispatch Formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirBudget},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerVariable, devices)
    add_variables!(psi_container, ReactivePowerVariable, devices)

    # Energy Budget Constraint
    energy_budget_constraints!(psi_container, devices, model, S, get_feedforward(model))

    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirBudget Dispatch Formulation
with only Active Power.
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirBudget},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerVariable, devices)

    # Energy Budget Constraint
    energy_budget_constraints!(psi_container, devices, model, S, get_feedforward(model))

    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirStorage Dispatch Formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirStorage},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerVariable, devices)
    add_variables!(psi_container, ReactivePowerVariable, devices)
    add_variables!(psi_container, EnergyVariable, devices)
    add_variables!(psi_container, SpillageVariable, devices)

    # Initial Conditions
    storage_energy_init(psi_container, devices)
    # Energy Balance Constraint
    energy_balance_constraint!(psi_container, devices, model, S, get_feedforward(model))

    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirStorage Dispatch Formulation
with only Active Power
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirStorage},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerVariable, devices)
    add_variables!(psi_container, EnergyVariable, devices)
    add_variables!(psi_container, SpillageVariable, devices)

    # Initial Conditions
    storage_energy_init(psi_container, devices)
    # Energy Balance Constraint
    energy_balance_constraint!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with RunOfRiver Commitment Formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, D},
    ::Type{S},
) where {H <: PSY.HydroGen, D <: HydroCommitmentRunOfRiver, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerVariable, devices)
    add_variables!(psi_container, ReactivePowerVariable, devices)
    add_variables!(psi_container, OnVariable, devices)

    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commit_hydro_active_power_ub!(psi_container, devices, model, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with RunOfRiver Commitment Formulation
with only Active Power.
"""
function construct_device!(
    psi_container::PSIContainer,
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
    add_variables!(psi_container, ActivePowerVariable, devices)
    add_variables!(psi_container, OnVariable, devices)

    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commit_hydro_active_power_ub!(psi_container, devices, model, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirBudget Commitment Formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, D},
    ::Type{S},
) where {H <: PSY.HydroGen, D <: HydroCommitmentReservoirBudget, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerVariable, devices)
    add_variables!(psi_container, ReactivePowerVariable, devices)
    add_variables!(psi_container, OnVariable, devices)

    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    # Energy Budget Constraint
    energy_budget_constraints!(psi_container, devices, model, S, get_feedforward(model))

    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirBudget Commitment Formulation
with only Active Power.
"""
function construct_device!(
    psi_container::PSIContainer,
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
    add_variables!(psi_container, ActivePowerVariable, devices)
    add_variables!(psi_container, OnVariable, devices)

    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    # Energy Budget Constraint
    energy_budget_constraints!(psi_container, devices, model, S, get_feedforward(model))

    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirStorage Commitment Formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroCommitmentReservoirStorage},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerVariable, devices)
    add_variables!(psi_container, ReactivePowerVariable, devices)
    add_variables!(psi_container, OnVariable, devices)
    add_variables!(psi_container, EnergyVariable, devices)
    add_variables!(psi_container, SpillageVariable, devices)

    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Initial Conditions
    storage_energy_init(psi_container, devices)
    # Energy Balance Constraint
    energy_balance_constraint!(psi_container, devices, model, S, get_feedforward(model))

    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroGen with ReservoirStorage Dispatch Formulation
with only Active Power
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroCommitmentReservoirStorage},
    ::Type{S},
) where {H <: PSY.HydroEnergyReservoir, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerVariable, devices)
    add_variables!(psi_container, OnVariable, devices)
    add_variables!(psi_container, EnergyVariable, devices)
    add_variables!(psi_container, SpillageVariable, devices)

    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Initial Conditions
    storage_energy_init(psi_container, devices)
    # Energy Balance Constraint
    energy_balance_constraint!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, nothing)

    return
end

"""
Construct model for HydroPumpedStorage with PumpedStorage Dispatch Formulation
with only Active Power
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchPumpedStorage},
    ::Type{S},
) where {H <: PSY.HydroPumpedStorage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerInVariable, devices)
    add_variables!(psi_container, ActivePowerOutVariable, devices)
    add_variables!(psi_container, EnergyVariableUp, devices)
    add_variables!(psi_container, EnergyVariableDown, devices)
    add_variables!(psi_container, SpillageVariable, devices)

    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Initial Conditions
    storage_energy_init(psi_container, devices)

    # Energy Balanace limits
    energy_balance_constraint!(psi_container, devices, model, S, get_feedforward(model))

    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function(psi_container, devices, HydroDispatchReservoirBudget, S)

    return
end

"""
Construct model for HydroPumpedStorage with PumpedStorage Dispatch Formulation with
reservation constraint with only Active Power
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchPumpedStoragewReservation},
    ::Type{S},
) where {H <: PSY.HydroPumpedStorage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerInVariable, devices)
    add_variables!(psi_container, ActivePowerOutVariable, devices)
    add_variables!(psi_container, EnergyVariableUp, devices)
    add_variables!(psi_container, EnergyVariableDown, devices)
    add_variables!(psi_container, SpillageVariable, devices)
    add_variables!(psi_container, ReserveVariable, devices)

    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Initial Conditions
    storage_energy_init(psi_container, devices)

    # Energy Balanace limits
    energy_balance_constraint!(psi_container, devices, model, S, get_feedforward(model))

    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function(psi_container, devices, HydroDispatchReservoirBudget, S)

    return
end
