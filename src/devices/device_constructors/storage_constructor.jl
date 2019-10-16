function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{St, D},
                           ::Type{S};
                           kwargs...) where {St<:PSY.Storage,
                                             D<:AbstractStorageFormulation,
                                             S<:PM.AbstractPowerModel}

    sys = get_system(op_model)

    devices = PSY.get_components(St, sys)

    if validate_available_devices(devices, St)
        return
    end

    parameters = get(kwargs, :parameters, true)

    #Variables
    active_power_variables(canonical, devices)

    reactive_power_variables(canonical, devices)

    energy_storage_variables(canonical, devices)

    #Initial Conditions

    initial_conditions!(canonical, devices, D)

    #Constraints
    active_power_constraints(canonical, devices, D, S)

    reactive_power_constraints(canonical, devices, D, S)

    energy_capacity_constraints(canonical, devices, D, S)

    feedforward!(canonical, St, model.feedforward)

    # Energy Balanace limits
    energy_balance_constraint(canonical, devices, D, S)

    return

end

function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{St, D},
                           ::Type{S};
                           kwargs...) where {St<:PSY.Storage,
                                             D<:AbstractStorageFormulation,
                                             S<:PM.AbstractActivePowerModel}

    sys = get_system(op_model)

    devices = PSY.get_components(St, sys)

    if validate_available_devices(devices, St)
        return
    end

    parameters = get(kwargs, :parameters, true)


    #Variables
    active_power_variables(canonical, devices);

    energy_storage_variables(canonical, devices);

    #Initial Conditions

    initial_conditions!(canonical, devices, D)

    #Constraints
    active_power_constraints(canonical, devices, D, S)

    energy_capacity_constraints(canonical, devices, D, S)

    feedforward!(canonical, St, model.feedforward)

    # Energy Balanace limits
    energy_balance_constraint(canonical, devices, D, S)

    return

end

function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                                        model::DeviceModel{St, BookKeepingwReservation},
                                        ::Type{S};
                                        kwargs...) where {St<:PSY.Storage,
                                                          S<:PM.AbstractPowerModel}

    sys = get_system(op_model)

    devices = PSY.get_components(St, sys)

    if validate_available_devices(devices, St)
        return
    end

    parameters = get(kwargs, :parameters, true)

    #Variables
    active_power_variables(canonical, devices)

    reactive_power_variables(canonical, devices)

    energy_storage_variables(canonical, devices)

    storage_reservation_variables(canonical, devices)

    #Initial Conditions

    initial_conditions!(canonical, devices, model.formulation)

    #Constraints
    active_power_constraints(canonical, devices, model.formulation, S)

    reactive_power_constraints(canonical, devices, model.formulation, S)

    energy_capacity_constraints(canonical, devices, model.formulation, S)

    feedforward!(canonical, St, model.feedforward)

    # Energy Balanace limits
    energy_balance_constraint(canonical, devices, model.formulation, S)

    return

end

function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{St, BookKeepingwReservation},
                           ::Type{S};
                           kwargs...) where {St<:PSY.Storage,
                                             S<:PM.AbstractActivePowerModel}

    sys = get_system(op_model)

    devices = PSY.get_components(St, sys)

    if validate_available_devices(devices, St)
        return
    end

    parameters = get(kwargs, :parameters, true)


    #Variables
    active_power_variables(canonical, devices)

    energy_storage_variables(canonical, devices)

    storage_reservation_variables(canonical, devices)

    #Initial Conditions

    initial_conditions!(canonical, devices, model.formulation)

    #Constraints
    active_power_constraints(canonical, devices, model.formulation, S)

    energy_capacity_constraints(canonical, devices, model.formulation, S)

    feedforward!(canonical, St, model.feedforward)

    # Energy Balanace limits
    energy_balance_constraint(canonical, devices, model.formulation, S)

    return

end
