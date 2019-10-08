function _internal_device_constructor!(canonical_model::CanonicalModel,
                                       model::DeviceModel{L, D},
                                       ::Type{S},
                                       sys::PSY.System;
                                       kwargs...) where {L<:PSY.ControllableLoad,
                                                         D<:AbstractFormulationControllablePowerLoadFormulation,
                                                         S<:PM.AbstracPowerModel}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables(canonical_model, devices)

    reactivepower_variables(canonical_model, devices)

    #Constraints
    if forecast
        forecasts = _retrieve_forecasts(sys, L)
        activepower_constraints(canonical_model, forecasts, D, S)
    else
        activepower_constraints(canonical_model, devices, D, S)
    end

    reactivepower_constraints(canonical_model, devices, D, S)

    feedforward!(canonical_model, L, model.feedforward)

    #Cost Function
    cost_function(canonical_model, devices, D, S)

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                                      model::DeviceModel{L, D},
                                      ::Type{S},
                                      sys::PSY.System;
                                      kwargs...) where {L<:PSY.ControllableLoad,
                                                        D<:AbstractFormulationControllablePowerLoadFormulation,
                                                        S<:PM.AbstractActivePowerModel}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables(canonical_model, devices)

    #Constraints
    if forecast
        forecasts = _retrieve_forecasts(sys, L)
        activepower_constraints(canonical_model, forecasts, D, S)
    else
        activepower_constraints(canonical_model, devices, D, S)
    end

    feedforward!(canonical_model, L, model.feedforward)

    #Cost Function
    cost_function(canonical_model, devices, D, S)

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                                        model::DeviceModel{L, InterruptiblePowerLoad},
                                        ::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {L<:PSY.ControllableLoad,
                                                          S<:PM.AbstracPowerModel}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables(canonical_model, devices)

    reactivepower_variables(canonical_model, devices)

    commitment_variables(canonical_model, devices)

    #Constraints
    if forecast
        forecasts = _retrieve_forecasts(sys, L)
        activepower_constraints(canonical_model, forecasts, model.formulation, S)
    else
        activepower_constraints(canonical_model, devices, model.formulation, S)
    end

    reactivepower_constraints(canonical_model, devices, model.formulation, S)

    feedforward!(canonical_model, L, model.feedforward)

    #Cost Function
    cost_function(canonical_model, devices, model.formulation, S)

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                                      model::DeviceModel{L, InterruptiblePowerLoad},
                                      ::Type{S},
                                      sys::PSY.System;
                                      kwargs...) where {L<:PSY.ControllableLoad,
                                                        S<:PM.AbstractActivePowerModel}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables(canonical_model, devices)

    commitment_variables(canonical_model, devices)

    #Constraints
    if forecast
        forecasts = _retrieve_forecasts(sys, L)
        activepower_constraints(canonical_model, forecasts, model.formulation, S)
    else
        activepower_constraints(canonical_model, devices, model.formulation, S)
    end

    feedforward!(canonical_model, L, model.feedforward)

    #Cost Function
    cost_function(canonical_model, devices, model.formulation, S)

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                                        model::DeviceModel{L, StaticPowerLoad},
                                        ::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {L<:PSY.ElectricLoad,
                                                          S<:PM.AbstracPowerModel}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    if forecast
        forecasts = _retrieve_forecasts(sys, L)
        nodal_expression(canonical_model, forecasts, S)
    else
        nodal_expression(canonical_model, devices, S)
    end

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                                        model::DeviceModel{L, D},
                                        ::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {L<:PSY.StaticLoad,
                                                          D<:AbstractFormulationControllablePowerLoadFormulation,
                                                          S<:PM.AbstracPowerModel}

    if D != StaticPowerLoad
        @warn("The Formulation $(D) only applies to FormulationControllable Loads, \n Consider Changing the Device Formulation to StaticPowerLoad")
    end

    _internal_device_constructor!(canonical_model,
                                  DeviceModel(L, StaticPowerLoad),
                                  S,
                                  sys;
                                  kwargs...)

end
