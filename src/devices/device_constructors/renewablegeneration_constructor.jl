function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{R},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {R<:PSY.RenewableGen,
                                                          D<:AbstractRenewableDispatchForm,
                                                          S<:PM.AbstractPowerFormulation}


    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(device, sys)

    if validate_available_devices(devices, device)
        return
    end

    #Variables
    activepower_variables(ps_m, devices);

    reactivepower_variables(ps_m, devices);

    #Constraints
    if forecast
        first_step = model_initial_time(ps_m)
        forecasts = PSY.get_forecasts(PSY.Deterministic{R}, sys, first_step)
        activepower_constraints(ps_m, forecasts, device_formulation, system_formulation)
    else
        activepower_constraints(ps_m, devices, device_formulation, system_formulation)
    end

    reactivepower_constraints(ps_m, devices, device_formulation, system_formulation)

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{R},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {R<:PSY.RenewableGen,
                                                          D<:AbstractRenewableDispatchForm,
                                                          S<:PM.AbstractActivePowerFormulation}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(device, sys)

    if validate_available_devices(devices, device)
        return
    end

    #Variables
    activepower_variables(ps_m, devices)

    #Constraints
    if forecast
        first_step = PSY.get_forecasts_initial_time(sys)
        forecasts = PSY.get_forecasts(PSY.Deterministic{R}, sys, first_step)
        isempty(forecasts) && error("System has no forecasts")
        activepower_constraints(ps_m, forecasts, device_formulation, system_formulation)
    else
        activepower_constraints(ps_m, devices, device_formulation, system_formulation)
    end

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{R},
                                        device_formulation::Type{RenewableFixed},
                                        system_formulation::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {R<:PSY.RenewableGen,
                                                          S<:PM.AbstractPowerFormulation}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(device, sys)

    if validate_available_devices(devices, device)
        return
    end

    if forecast
        first_step = PSY.get_forecasts_initial_time(sys)
        forecasts = PSY.get_forecasts(PSY.Deterministic{R}, sys, first_step)
        nodal_expression(ps_m, forecasts, system_formulation)
    else
        nodal_expression(ps_m, devices, system_formulation)
    end

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{PSY.RenewableFix},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {D<:AbstractRenewableDispatchForm,
                                                          S<:PM.AbstractPowerFormulation}

    @warn("The Formulation $(D) only applies to Controllable Renewable Resources, \n Consider Changing the Device Formulation to RenewableFixed")

    _internal_device_constructor!(ps_m,
                                  device,
                                  RenewableFixed,
                                  system_formulation,
                                  sys;
                                  kwargs...)

    return

end


function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{PSY.RenewableFix},
                                        device_formulation::Type{RenewableFixed},
                                        system_formulation::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {S<:PM.AbstractPowerFormulation}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(device, sys)

    if validate_available_devices(devices, device)
        return
    end

    if forecast
        first_step = PSY.get_forecasts_initial_time(sys)
        forecasts = PSY.get_forecasts(PSY.Deterministic{PSY.RenewableFix}, sys, first_step)
        nodal_expression(ps_m, forecasts, system_formulation)
    else
        nodal_expression(ps_m, devices, system_formulation)
    end

    return

end
