"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
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

    #Initial Conditions

    initial_conditions!(canonical_model, devices, D)

    #Constraints
    activepower_constraints!(canonical_model, devices, D, S)

    reactivepower_constraints!(canonical_model, devices, D, S)

    commitment_constraints!(canonical_model, devices, D, S)

    ramp_constraints!(canonical_model, devices, D, S)

    time_constraints!(canonical_model, devices, D, S)

    feedforward!(canonical_model, T, model.feedforward)

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

    #Initial Conditions

    initial_conditions!(canonical_model, devices, D)

    #Constraints
    activepower_constraints!(canonical_model, devices, D, S)

    commitment_constraints!(canonical_model, devices, D, S)

    ramp_constraints!(canonical_model, devices, D, S)

    time_constraints!(canonical_model, devices, D, S)

    feedforward!(canonical_model, T, model.feedforward)

    #Cost Function
    cost_function(canonical_model, devices, D, S)

    return

end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function _internal_device_constructor!(canonical_model::CanonicalModel,
                                       model::DeviceModel{T, ThermalBasicUnitCommitment},
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

    commitment_variables!(canonical_model, devices)

    #Initial Conditions

    initial_conditions!(canonical_model, devices, model.formulation)

    #Constraints
    activepower_constraints!(canonical_model, devices, model.formulation, S)

    reactivepower_constraints!(canonical_model, devices, model.formulation, S)

    commitment_constraints!(canonical_model, devices, model.formulation, S)

    feedforward!(canonical_model, T, model.feedforward)

    #Cost Function
    cost_function(canonical_model, devices, model.formulation, S)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function _internal_device_constructor!(canonical_model::CanonicalModel,
                                       model::DeviceModel{T, ThermalBasicUnitCommitment},
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

    commitment_variables!(canonical_model, devices)

    #Initial Conditions

    initial_conditions!(canonical_model, devices, model.formulation)

    #Constraints
    activepower_constraints!(canonical_model, devices, model.formulation, S)

    commitment_constraints!(canonical_model, devices, model.formulation, S)

    feedforward!(canonical_model, T, model.feedforward)

    #Cost Function
    cost_function(canonical_model, devices, model.formulation, S)

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

    #Initial Conditions

    initial_conditions!(canonical_model, devices, model.formulation)

    #Constraints
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(canonical_model, devices, ThermalRampLimited, S)
    end

    reactivepower_constraints!(canonical_model, devices, model.formulation, S)

    ramp_constraints!(canonical_model, devices, model.formulation, S)

    feedforward!(canonical_model, T, model.feedforward)

    #Cost Function
    cost_function(canonical_model, devices, model.formulation, S)

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

    #Initial Conditions

    initial_conditions!(canonical_model, devices, model.formulation)

    #Constraints
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(canonical_model, devices, ThermalRampLimited, S)
    end

    ramp_constraints!(canonical_model, devices, model.formulation, S)

    feedforward!(canonical_model, T, model.feedforward)

    #Cost Function
    cost_function(canonical_model, devices, model.formulation, S)

    return

end



function _internal_device_constructor!(canonical_model::CanonicalModel,
                                       model::DeviceModel{T, D},
                                       ::Type{S},
                                       sys::PSY.System;
                                       kwargs...) where {T<: PSY.ThermalGen,
                                                         D<:AbstractThermalDispatchFormulation,
                                                         S<:PM.AbstractPowerFormulation}

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical_model, devices)

    reactivepower_variables!(canonical_model, devices)

    #Initial Conditions

    #Constraints
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(canonical_model, devices, D, S)
    end

    reactivepower_constraints!(canonical_model, devices, D, S)

    feedforward!(canonical_model, T, model.feedforward)

    #Cost Function
    cost_function(canonical_model, devices, D, S)

    return

end

function _internal_device_constructor!(canonical_model::CanonicalModel,
                                       model::DeviceModel{T, D},
                                       ::Type{S},
                                       sys::PSY.System;
                                       kwargs...) where {T<: PSY.ThermalGen,
                                                         D<:AbstractThermalDispatchFormulation,
                                                         S<:PM.AbstractActivePowerFormulation}

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical_model, devices)

    #Initial Conditions

    #Constraints
    # Slighly hacky for now
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(canonical_model, devices, D, S)
    end

    feedforward!(canonical_model, T, model.feedforward)

    #Cost Function
    cost_function(canonical_model, devices, D, S)

    return

end
