"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{T, D},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             D<:AbstractThermalFormulation,
                                             S<:PM.AbstractPowerModel}



    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical, devices)

    reactivepower_variables!(canonical, devices)

    commitment_variables!(canonical, devices)

    #Initial Conditions

    initial_conditions!(canonical, devices, D)

    #Constraints
    activepower_constraints!(canonical, devices, D, S)

    reactivepower_constraints!(canonical, devices, D, S)

    commitment_constraints!(canonical, devices, D, S)

    ramp_constraints!(canonical, devices, D, S)

    time_constraints!(canonical, devices, D, S)

    feedforward!(canonical, T, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, D, S)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{T, D},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             D<:AbstractThermalFormulation,
                                             S<:PM.AbstractActivePowerModel}


    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical, devices)

    commitment_variables!(canonical, devices)

    #Initial Conditions

    initial_conditions!(canonical, devices, D)

    #Constraints
    activepower_constraints!(canonical, devices, D, S)

    commitment_constraints!(canonical, devices, D, S)

    ramp_constraints!(canonical, devices, D, S)

    time_constraints!(canonical, devices, D, S)

    feedforward!(canonical, T, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, D, S)

    return

end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{T, ThermalBasicUnitCommitment},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             S<:PM.AbstractPowerModel}



    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical, devices)

    reactivepower_variables!(canonical, devices)

    commitment_variables!(canonical, devices)

    #Initial Conditions

    initial_conditions!(canonical, devices, model.formulation)

    #Constraints
    activepower_constraints!(canonical, devices, model.formulation, S)

    reactivepower_constraints!(canonical, devices, model.formulation, S)

    commitment_constraints!(canonical, devices, model.formulation, S)

    feedforward!(canonical, T, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, model.formulation, S)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{T, ThermalBasicUnitCommitment},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             S<:PM.AbstractActivePowerModel}



    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical, devices)

    commitment_variables!(canonical, devices)

    #Initial Conditions

    initial_conditions!(canonical, devices, model.formulation)

    #Constraints
    activepower_constraints!(canonical, devices, model.formulation, S)

    commitment_constraints!(canonical, devices, model.formulation, S)

    feedforward!(canonical, T, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, model.formulation, S)

    return

end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{T, ThermalRampLimited},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             S<:PM.AbstractPowerModel}



    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical, devices)

    reactivepower_variables!(canonical, devices)

    #Initial Conditions

    initial_conditions!(canonical, devices, model.formulation)

    #Constraints
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(canonical, devices, ThermalRampLimited, S)
    end

    reactivepower_constraints!(canonical, devices, model.formulation, S)

    ramp_constraints!(canonical, devices, model.formulation, S)

    feedforward!(canonical, T, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, model.formulation, S)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{T, ThermalRampLimited},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             S<:PM.AbstractActivePowerModel}



    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical, devices)

    #Initial Conditions

    initial_conditions!(canonical, devices, model.formulation)

    #Constraints
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(canonical, devices, ThermalRampLimited, S)
    end

    ramp_constraints!(canonical, devices, model.formulation, S)

    feedforward!(canonical, T, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, model.formulation, S)

    return

end



function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{T, D},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             D<:AbstractThermalDispatchFormulation,
                                             S<:PM.AbstractPowerModel}



    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical, devices)

    reactivepower_variables!(canonical, devices)

    #Initial Conditions

    #Constraints
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(canonical, devices, D, S)
    end

    reactivepower_constraints!(canonical, devices, D, S)

    feedforward!(canonical, T, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, D, S)

    return

end

function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{T, D},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             D<:AbstractThermalDispatchFormulation,
                                             S<:PM.AbstractActivePowerModel}



    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(canonical, devices)

    #Initial Conditions

    #Constraints
    # Slighly hacky for now
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(canonical, devices, D, S)
    end

    feedforward!(canonical, T, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, D, S)

    return

end
