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

    #Variables
    add_variables!(ActivePowerVariable, psi_container, devices)
    add_variables!(ReactivePowerVariable, psi_container, devices)

    #Constraints
    add_constraints!(
        RangeConstraint,
        ActivePowerVariable,
        psi_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        RangeConstraint,
        ReactivePowerVariable,
        psi_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S)

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

    #Variables
    add_variables!(ActivePowerVariable, psi_container, devices)

    #Constraints
    add_constraints!(
        RangeConstraint,
        ActivePowerVariable,
        psi_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S)

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

    #Variables
    add_variables!(ActivePowerVariable, psi_container, devices)
    add_variables!(ReactivePowerVariable, psi_container, devices)

    #Energy Budget Constraint
    if model_uses_forecasts(psi_container)
        energy_budget_constraints!(psi_container, devices, model, S, get_feedforward(model))
    else
        @warn "No Forecasts: Ignoring energy constraints"
    end

    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, HydroDispatchReservoirBudget, S)

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

    #Variables
    add_variables!(ActivePowerVariable, psi_container, devices)

    #Energy Budget Constraint
    if model_uses_forecasts(psi_container)
        energy_budget_constraints!(psi_container, devices, model, S, get_feedforward(model))
    else
        @warn "No Forecasts: Ignoring energy constraints"
    end

    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, HydroDispatchReservoirBudget, S)

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

    #Variables
    add_variables!(ActivePowerVariable, psi_container, devices)
    add_variables!(ReactivePowerVariable, psi_container, devices)
    add_variables!(EnergyVariable, psi_container, devices)
    add_variables!(SpillageVariable, psi_container, devices)

    #Initial Conditions
    storage_energy_init(psi_container, devices)

    #Constraints
    add_constraints!(
        RangeConstraint,
        ActivePowerVariable,
        psi_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_balance_constraint!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, HydroDispatchReservoirStorage, S)

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

    #Variables
    add_variables!(ActivePowerVariable, psi_container, devices)
    add_variables!(EnergyVariable, psi_container, devices)
    add_variables!(SpillageVariable, psi_container, devices)

    #Initial Conditions
    storage_energy_init(psi_container, devices)

    energy_balance_constraint!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, HydroDispatchReservoirStorage, S)

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

    #Variables
    add_variables!(ActivePowerVariable, psi_container, devices)
    add_variables!(ReactivePowerVariable, psi_container, devices)
    add_variables!(OnVariable, psi_container, devices)

    #Constraints
    add_constraints!(
        RangeConstraint,
        ActivePowerVariable,
        psi_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    #Constraints
    add_constraints!(
        RangeConstraint,
        ReactivePowerVariable,
        psi_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commit_hydro_active_power_ub!(psi_container, devices, model, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S)

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

    #Variables
    add_variables!(ActivePowerVariable, psi_container, devices)
    add_variables!(OnVariable, psi_container, devices)

    #Constraints
    add_constraints!(
        RangeConstraint,
        ActivePowerVariable,
        psi_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commit_hydro_active_power_ub!(psi_container, devices, model, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S)

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

    #Variables
    add_variables!(ActivePowerVariable, psi_container, devices)
    add_variables!(ReactivePowerVariable, psi_container, devices)
    add_variables!(OnVariable, psi_container, devices)

    #Constraints
    add_constraints!(
        RangeConstraint,
        ActivePowerVariable,
        psi_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        RangeConstraint,
        ReactivePowerVariable,
        psi_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    #Energy Budget Constraint
    if model_uses_forecasts(psi_container)
        energy_budget_constraints!(psi_container, devices, model, S, get_feedforward(model))
    else
        @warn "No Forecasts: Ignoring energy constraints"
    end
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S)

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

    #Variables
    add_variables!(ActivePowerVariable, psi_container, devices)
    add_variables!(OnVariable, psi_container, devices)

    #Constraints
    add_constraints!(
        RangeConstraint,
        ActivePowerVariable,
        psi_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    #Energy Budget Constraint
    if model_uses_forecasts(psi_container)
        energy_budget_constraints!(psi_container, devices, model, S, get_feedforward(model))
    else
        @warn "No Forecasts: Ignoring energy constraints"
    end
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end

#=
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H,D},
    ::Type{S};

) where {H<:PSY.HydroGen,D<:AbstractHydroUnitCommitment,S<:PM.AbstractActivePowerModel}

    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    #Variables
    active_power_variables!(psi_container, devices)
    commitment_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    active_power_constraints!(psi_container, devices, model, S,get_feedforward(model))
    commitment_constraints!(psi_container, devices, model, S,get_feedforward(model))
    feedforward!(psi_container, H,get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end
=#

# Currently no Hydro device supports a Unit commiment formulation
#=
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.HydroDispatch, D},
    ::Type{S};

) where {D <: AbstractHydroUnitCommitment, S <: PM.AbstractPowerModel}
    @warn("The Formulation $(D) only applies to Dispatchable Hydro, *
               Consider Changing the Device Formulation to FixedOutput")

    construct_device!(
        psi_container,
        DeviceModel(PSY.HydroDispatch, FixedOutput),
        S

    )
end
=#
