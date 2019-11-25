"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(psi_container::PSIContainer, sys::PSY.System,
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
    activepower_variables!(psi_container, devices)

    reactivepower_variables!(psi_container, devices)

    commitment_variables!(psi_container, devices)

    #Initial Conditions

    initial_conditions!(psi_container, devices, D)

    #Constraints
    activepower_constraints!(psi_container, devices, D, S)

    reactivepower_constraints!(psi_container, devices, D, S)

    commitment_constraints!(psi_container, devices, D, S)

    ramp_constraints!(psi_container, devices, D, S)

    time_constraints!(psi_container, devices, D, S)

    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(psi_container::PSIContainer, sys::PSY.System,
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
    activepower_variables!(psi_container, devices)

    commitment_variables!(psi_container, devices)

    #Initial Conditions

    initial_conditions!(psi_container, devices, D)

    #Constraints
    activepower_constraints!(psi_container, devices, D, S)

    commitment_constraints!(psi_container, devices, D, S)

    ramp_constraints!(psi_container, devices, D, S)

    time_constraints!(psi_container, devices, D, S)

    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return

end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{T, ThermalBasicUnitCommitment},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             S<:PM.AbstractPowerModel}



    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)

    reactivepower_variables!(psi_container, devices)

    commitment_variables!(psi_container, devices)

    #Initial Conditions

    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model.formulation, S)

    reactivepower_constraints!(psi_container, devices, model.formulation, S)

    commitment_constraints!(psi_container, devices, model.formulation, S)

    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{T, ThermalBasicUnitCommitment},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             S<:PM.AbstractActivePowerModel}



    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)

    commitment_variables!(psi_container, devices)

    #Initial Conditions

    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model.formulation, S)

    commitment_constraints!(psi_container, devices, model.formulation, S)

    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S)

    return

end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{T, ThermalRampLimited},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             S<:PM.AbstractPowerModel}



    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)

    reactivepower_variables!(psi_container, devices)

    #Initial Conditions

    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(psi_container, devices, ThermalRampLimited, S)
    end

    reactivepower_constraints!(psi_container, devices, model.formulation, S)

    ramp_constraints!(psi_container, devices, model.formulation, S)

    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{T, ThermalRampLimited},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             S<:PM.AbstractActivePowerModel}



    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)

    #Initial Conditions

    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(psi_container, devices, ThermalRampLimited, S)
    end

    ramp_constraints!(psi_container, devices, model.formulation, S)

    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S)

    return

end



function construct_device!(psi_container::PSIContainer, sys::PSY.System,
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
    activepower_variables!(psi_container, devices)

    reactivepower_variables!(psi_container, devices)

    #Initial Conditions

    #Constraints
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(psi_container, devices, D, S)
    end

    reactivepower_constraints!(psi_container, devices, D, S)

    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return

end

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
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
    activepower_variables!(psi_container, devices)

    #Initial Conditions

    #Constraints
    # Slighly hacky for now
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(psi_container, devices, D, S)
    end

    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return

end
