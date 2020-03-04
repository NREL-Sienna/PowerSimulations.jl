function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{St, D},
    ::Type{S};
    kwargs...,
) where {St <: PSY.Storage, D <: AbstractStorageFormulation, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(St, sys)

    if validate_available_devices(devices, St)
        return
    end

    #Variables
    active_power_variables!(psi_container, devices)
    reactive_power_variables!(psi_container, devices)
    energy_storage_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, D)

    #Constraints
    active_power_constraints!(psi_container, devices, model, S,get_feedforward(model))
    reactive_power_constraints!(psi_container, devices, model, S,get_feedforward(model))
    energy_capacity_constraints!(psi_container, devices, model, S,get_feedforward(model))
    feedforward!(psi_container, St,get_feedforward(model))

    # Energy Balanace limits
    energy_balance_constraint!(psi_container, devices, D, S,get_feedforward(model))

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{St, D},
    ::Type{S};
    kwargs...,
) where {
    St <: PSY.Storage,
    D <: AbstractStorageFormulation,
    S <: PM.AbstractActivePowerModel,
}

    devices = PSY.get_components(St, sys)

    if validate_available_devices(devices, St)
        return
    end

    #Variables
    active_power_variables!(psi_container, devices)
    energy_storage_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, D)

    #Constraints
    active_power_constraints!(psi_container, devices, model, S,get_feedforward(model))
    energy_capacity_constraints!(psi_container, devices, model, S,get_feedforward(model))
    feedforward!(psi_container, St,get_feedforward(model))

    # Energy Balanace limits
    energy_balance_constraint!(psi_container, devices, D, S,get_feedforward(model))

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{St, BookKeepingwReservation},
    ::Type{S};
    kwargs...,
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(St, sys)

    if validate_available_devices(devices, St)
        return
    end

    #Variables
    active_power_variables!(psi_container, devices)
    reactive_power_variables!(psi_container, devices)
    energy_storage_variables!(psi_container, devices)
    storage_reservation_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    active_power_constraints!(psi_container, devices, model, S,get_feedforward(model))
    reactive_power_constraints!(psi_container, devices, model, S,get_feedforward(model))
    energy_capacity_constraints!(psi_container, devices, model, S,get_feedforward(model))
    feedforward!(psi_container, St,get_feedforward(model))

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
    ::Type{S};
    kwargs...,
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(St, sys)

    if validate_available_devices(devices, St)
        return
    end

    #Variables
    active_power_variables!(psi_container, devices)
    energy_storage_variables!(psi_container, devices)
    storage_reservation_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    active_power_constraints!(psi_container, devices, model, S,get_feedforward(model))
    energy_capacity_constraints!(psi_container, devices, model, S,get_feedforward(model))
    feedforward!(psi_container, St,get_feedforward(model))

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
