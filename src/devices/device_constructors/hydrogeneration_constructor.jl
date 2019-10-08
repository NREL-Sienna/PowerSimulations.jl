function _internal_device_constructor!(canonical_model::CanonicalModel,
                                        model::DeviceModel{H, D},
                                        ::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {H<:PSY.HydroGen,
                                                          D<:AbstractHydroFormulation,
                                                          S<:PM.AbstracPowerModel}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #error("Currently only HydroFixed Formulation is Enabled")
    #=
    if forecast
        first_step = PSY.get_forecasts_initial_time(sys)
        forecasts = PSY.get_forecasts(PSY.Deterministic{H}, sys, first_step)
        nodal_expression(canonical_model, forecasts, S)
    else
        nodal_expression(canonical_model, devices, S)
    end
    =#
    return

end


function _internal_device_constructor!(canonical_model::CanonicalModel,
                                        model::DeviceModel{H, HydroFixed},
                                        ::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {H<:PSY.HydroGen,
                                                          S<:PM.AbstracPowerModel}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    if forecast
        forecasts = _retrieve_forecasts(sys, H)
        nodal_expression(canonical_model, forecasts, S)
    else
        nodal_expression(canonical_model, devices, S)
    end

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                                        model::DeviceModel{PSY.HydroFix, D},
                                        ::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {D<:AbstractHydroFormulation,
                                                          S<:PM.AbstracPowerModel}

    @warn("The Formulation $(D) only applies to Dispatchable Hydro, *
               Consider Changing the Device Formulation to HydroFixed")

    _internal_device_constructor!(canonical_model,
                                  DeviceModel(PSY.HydroFix, HydroFixed),
                                  S,
                                  sys;
                                  kwargs...)

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                                        model::DeviceModel{PSY.HydroFix, HydroFixed},
                                        ::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {S<:PM.AbstracPowerModel}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(PSY.HydroFix, sys)

    if validate_available_devices(devices, PSY.HydroFix)
        return
    end

    if forecast
        forecasts = _retrieve_forecasts(sys, PSY.HydroFix)
        nodal_expression(canonical_model, forecasts, S)
    else
        nodal_expression(canonical_model, devices, S)
    end

    return

end
