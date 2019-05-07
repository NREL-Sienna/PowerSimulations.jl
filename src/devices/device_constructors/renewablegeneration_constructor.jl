function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{R},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.ConcreteSystem,
                                        time_range::UnitRange{Int64};
                                        kwargs...) where {R <: PSY.RenewableGen,
                                                          D <: AbstractRenewableDispatchForm,
                                                          S <: PM.AbstractPowerFormulation}

    devices = collect(PSY.get_components(device, sys))
    
    if validate_available_devices(devices, device)
        return
    end

    parameters = get(kwargs, :parameters, true)

    #Variables
    activepower_variables(ps_m, devices, time_range);

    reactivepower_variables(ps_m, devices, time_range);

    #Constraints
    activepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range, parameters)

    reactivepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range)

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{R},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.ConcreteSystem,
                                        time_range::UnitRange{Int64};
                                        kwargs...) where {R <: PSY.RenewableGen,
                                                          D <: AbstractRenewableDispatchForm,
                                                          S <: PM.AbstractActivePowerFormulation}

    devices = collect(PSY.get_components(device, sys))
    
    if validate_available_devices(devices, device)
        return
    end

    parameters = get(kwargs, :parameters, true)                                             

    #Variables
    activepower_variables(ps_m, devices, time_range)

    #Constraints
    activepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range, parameters)

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{R},
                                        device_formulation::Type{PSI.RenewableFixed},
                                        system_formulation::Type{S},
                                        sys::PSY.ConcreteSystem,
                                        time_range::UnitRange{Int64};
                                        kwargs...) where {R <: PSY.RenewableGen,
                                                          S <: PM.AbstractPowerFormulation}

    devices = collect(PSY.get_components(device, sys))
    
    if validate_available_devices(devices, device)
        return
    end

    parameters = get(kwargs, :parameters, true)

    nodal_expression(ps_m, devices, system_formulation, time_range, parameters)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{PSY.RenewableFix},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.ConcreteSystem,
                                        time_range::UnitRange{Int64};
                                        kwargs...) where {D <: PSI.AbstractRenewableFormulation,
                                                          S <: PM.AbstractPowerFormulation}

    devices = collect(PSY.get_components(device, sys))
    
    if validate_available_devices(devices, device)
        return
    end

    parameters = get(kwargs, :parameters, true)

    if device_formulation != RenewableFixed
        @warn("The Formulation $(D) onky applied to Controllable Renewable Resources, \n Consider Changing the Device Formulation to RenewableFixed")                                              
    end

    _internal_device_constructor!(ps_m, 
                                    device,
                                    device_formulation,
                                    PSI.RenewableFixed,
                                    sys,
                                    time_range; kwargs...)

end                      