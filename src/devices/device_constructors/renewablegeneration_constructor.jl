function _internal_device_constructor!(canonical_model::CanonicalModel,
                                        model::DeviceModel{R, D},
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
    activepower_variables(canonical_model, devices);

    reactivepower_variables(canonical_model, devices);

    #Constraints
    if forecast
        forecasts = _retrieve_forecasts(sys, R)
        activepower_constraints(canonical_model, forecasts, D, S)
    else
        activepower_constraints(canonical_model, devices, D, S)
    end

    reactivepower_constraints(canonical_model, devices, D, S)

    #Cost Function
    cost_function(canonical_model, devices, D, S)

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                                        model::DeviceModel{R, D},
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
    activepower_variables(canonical_model, devices)

    #Constraints
    if forecast
        forecasts = _retrieve_forecasts(sys, R)
        activepower_constraints(canonical_model, forecasts, D, S)
    else
        activepower_constraints(canonical_model, devices, D, S)
    end

    #Cost Function
    cost_function(canonical_model, devices, D, S)

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                                        model::DeviceModel{R, RenewableFixed},
                                        system_formulation::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {R<:PSY.RenewableGen,
                                                          S<:PM.AbstractPowerFormulation}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(R, sys)

    if validate_available_devices(devices, R)
        return
    end

    if forecast
        forecasts = _retrieve_forecasts(sys, R)
        nodal_expression(canonical_model, forecasts, system_formulation)
    else
        nodal_expression(canonical_model, devices, system_formulation)
    end

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                                       model::DeviceModel{PSY.RenewableFix, D},
                                       system_formulation::Type{S},
                                       sys::PSY.System;
                                       kwargs...) where {D<:AbstractRenewableDispatchForm,
                                                          S<:PM.AbstractPowerFormulation}

    @warn("The Formulation $(D) only applies to Controllable Renewable Resources, \n Consider Changing the Device Formulation to RenewableFixed")

    _internal_device_constructor!(canonical_model,
                                  DeviceModel(PSY.RenewableFix,RenewableFixed),
                                  system_formulation,
                                  sys;
                                  kwargs...)

    return

end


function _internal_device_constructor!(canonical_model::CanonicalModel,
                                       model::DeviceModel{PSY.RenewableFix, RenewableFixed},
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
        nodal_expression(canonical_model, forecasts, system_formulation)
    else
        nodal_expression(canonical_model, devices, system_formulation)
    end

    return

end
