function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{R, D},
    ::Type{S};
    kwargs...,
) where {
    R <: PSY.RenewableGen,
    D <: AbstractRenewableDispatchFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = PSY.get_components(R, sys)

    if validate_available_devices(devices, R)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    reactivepower_variables!(psi_container, devices)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    reactivepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, R, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{R, D},
    ::Type{S};
    kwargs...,
) where {
    R <: PSY.RenewableGen,
    D <: AbstractRenewableDispatchFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = PSY.get_components(R, sys)

    if validate_available_devices(devices, R)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, R, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{R, RenewableFixed},
    system_formulation::Type{S};
    kwargs...,
) where {R <: PSY.RenewableGen, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(R, sys)

    if validate_available_devices(devices, R)
        return
    end

    nodal_expression!(psi_container, devices, system_formulation)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.RenewableFix, D},
    system_formulation::Type{S};
    kwargs...,
) where {D <: AbstractRenewableDispatchFormulation, S <: PM.AbstractPowerModel}
    @warn("The Formulation $(D) only applies to FormulationControllable Renewable Resources, \n Consider Changing the Device Formulation to RenewableFixed")

    construct_device!(
        psi_container,
        sys,
        DeviceModel(PSY.RenewableFix, RenewableFixed),
        system_formulation;
        kwargs...,
    )

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.RenewableFix, RenewableFixed},
    system_formulation::Type{S};
    kwargs...,
) where {S <: PM.AbstractPowerModel}
    devices = PSY.get_components(PSY.RenewableFix, sys)

    if validate_available_devices(devices, PSY.RenewableFix)
        return
    end

    nodal_expression!(psi_container, devices, system_formulation)

    return
end
