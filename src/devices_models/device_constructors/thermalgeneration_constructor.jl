"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S},
) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    reactivepower_variables!(psi_container, devices)
    commitment_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, D)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    reactivepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    commitment_constraints!(psi_container, devices, model, S, get_feedforward(model))
    ramp_constraints!(psi_container, devices, model, S, get_feedforward(model))
    time_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    commitment_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, D)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    commitment_constraints!(psi_container, devices, model, S, get_feedforward(model))
    ramp_constraints!(psi_container, devices, model, S, get_feedforward(model))
    time_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalBasicUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    reactivepower_variables!(psi_container, devices)
    commitment_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    reactivepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    commitment_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalBasicUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    commitment_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    commitment_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalRampLimited},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    reactivepower_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    reactivepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    ramp_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalRampLimited},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    ramp_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S, get_feedforward(model))

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalDispatchFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)
    reactivepower_variables!(psi_container, devices)

    #Initial Conditions

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    reactivepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S, get_feedforward(model))

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalDispatchFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices)

    #Initial Conditions

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    #Cost Function
    cost_function(psi_container, devices, D, S, get_feedforward(model))

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, FixedOutput},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    nodal_expression!(psi_container, devices, S)

    return
end
