function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{St, D},
                           ::Type{S};
                           kwargs...) where {St<:PSY.Storage,
                                             D<:AbstractStorageFormulation,
                                             S<:PM.AbstractPowerModel}



    devices = PSY.get_components(St, sys)

    if validate_available_devices(devices, St)
        return
    end

    parameters = get(kwargs, :parameters, true)

    #Variables
    active_power_variables!(psi_container, devices)

    reactive_power_variables!(psi_container, devices)

    energy_storage_variables!(psi_container, devices)

    #Initial Conditions

    initial_conditions!(psi_container, devices, D)

    #Constraints
    active_power_constraints!(psi_container, devices, D, S)

    reactive_power_constraints!(psi_container, devices, D, S)

    energy_capacity_constraints!(psi_container, devices, D, S)

    feedforward!(psi_container, St, model.feedforward)

    # Energy Balanace limits
    energy_balance_constraint!(psi_container, devices, D, S)

    return

end

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{St, D},
                           ::Type{S};
                           kwargs...) where {St<:PSY.Storage,
                                             D<:AbstractStorageFormulation,
                                             S<:PM.AbstractActivePowerModel}



    devices = PSY.get_components(St, sys)

    if validate_available_devices(devices, St)
        return
    end

    parameters = get(kwargs, :parameters, true)


    #Variables
    active_power_variables!(psi_container, devices);

    energy_storage_variables!(psi_container, devices);

    #Initial Conditions

    initial_conditions!(psi_container, devices, D)

    #Constraints
    active_power_constraints!(psi_container, devices, D, S)

    energy_capacity_constraints!(psi_container, devices, D, S)

    feedforward!(psi_container, St, model.feedforward)

    # Energy Balanace limits
    energy_balance_constraint!(psi_container, devices, D, S)

    return

end

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                                        model::DeviceModel{St, BookKeepingwReservation},
                                        ::Type{S};
                                        kwargs...) where {St<:PSY.Storage,
                                                          S<:PM.AbstractPowerModel}



    devices = PSY.get_components(St, sys)

    if validate_available_devices(devices, St)
        return
    end

    parameters = get(kwargs, :parameters, true)

    #Variables
    active_power_variables!(psi_container, devices)

    reactive_power_variables!(psi_container, devices)

    energy_storage_variables!(psi_container, devices)

    storage_reservation_variables!(psi_container, devices)

    #Initial Conditions

    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    active_power_constraints!(psi_container, devices, model.formulation, S)

    reactive_power_constraints!(psi_container, devices, model.formulation, S)

    energy_capacity_constraints!(psi_container, devices, model.formulation, S)

    feedforward!(psi_container, St, model.feedforward)

    # Energy Balanace limits
    energy_balance_constraint!(psi_container, devices, model.formulation, S)

    return

end

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{St, BookKeepingwReservation},
                           ::Type{S};
                           kwargs...) where {St<:PSY.Storage,
                                             S<:PM.AbstractActivePowerModel}



    devices = PSY.get_components(St, sys)

    if validate_available_devices(devices, St)
        return
    end

    parameters = get(kwargs, :parameters, true)


    #Variables
    active_power_variables!(psi_container, devices)

    energy_storage_variables!(psi_container, devices)

    storage_reservation_variables!(psi_container, devices)

    #Initial Conditions

    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    active_power_constraints!(psi_container, devices, model.formulation, S)

    energy_capacity_constraints!(psi_container, devices, model.formulation, S)

    feedforward!(psi_container, St, model.feedforward)

    # Energy Balanace limits
    energy_balance_constraint!(psi_container, devices, model.formulation, S)

    return

end
