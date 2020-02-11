"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S};
    kwargs...,
) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerModel}
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
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    reactivepower_constraints!(psi_container, devices, model, S, model.feedforward)
    commitment_constraints!(psi_container, devices, model, S, model.feedforward)
    ramp_constraints!(psi_container, devices, model, S, model.feedforward)
    time_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, D, S, model.feedforward)

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S};
    kwargs...,
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalFormulation,
    S <: PM.AbstractActivePowerModel,
}
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
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    commitment_constraints!(psi_container, devices, model, S, model.feedforward)
    ramp_constraints!(psi_container, devices, model, S, model.feedforward)
    time_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, D, S, model.feedforward)

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalBasicUnitCommitment},
    ::Type{S};
    kwargs...,
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
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
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    reactivepower_constraints!(psi_container, devices, model, S, model.feedforward)
    commitment_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S, model.feedforward)

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalBasicUnitCommitment},
    ::Type{S};
    kwargs...,
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
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
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    commitment_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S, model.feedforward)

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalRampLimited},
    ::Type{S};
    kwargs...,
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
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
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    reactivepower_constraints!(psi_container, devices, model, S, model.feedforward)
    ramp_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S, model.feedforward)

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalRampLimited},
    ::Type{S};
    kwargs...,
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    ramp_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S, model.feedforward)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S};
    kwargs...,
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalDispatchFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    reactivepower_variables!(psi_container, devices)

    #Initial Conditions

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    reactivepower_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, D, S, model.feedforward)

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S};
    kwargs...,
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalDispatchFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)

    #Initial Conditions

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feedforward)
    feedforward!(psi_container, T, model.feedforward)

    #Cost Function
    cost_function(psi_container, devices, D, S, model.feedforward)

    return
end
