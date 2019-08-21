"""
This function creates the model for a full themal dis`pa`tch formulation depending on combination of devices, device_formulation and system_formulation
"""
function _internal_device_constructor!(canonical_model::CanonicalModel,
                                       model::DeviceModel{T, D},
                                       ::Type{S},
                                       sys::PSY.System;
                                       kwargs...) where {T<:PSY.ThermalGen,
                                                         D<:AbstractThermalFormulation,
                                                         S<:PM.AbstractPowerFormulation}

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical_model, devices)

    reactivepower_variables!(canonical_model, devices)

    commitment_variables!(canonical_model, devices)

    #Constraints
    activepower_constraints!(canonical_model, devices, D, S)

    reactivepower_constraints!(canonical_model, devices, D, S)

    commitment_constraints!(canonical_model, devices, D, S)

    ramp_constraints!(canonical_model, devices, D, S)

    time_constraints!(canonical_model, devices, D, S)

    #Cost Function
    cost_function(canonical_model, devices, D, S)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function _internal_device_constructor!(canonical_model::CanonicalModel,
                                       model::DeviceModel{T, D},
                                       ::Type{S},
                                       sys::PSY.System;
                                       kwargs...) where {T<:PSY.ThermalGen,
                                                         D<:AbstractThermalFormulation,
                                                         S<:PM.AbstractActivePowerFormulation}

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical_model, devices)

    commitment_variables!(canonical_model, devices)

    #Constraints
    activepower_constraints!(canonical_model, devices, D, S)

    commitment_constraints!(canonical_model, devices, D, S)

    ramp_constraints!(canonical_model, devices, D, S)

    time_constraints!(canonical_model, devices, D, S)

    #Cost Function
    cost_function(canonical_model, devices, D, S)

    return

end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function _internal_device_constructor!(canonical_model::CanonicalModel,
                                        model::DeviceModel{T, ThermalRampLimited},
                                        ::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {T<:PSY.ThermalGen,
                                                          S<:PM.AbstractPowerFormulation}

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical_model, devices)

    reactivepower_variables!(canonical_model, devices)

    #Constraints
    activepower_constraints!(canonical_model, devices, ThermalRampLimited, S)

    reactivepower_constraints!(canonical_model, devices, ThermalRampLimited, S)

    ramp_constraints!(canonical_model, devices, ThermalRampLimited, S)

    #Cost Function
    cost_function(canonical_model, devices, ThermalRampLimited, S)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function _internal_device_constructor!(canonical_model::CanonicalModel,
                                       model::DeviceModel{T, ThermalRampLimited},
                                       ::Type{S},
                                       sys::PSY.System;
                                       kwargs...) where {T<:PSY.ThermalGen,
                                                         S<:PM.AbstractActivePowerFormulation}

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical_model, devices)

    #Constraints
    activepower_constraints!(canonical_model, devices, ThermalRampLimited, S)

    ramp_constraints!(canonical_model, devices, ThermalRampLimited, S)

    #Cost Function
    cost_function(canonical_model, devices, ThermalRampLimited, S)

    return

end



function _internal_device_constructor!(canonical_model::CanonicalModel,
                                       model::DeviceModel{T, D},
                                       ::Type{S},
                                       sys::PSY.System;
                                       kwargs...) where {T<: PSY.ThermalGen,
                                                         D<:AbstractThermalDispatchForm,
                                                         S<:PM.AbstractPowerFormulation}

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical_model, devices)

    reactivepower_variables!(canonical_model, devices)

    #Constraints
    activepower_constraints!(canonical_model, devices, D, S)

    reactivepower_constraints!(canonical_model, devices, D, S)

    #Cost Function
    cost_function(canonical_model, devices, D, S)

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                                       model::DeviceModel{T, D},
                                       ::Type{S},
                                       sys::PSY.System;
                                       kwargs...) where {T<: PSY.ThermalGen,
                                                         D<:AbstractThermalDispatchForm,
                                                         S<:PM.AbstractActivePowerFormulation}

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical_model, devices)

    #Constraints
    activepower_constraints!(canonical_model, devices, D, S)

    #Cost Function
    cost_function(canonical_model, devices, D, S)

    return

end
