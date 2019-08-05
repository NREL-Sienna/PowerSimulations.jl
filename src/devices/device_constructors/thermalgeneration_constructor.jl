"""
This function creates the model for a full themal dis`pa`tch formulation depending on combination of devices, device_formulation and system_formulation
"""
function _internal_device_constructor!(ps_m::CanonicalModel,
                                        ::Type{T},
                                        ::Type{D},
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
    activepower_variables!(ps_m, devices)

    reactivepower_variables!(ps_m, devices)

    commitment_variables!(ps_m, devices)

    #Constraints
    activepower_constraints!(ps_m, devices, D, S)

    reactivepower_constraints!(ps_m, devices, D, S)

    commitment_constraints!(ps_m, devices, D, S)

    ramp_constraints!(ps_m, devices, D, S)

    time_constraints!(ps_m, devices, D, S)

    #Cost Function
    cost_function(ps_m, devices, D, S)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function _internal_device_constructor!(ps_m::CanonicalModel,
                                       ::Type{T},
                                       ::Type{D},
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
    activepower_variables!(ps_m, devices)

    commitment_variables!(ps_m, devices)

    #Constraints
    activepower_constraints!(ps_m, devices, D, S)

    commitment_constraints!(ps_m, devices, D, S)

    ramp_constraints!(ps_m, devices, D, S)

    time_constraints!(ps_m, devices, D, S)

    #Cost Function
    cost_function(ps_m, devices, D, S)

    return

end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function _internal_device_constructor!(ps_m::CanonicalModel,
                                        ::Type{T},
                                        ::Type{ThermalRampLimited},
                                        ::Type{S},
                                        sys::PSY.System;
                                        kwargs...) where {T<:PSY.ThermalGen,
                                                          S<:PM.AbstractPowerFormulation}

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(ps_m, devices)

    reactivepower_variables!(ps_m, devices)

    #Constraints
    activepower_constraints!(ps_m, devices, ThermalRampLimited, S)

    reactivepower_constraints!(ps_m, devices, ThermalRampLimited, S)

    ramp_constraints!(ps_m, devices, ThermalRampLimited, S)

    #Cost Function
    cost_function(ps_m, devices, ThermalRampLimited, S)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function _internal_device_constructor!(ps_m::CanonicalModel,
                                       ::Type{T},
                                       ::Type{ThermalRampLimited},
                                       ::Type{S},
                                       sys::PSY.System;
                                       kwargs...) where {T<:PSY.ThermalGen,
                                                         S<:PM.AbstractActivePowerFormulation}

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(ps_m, devices)

    #Constraints
    activepower_constraints!(ps_m, devices, ThermalRampLimited, S)

    ramp_constraints!(ps_m, devices, ThermalRampLimited, S)

    #Cost Function
    cost_function(ps_m, devices, ThermalRampLimited, S)

    return

end



function _internal_device_constructor!(ps_m::CanonicalModel,
                                       ::Type{T},
                                       ::Type{D},
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
    activepower_variables!(ps_m, devices)

    reactivepower_variables!(ps_m, devices)

    #Constraints
    activepower_constraints!(ps_m, devices, D, S)

    reactivepower_constraints!(ps_m, devices, D, S)

    #Cost Function
    cost_function(ps_m, devices, D, S)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        ::Type{T},
                                        ::Type{D},
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
    activepower_variables!(ps_m, devices)

    #Constraints
    activepower_constraints!(ps_m, devices, D, S)

    #Cost Function
    cost_function(ps_m, devices, D, S)

    return

end
