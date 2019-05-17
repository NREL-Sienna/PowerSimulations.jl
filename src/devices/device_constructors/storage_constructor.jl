function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{St},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.System,
                                        lookahead::UnitRange{Int64},
                                        resolution::Dates.Period;
                                        kwargs...) where {St <: PSY.Storage,
                                                            D <: AbstractStorageForm,
                                                            S <: PM.AbstractPowerFormulation}


    devices = PSY.get_components(device, sys)
    
    if validate_available_devices(devices, device)
        return
    end
                                                                
    parameters = get(kwargs, :parameters, true)

    #Variables
    active_power_variables(ps_m, devices, lookahead);

    reactive_power_variables(ps_m, devices, lookahead);

    energy_storage_variables(ps_m, devices, lookahead);

    #Constraints
    active_power_constraints(ps_m, devices, device_formulation, system_formulation, lookahead)

    reactive_power_constraints(ps_m, devices, device_formulation, system_formulation, lookahead)

    energy_capacity_constraints(ps_m, devices, device_formulation, system_formulation, lookahead)

    # Energy Balanace limits
    energy_balance_constraint(ps_m, devices, device_formulation, system_formulation, lookahead, resolution, parameters)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{St},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.System,
                                        lookahead::UnitRange{Int64},
                                        resolution::Dates.Period;
                                        kwargs...) where {St <: PSY.Storage,
                                                            D <: AbstractStorageForm,
                                                            S <: PM.AbstractActivePowerFormulation}

    devices = PSY.get_components(device, sys)
    
    if validate_available_devices(devices, device)
        return
    end
                                                                
    parameters = get(kwargs, :parameters, true)


    #Variables
    active_power_variables(ps_m, devices, lookahead);

    energy_storage_variables(ps_m, devices, lookahead);

    #Constraints
    active_power_constraints(ps_m, devices, device_formulation, system_formulation, lookahead)

    energy_capacity_constraints(ps_m, devices, device_formulation, system_formulation, lookahead)

    # Energy Balanace limits
    energy_balance_constraint(ps_m, devices, device_formulation, system_formulation, lookahead, resolution, parameters)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{St},
                                        device_formulation::Type{BookKeepingwReservation},
                                        system_formulation::Type{S},
                                        sys::PSY.System,
                                        lookahead::UnitRange{Int64},
                                        resolution::Dates.Period;
                                        kwargs...) where {St <: PSY.Storage,
                                                          S <: PM.AbstractPowerFormulation}


    devices = PSY.get_components(device, sys)
    
    if validate_available_devices(devices, device)
        return
    end
                                                                
    parameters = get(kwargs, :parameters, true)

    #Variables
    active_power_variables(ps_m, devices, lookahead);

    reactive_power_variables(ps_m, devices, lookahead);

    energy_storage_variables(ps_m, devices, lookahead);

    storage_reservation_variables(ps_m, devices, lookahead);

    #Constraints
    active_power_constraints(ps_m, devices, device_formulation, system_formulation, lookahead)

    reactive_power_constraints(ps_m, devices, device_formulation, system_formulation, lookahead)

    energy_capacity_constraints(ps_m, devices, device_formulation, system_formulation, lookahead)

    # Energy Balanace limits
    energy_balance_constraint(ps_m, devices, device_formulation, system_formulation, lookahead, resolution, parameters)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{St},
                                        device_formulation::Type{BookKeepingwReservation},
                                        system_formulation::Type{S},
                                        sys::PSY.System,
                                        lookahead::UnitRange{Int64},
                                        resolution::Dates.Period;
                                        kwargs...) where {St <: PSY.Storage,
                                                          S <: PM.AbstractActivePowerFormulation}

    devices = PSY.get_components(device, sys)
    
    if validate_available_devices(devices, device)
        return
    end
                                                                
    parameters = get(kwargs, :parameters, true)


    #Variables
    active_power_variables(ps_m, devices, lookahead);

    energy_storage_variables(ps_m, devices, lookahead);

    storage_reservation_variables(ps_m, devices, lookahead);

    #Constraints
    active_power_constraints(ps_m, devices, device_formulation, system_formulation, lookahead)

    energy_capacity_constraints(ps_m, devices, device_formulation, system_formulation, lookahead)

    # Energy Balanace limits
    energy_balance_constraint(ps_m, devices, device_formulation, system_formulation, lookahead, resolution, parameters)

    return

end
