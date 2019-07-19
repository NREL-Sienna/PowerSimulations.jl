function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{H},
                                        device_formulation::Type{HydroFixed},
                                        system_formulation::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {H <: PSY.HydroGen,
                                                          S <: PM.AbstractPowerFormulation}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(device, sys)

    if validate_available_devices(devices, device)
        return
    end

    if forecast
        first_step = PSY.get_forecasts_initial_time(sys)
        forecasts = PSY.get_forecasts(PSY.Deterministic{H}, sys, first_step)
        nodal_expression(ps_m, forecasts, system_formulation)
    else
        nodal_expression(ps_m, devices, system_formulation)
    end

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{PSY.HydroFix},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {D <: AbstractHydroFormulation,
                                                          S <: PM.AbstractPowerFormulation}

    if device_formulation != HydroFixed
        @warn("The Formulation $(D) only applies to Dispatchable Hydro, *
               Consider Changing the Device Formulation to HydroFixed")
    end

    _internal_device_constructor!(ps_m,
                                  device,
                                  HydroFixed,
                                  sys,
                                  kwargs...)

end
