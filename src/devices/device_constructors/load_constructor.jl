function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{L},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {L <: PSY.ControllableLoad,
                                                            D <: AbstractControllablePowerLoadForm,
                                                            S <: PM.AbstractPowerFormulation}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(device, sys)

    if validate_available_devices(devices, device)
        return
    end

    parameters = get(kwargs, :parameters, true)

    #Variables
    activepower_variables(ps_m, devices)

    reactivepower_variables(ps_m, devices)

    #Constraints
    if forecast
        first_step = PSY.get_forecasts_initial_time(sys)
        forecasts = collect(PSY.get_forecasts(PSY.Deterministic{L}, sys, PSY.get_forecasts_initial_time(sys)))
        activepower_constraints(ps_m, forecasts, device_formulation, system_formulation, parameters)
    else
        activepower_constraints(ps_m, devices, device_formulation, system_formulation, parameters)
    end

    reactivepower_constraints(ps_m, devices, device_formulation, system_formulation)

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{L},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {L <: PSY.ControllableLoad,
                                                            D <: AbstractControllablePowerLoadForm,
                                                            S <: PM.AbstractActivePowerFormulation}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(device, sys)

    if validate_available_devices(devices, device)
        return
    end

    parameters = get(kwargs, :parameters, true)

    #Variables
    activepower_variables(ps_m, devices)

    #Constraints
    if forecast
        first_step = PSY.get_forecasts_initial_time(sys)
        forecasts = Vector{PSY.Deterministic{L}}(PSY.get_forecasts(sys, first_step, devices))
        activepower_constraints(ps_m, forecasts, device_formulation, system_formulation, parameters)
    else
        activepower_constraints(ps_m, devices, device_formulation, system_formulation, parameters)
    end

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{L},
                                        device_formulation::Type{StaticPowerLoad},
                                        system_formulation::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {L <: PSY.ElectricLoad,
                                                          S <: PM.AbstractPowerFormulation}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(device, sys)

    if validate_available_devices(devices, device)
        return
    end

    parameters = get(kwargs, :parameters, true)

    if forecast
        first_step = PSY.get_forecasts_initial_time(sys)
        forecasts = collect(PSY.get_forecasts(PSY.Deterministic{L}, sys, PSY.get_forecasts_initial_time(sys)))
        nodal_expression(ps_m, forecasts, system_formulation, parameters)
    else
        nodal_expression(ps_m, devices, system_formulation, parameters)
    end

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{L},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {L <: PSY.StaticLoad,
                                                          D <: AbstractControllablePowerLoadForm,
                                                          S <: PM.AbstractPowerFormulation}

    if device_formulation != StaticPowerLoad
        @warn("The Formulation $(D) only applies to Controllable Loads, \n Consider Changing the Device Formulation to StaticPowerLoad")
    end

    _internal_device_constructor!(ps_m,
                                  device,
                                  StaticPowerLoad,
                                  system_formulation,
                                  sys;
                                  kwargs...)

end
