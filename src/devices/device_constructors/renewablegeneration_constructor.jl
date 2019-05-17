function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{R},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.System,
                                        time_range::UnitRange{Int64},
                                        resolution::Dates.Period;
                                        kwargs...) where {R <: PSY.RenewableGen,
                                                          D <: AbstractRenewableDispatchForm,
                                                          S <: PM.AbstractPowerFormulation}

    
    forecast = get(kwargs, :forecast, true)
    
    devices = PSY.get_components(device, sys)
       
    if validate_available_devices(devices, device)
        return
    end

    parameters = get(kwargs, :parameters, true)
    
    #Variables
    activepower_variables(ps_m, devices, time_range);

    reactivepower_variables(ps_m, devices, time_range);

    #Constraints
    if forecast 
        first_step = collect(PSY.get_forecast_issue_times(sys))[1]
        forecasts = Vector{PSY.Deterministic{R}}(PSY.get_forecasts(sys, first_step, devices))
        activepower_constraints(ps_m, forecasts, device_formulation, system_formulation, time_range, parameters)
    else
        activepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range, parameters)
    end

    reactivepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range)

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation, resolution)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{R},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.System,
                                        time_range::UnitRange{Int64},
                                        resolution::Dates.Period;
                                        kwargs...) where {R <: PSY.RenewableGen,
                                                          D <: AbstractRenewableDispatchForm,
                                                          S <: PM.AbstractActivePowerFormulation}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(device, sys)
   
    if validate_available_devices(devices, device)
        return
    end

    parameters = get(kwargs, :parameters, true)                                             

    #Variables
    activepower_variables(ps_m, devices, time_range)

    #Constraints
    if forecast 
        first_step = collect(PSY.get_forecast_issue_times(sys))[1]
        forecasts = Vector{PSY.Deterministic{R}}(PSY.get_forecasts(sys, first_step, devices))
        activepower_constraints(ps_m, forecasts, device_formulation, system_formulation, time_range, parameters)
    else
        activepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range, parameters)
    end

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation, resolution)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{R},
                                        device_formulation::Type{RenewableFixed},
                                        system_formulation::Type{S},
                                        sys::PSY.System,
                                        time_range::UnitRange{Int64},
                                        resolution::Dates.Period;
                                        kwargs...) where {R <: PSY.RenewableGen,
                                                          S <: PM.AbstractPowerFormulation}

    forecast = get(kwargs, :forecast, true)

    devices = PSY.get_components(device, sys)
    
    if validate_available_devices(devices, device)
        return
    end

    parameters = get(kwargs, :parameters, true)

    if forecast 
        first_step = collect(PSY.get_forecast_issue_times(sys))[1]
        forecasts = Vector{PSY.Deterministic{R}}(PSY.get_forecasts(sys, first_step, devices))
        nodal_expression(ps_m, forecasts, system_formulation, time_range, parameters)
    else
        nodal_expression(ps_m, devices, system_formulation, time_range, parameters)
    end   

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{PSY.RenewableFix},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.System,
                                        time_range::UnitRange{Int64},
                                        resolution::Dates.Period;
                                        kwargs...) where {D <: AbstractRenewableDispatchForm,
                                                          S <: PM.AbstractPowerFormulation}

    if device_formulation != RenewableFixed
        @warn("The Formulation $(D) only applies to Controllable Renewable Resources, \n Consider Changing the Device Formulation to RenewableFixed")                                              
    end

    _internal_device_constructor!(ps_m, 
                                  device,
                                  RenewableFixed,
                                  sys,
                                  time_range; 
                                  kwargs...)

end                      
