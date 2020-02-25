function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{L, D},
    ::Type{S};
    kwargs...,
) where {
    L <: PSY.ControllableLoad,
    D <: AbstractControllablePowerLoadFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    reactivepower_variables!(psi_container, devices)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    reactivepower_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, L, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return

end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{L, D},
    ::Type{S};
    kwargs...,
) where {
    L <: PSY.ControllableLoad,
    D <: AbstractControllablePowerLoadFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, L, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{L, InterruptiblePowerLoad},
    ::Type{S};
    kwargs...,
) where {L <: PSY.ControllableLoad, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    reactivepower_variables!(psi_container, devices)
    commitment_variables!(psi_container, devices)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    reactivepower_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, L, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{L, InterruptiblePowerLoad},
    ::Type{S};
    kwargs...,
) where {L <: PSY.ControllableLoad, S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    commitment_variables!(psi_container, devices)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, L, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{L, StaticPowerLoad},
    ::Type{S};
    kwargs...,
) where {L <: PSY.ElectricLoad, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    nodal_expression!(psi_container, devices, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{L, D},
    ::Type{S};
    kwargs...,
) where {
    L <: PSY.StaticLoad,
    D <: AbstractControllablePowerLoadFormulation,
    S <: PM.AbstractPowerModel,
}
    if D != StaticPowerLoad
        @warn("The Formulation $(D) only applies to FormulationControllable Loads, \n Consider Changing the Device Formulation to StaticPowerLoad")
    end

    construct_device!(psi_container, sys, DeviceModel(L, StaticPowerLoad), S; kwargs...)
    return
end
