function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{St, D},
    ::Type{S},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    #Variables
    add_variables!(ActivePowerInVariable, psi_container, devices)
    add_variables!(ActivePowerOutVariable, psi_container, devices)
    add_variables!(ReactivePowerVariable, psi_container, devices)
    add_variables!(EnergyVariable, psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, D)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    reactive_power_constraints!(psi_container, devices, model, S, get_feedforward(model))
    energy_capacity_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    energy_balance_constraint!(psi_container, devices, D, S, get_feedforward(model))

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{St, D},
    ::Type{S},
) where {
    St <: PSY.Storage,
    D <: AbstractStorageFormulation,
    S <: PM.AbstractActivePowerModel,
}

    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    #Variables
    add_variables!(ActivePowerInVariable, psi_container, devices)
    add_variables!(ActivePowerOutVariable, psi_container, devices)
    add_variables!(EnergyVariable, psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, D)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    energy_capacity_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    energy_balance_constraint!(psi_container, devices, D, S, get_feedforward(model))

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{St, BookKeepingwReservation},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    #Variables
    add_variables!(ActivePowerInVariable, psi_container, devices)
    add_variables!(ActivePowerOutVariable, psi_container, devices)
    add_variables!(ReactivePowerVariable, psi_container, devices)
    add_variables!(EnergyVariable, psi_container, devices)
    add_variables!(ReserveVariable, psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    reactive_power_constraints!(psi_container, devices, model, S, get_feedforward(model))
    energy_capacity_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    energy_balance_constraint!(
        psi_container,
        devices,
        model.formulation,
        S,
        get_feedforward(model),
    )

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{St, BookKeepingwReservation},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    #Variables
    add_variables!(ActivePowerInVariable, psi_container, devices)
    add_variables!(ActivePowerOutVariable, psi_container, devices)
    add_variables!(EnergyVariable, psi_container, devices)
    add_variables!(ReserveVariable, psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    energy_capacity_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    energy_balance_constraint!(
        psi_container,
        devices,
        model.formulation,
        S,
        get_feedforward(model),
    )

    return
end
