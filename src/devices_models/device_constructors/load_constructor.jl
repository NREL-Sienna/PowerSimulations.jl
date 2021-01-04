function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{L, D},
    ::Type{S},
) where {
    L <: PSY.ControllableLoad,
    D <: AbstractControllablePowerLoadFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(L, sys)

    if !validate_available_devices(L, devices)
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
    cost_function!(psi_container, devices, model, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{L, D},
    ::Type{S},
) where {
    L <: PSY.ControllableLoad,
    D <: AbstractControllablePowerLoadFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(L, sys)

    if !validate_available_devices(L, devices)
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
    cost_function!(psi_container, devices, model, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{L, InterruptiblePowerLoad},
    ::Type{S},
) where {L <: PSY.ControllableLoad, S <: PM.AbstractPowerModel}
    devices = get_available_components(L, sys)

    if !validate_available_devices(L, devices)
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
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{L, InterruptiblePowerLoad},
    ::Type{S},
) where {L <: PSY.ControllableLoad, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(L, sys)

    if !validate_available_devices(L, devices)
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
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{L, StaticPowerLoad},
    ::Type{S},
) where {L <: PSY.ElectricLoad, S <: PM.AbstractPowerModel}
    devices = get_available_components(L, sys)

    if !validate_available_devices(L, devices)
        return
    end

    nodal_expression!(psi_container, devices, S)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{L, D},
    ::Type{S},
) where {
    L <: PSY.StaticLoad,
    D <: AbstractControllablePowerLoadFormulation,
    S <: PM.AbstractPowerModel,
}
    if D != StaticPowerLoad
        @warn("The Formulation $(D) only applies to FormulationControllable Loads, \n Consider Changing the Device Formulation to StaticPowerLoad")
    end

    construct_device!(psi_container, sys, DeviceModel(L, StaticPowerLoad), S)
    return
end
