function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, D},
    ::Type{S};
    kwargs...,
) where {
    H <: PSY.HydroGen,
    D <: AbstractHydroDispatchFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    reactivepower_variables!(psi_container, devices)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    reactivepower_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, H, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirFlow},
    ::Type{S};
    kwargs...,
) where {H <: PSY.HydroGen, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    reactivepower_variables!(psi_container, devices)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    # since hydro generators don't currently have pf info, don't add any additional
    # reactive power constraints other than the variable bounds.
    # reactivepower_constraints!(psi_container, devices, model, S, model.feedforward)
    energy_limit_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, H, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, HydroDispatchReservoirFlow, S)

    return
end

#=
# All Hydro UC formulations are currently not supported
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H,D},
    ::Type{S};
    kwargs...,
) where {H<:PSY.HydroGen,D<:AbstractHydroUnitCommitment,S<:PM.AbstractPowerModel}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    reactivepower_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    reactivepower_constraints!(psi_container, devices, model, S, model.feedforward)
    commitment_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, H, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end
=#

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, D},
    ::Type{S};
    kwargs...,
) where {
    H <: PSY.HydroGen,
    D <: AbstractHydroDispatchFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, H, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirFlow},
    ::Type{S};
    kwargs...,
) where {H <: PSY.HydroGen, S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    energy_limit_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, H, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, HydroDispatchReservoirFlow, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroDispatchReservoirStorage},
    ::Type{S};
    kwargs...,
) where {H <: PSY.HydroGen, S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    energy_variables!(psi_container, devices)
    spillage_variables!(psi_container, devices)

    #Initial Conditions
    storage_energy_init(psi_container, devices)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    energy_balance_constraint!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, H, model.feedforward)

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
    kwargs...,
) where {H<:PSY.HydroGen,D<:AbstractHydroUnitCommitment,S<:PM.AbstractActivePowerModel}

    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    commitment_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    commitment_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, H, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end
=#

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{H, HydroFixed},
    ::Type{S};
    kwargs...,
) where {H <: PSY.HydroGen, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    nodal_expression!(psi_container, devices, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.HydroDispatch, D},
    ::Type{S};
    kwargs...,
) where {D <: AbstractHydroUnitCommitment, S <: PM.AbstractPowerModel}
    @warn("The Formulation $(D) only applies to Dispatchable Hydro, *
               Consider Changing the Device Formulation to HydroFixed")

    construct_device!(
        psi_container,
        DeviceModel(PSY.HydroDispatch, HydroFixed),
        S;
        kwargs...,
    )
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.HydroDispatch, HydroFixed},
    ::Type{S};
    kwargs...,
) where {S <: PM.AbstractPowerModel}
    devices = PSY.get_components(PSY.HydroDispatch, sys)

    if validate_available_devices(devices, PSY.HydroDispatch)
        return
    end

    nodal_expression!(psi_container, devices, S)

    return
end
