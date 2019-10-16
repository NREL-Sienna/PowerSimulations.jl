"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(op_model::OperationModel,
                           model::DeviceModel{T, D},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             D<:AbstractThermalFormulation,
                                             S<:PM.AbstractPowerModel}

    sys = get_system(op_model)

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(op_model.canonical, devices)

    reactivepower_variables!(op_model.canonical, devices)

    commitment_variables!(op_model.canonical, devices)

    #Initial Conditions

    initial_conditions!(op_model.canonical, devices, D)

    #Constraints
    activepower_constraints!(op_model.canonical, devices, D, S)

    reactivepower_constraints!(op_model.canonical, devices, D, S)

    commitment_constraints!(op_model.canonical, devices, D, S)

    ramp_constraints!(op_model.canonical, devices, D, S)

    time_constraints!(op_model.canonical, devices, D, S)

    feedforward!(op_model.canonical, T, model.feedforward)

    #Cost Function
    cost_function(op_model.canonical, devices, D, S)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(op_model::OperationModel,
                           model::DeviceModel{T, D},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             D<:AbstractThermalFormulation,
                                             S<:PM.AbstractActivePowerModel}

    sys = get_system(op_model)
    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(op_model.canonical, devices)

    commitment_variables!(op_model.canonical, devices)

    #Initial Conditions

    initial_conditions!(op_model.canonical, devices, D)

    #Constraints
    activepower_constraints!(op_model.canonical, devices, D, S)

    commitment_constraints!(op_model.canonical, devices, D, S)

    ramp_constraints!(op_model.canonical, devices, D, S)

    time_constraints!(op_model.canonical, devices, D, S)

    feedforward!(op_model.canonical, T, model.feedforward)

    #Cost Function
    cost_function(op_model.canonical, devices, D, S)

    return

end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(op_model::OperationModel,
                           model::DeviceModel{T, ThermalBasicUnitCommitment},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             S<:PM.AbstractPowerModel}

    sys = get_system(op_model)

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(op_model.canonical, devices)

    reactivepower_variables!(op_model.canonical, devices)

    commitment_variables!(op_model.canonical, devices)

    #Initial Conditions

    initial_conditions!(op_model.canonical, devices, model.formulation)

    #Constraints
    activepower_constraints!(op_model.canonical, devices, model.formulation, S)

    reactivepower_constraints!(op_model.canonical, devices, model.formulation, S)

    commitment_constraints!(op_model.canonical, devices, model.formulation, S)

    feedforward!(op_model.canonical, T, model.feedforward)

    #Cost Function
    cost_function(op_model.canonical, devices, model.formulation, S)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(op_model::OperationModel,
                           model::DeviceModel{T, ThermalBasicUnitCommitment},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             S<:PM.AbstractActivePowerModel}

    sys = get_system(op_model)

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(op_model.canonical, devices)

    commitment_variables!(op_model.canonical, devices)

    #Initial Conditions

    initial_conditions!(op_model.canonical, devices, model.formulation)

    #Constraints
    activepower_constraints!(op_model.canonical, devices, model.formulation, S)

    commitment_constraints!(op_model.canonical, devices, model.formulation, S)

    feedforward!(op_model.canonical, T, model.feedforward)

    #Cost Function
    cost_function(op_model.canonical, devices, model.formulation, S)

    return

end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(op_model::OperationModel,
                           model::DeviceModel{T, ThermalRampLimited},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             S<:PM.AbstractPowerModel}

    sys = get_system(op_model)

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(op_model.canonical, devices)

    reactivepower_variables!(op_model.canonical, devices)

    #Initial Conditions

    initial_conditions!(op_model.canonical, devices, model.formulation)

    #Constraints
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(op_model.canonical, devices, ThermalRampLimited, S)
    end

    reactivepower_constraints!(op_model.canonical, devices, model.formulation, S)

    ramp_constraints!(op_model.canonical, devices, model.formulation, S)

    feedforward!(op_model.canonical, T, model.feedforward)

    #Cost Function
    cost_function(op_model.canonical, devices, model.formulation, S)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(op_model::OperationModel,
                           model::DeviceModel{T, ThermalRampLimited},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             S<:PM.AbstractActivePowerModel}

    sys = get_system(op_model)

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(op_model.canonical, devices)

    #Initial Conditions

    initial_conditions!(op_model.canonical, devices, model.formulation)

    #Constraints
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(op_model.canonical, devices, ThermalRampLimited, S)
    end

    ramp_constraints!(op_model.canonical, devices, model.formulation, S)

    feedforward!(op_model.canonical, T, model.feedforward)

    #Cost Function
    cost_function(op_model.canonical, devices, model.formulation, S)

    return

end



function construct_device!(op_model::OperationModel,
                           model::DeviceModel{T, D},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             D<:AbstractThermalDispatchFormulation,
                                             S<:PM.AbstractPowerModel}

    sys = get_system(op_model)

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(op_model.canonical, devices)

    reactivepower_variables!(op_model.canonical, devices)

    #Initial Conditions

    #Constraints
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(op_model.canonical, devices, D, S)
    end

    reactivepower_constraints!(op_model.canonical, devices, D, S)

    feedforward!(op_model.canonical, T, model.feedforward)

    #Cost Function
    cost_function(op_model.canonical, devices, D, S)

    return

end

function construct_device!(op_model::OperationModel,
                           model::DeviceModel{T, D},
                           ::Type{S};
                           kwargs...) where {T<:PSY.ThermalGen,
                                             D<:AbstractThermalDispatchFormulation,
                                             S<:PM.AbstractActivePowerModel}

    sys = get_system(op_model)

    devices = PSY.get_components(T, sys)

    if validate_available_devices(devices, T)
        return
    end

    #Variables
    activepower_variables!(op_model.canonical, devices)

    #Initial Conditions

    #Constraints
    # Slighly hacky for now
    if !(isa(model.feedforward, SemiContinuousFF))
        activepower_constraints!(op_model.canonical, devices, D, S)
    end

    feedforward!(op_model.canonical, T, model.feedforward)

    #Cost Function
    cost_function(op_model.canonical, devices, D, S)

    return

end
