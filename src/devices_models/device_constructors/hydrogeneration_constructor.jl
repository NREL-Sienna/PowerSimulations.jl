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
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    reactivepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirFlow},
    ::Type{S},
) where {H <: PSY.HydroGen, S <: PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    #Variables
    add_variables!(ActivePowerVariable, psi_container, devices)
    add_variables!(ReactivePowerVariable, psi_container, devices)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    reactivepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    energy_limit_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, HydroDispatchReservoirStorage, S)

    return
end

#=
# All Hydro UC formulations are currently not supported
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H,D},
    ::Type{S};

) where {H<:PSY.HydroGen,D<:AbstractHydroUnitCommitment,S<:PM.AbstractPowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    reactivepower_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S,get_feedforward(model))
    reactivepower_constraints!(psi_container, devices, model, S,get_feedforward(model))
    commitment_constraints!(psi_container, devices, model, S,get_feedforward(model))
    feedforward!(psi_container, H,get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end
=#

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
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirFlow},
    ::Type{S},
) where {H <: PSY.HydroGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(H, sys)

    if !validate_available_devices(H, devices)
        return
    end

    #Variables
    add_variables!(ActivePowerVariable, psi_container, devices)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    energy_limit_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, HydroDispatchReservoirFlow, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirStorage},
    ::Type{S},
) where {H <: PSY.HydroGen, S <: PM.AbstractActivePowerModel}
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

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    energy_balance_constraint!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, HydroDispatchReservoirStorage, S)

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
    activepower_variables!(psi_container, devices)
    commitment_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S,get_feedforward(model))
    commitment_constraints!(psi_container, devices, model, S,get_feedforward(model))
    feedforward!(psi_container, H,get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end
=#

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

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.HydroDispatch, FixedOutput},
    ::Type{S},
) where {S <: PM.AbstractPowerModel}
    devices = get_available_components(PSY.HydroDispatch, sys)

    if !validate_available_devices(PSY.HydroDispatch, devices)
        return
    end

    nodal_expression!(psi_container, devices, S)

    return
end
