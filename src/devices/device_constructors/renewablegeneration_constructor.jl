function _internal_device_constructor!(ps_m::CanonicalModel,
                                        ::Type{R},
                                        ::Type{D},
                                        ::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {R<:PSY.RenewableGen,
                                                          D<:AbstractRenewableDispatchForm,
                                                          S<:PM.AbstractPowerFormulation}


    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(R, sys)

    if validate_available_devices(devices, R)
        return
    end

    #Variables
    activepower_variables(ps_m, devices);

    reactivepower_variables(ps_m, devices);

    #Constraints
    if forecast
        forecasts = _retrieve_forecasts(sys, R)
        activepower_constraints(ps_m, forecasts, D, S)
    else
        activepower_constraints(ps_m, devices, D, S)
    end

    reactivepower_constraints(ps_m, devices, D, S)

    #Cost Function
    cost_function(ps_m, devices, D, S)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        ::Type{R},
                                        ::Type{D},
                                        ::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {R<:PSY.RenewableGen,
                                                          D<:AbstractRenewableDispatchForm,
                                                          S<:PM.AbstractActivePowerFormulation}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(R, sys)

    if validate_available_devices(devices, R)
        return
    end

    #Variables
    activepower_variables(ps_m, devices)

    #Constraints
    if forecast
        forecasts = _retrieve_forecasts(sys, R)
        activepower_constraints(ps_m, forecasts, D, S)
    else
        activepower_constraints(ps_m, devices, D, S)
    end

    #Cost Function
    cost_function(ps_m, devices, D, S)

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
        forecasts = _retrieve_forecasts(sys, R)
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
                                        ::Type{PSY.RenewableFix},
                                        device_formulation::Type{RenewableFixed},
                                        system_formulation::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {S<:PM.AbstractPowerFormulation}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(PSY.RenewableFix, sys)

    if validate_available_devices(devices, PSY.RenewableFix)
        return
    end

    if forecast
        forecasts = _retrieve_forecasts(sys, PSY.RenewableFix)
        nodal_expression(ps_m, forecasts, system_formulation)
    else
        nodal_expression(ps_m, devices, system_formulation)
    end

    return

end
