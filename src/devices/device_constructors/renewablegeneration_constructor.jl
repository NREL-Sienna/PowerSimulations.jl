function _internal_device_constructor!(canonical_model::CanonicalModel,
                                        model::DeviceModel{R, D},
                                        ::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {R<:PSY.RenewableGen,
                                                          D<:AbstractRenewableDispatchFormulation,
                                                          S<:PM.AbstractPowerModel}


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

    feedforward!(canonical_model, R, model.feedforward)

    #Cost Function
    cost_function(canonical_model, devices, D, S)

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                                        model::DeviceModel{R, D},
                                        ::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {R<:PSY.RenewableGen,
                                                          D<:AbstractRenewableDispatchFormulation,
                                                          S<:PM.AbstractActivePowerModel}

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

    feedforward!(canonical_model, R, model.feedforward)

    #Cost Function
    cost_function(canonical_model, devices, D, S)

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                                        model::DeviceModel{R, RenewableFixed},
                                        system_formulation::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {R<:PSY.RenewableGen,
                                                          S<:PM.AbstractPowerModel}

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
                                       kwargs...) where {D<:AbstractRenewableDispatchFormulation,
                                                          S<:PM.AbstractPowerModel}

    @warn("The Formulation $(D) only applies to FormulationControllable Renewable Resources, \n Consider Changing the Device Formulation to RenewableFixed")

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
                                       kwargs...) where {S<:PM.AbstractPowerModel}

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
