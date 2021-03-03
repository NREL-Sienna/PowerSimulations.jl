"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalUnitCommitment,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)
    add_variables!(optimization_container, ReactivePowerVariable, devices)
    add_variables!(optimization_container, OnVariable, devices)
    add_variables!(optimization_container, StartVariable, devices)
    add_variables!(optimization_container, StopVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, D)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commitment_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    ramp_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    time_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalUnitCommitment,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)
    add_variables!(optimization_container, OnVariable, devices)
    add_variables!(optimization_container, StartVariable, devices)
    add_variables!(optimization_container, StopVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, D)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commitment_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    ramp_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    time_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalBasicUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)
    add_variables!(optimization_container, ReactivePowerVariable, devices)
    add_variables!(optimization_container, OnVariable, devices)
    add_variables!(optimization_container, StartVariable, devices)
    add_variables!(optimization_container, StopVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    # TODO: active_power_constraints
    # TODO: refactor constraints such that ALL variables for all devices are added first, and then the constraint creation is trigged
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commitment_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalBasicUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)
    add_variables!(optimization_container, OnVariable, devices)
    add_variables!(optimization_container, StartVariable, devices)
    add_variables!(optimization_container, StopVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commitment_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalRampLimited},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)
    add_variables!(optimization_container, ReactivePowerVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    ramp_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalRampLimited},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    ramp_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
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

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)
    add_variables!(optimization_container, ReactivePowerVariable, devices)

    # Initial Conditions

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
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

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)

    # Initial Conditions

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, FixedOutput},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    nodal_expression!(optimization_container, devices, S)

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S};
    kwargs...,
) where {S <: PM.AbstractPowerModel}
    devices = PSY.get_components(PSY.ThermalMultiStart, sys)

    if !validate_available_devices(PSY.ThermalMultiStart, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)
    add_variables!(optimization_container, ReactivePowerVariable, devices)
    commitment_variables!(optimization_container, devices)
    add_variables!(optimization_container, ColdStartVariable, devices)
    add_variables!(optimization_container, WarmStartVariable, devices)
    add_variables!(optimization_container, HotStartVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commitment_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    ramp_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    time_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    startup_time_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    startup_type_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    startup_initial_condition_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    must_run_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    initial_range_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))
    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S};,
) where {S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(PSY.ThermalMultiStart, sys)

    if !validate_available_devices(PSY.ThermalMultiStart, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)
    commitment_variables!(optimization_container, devices)
    add_variables!(optimization_container, ColdStartVariable, devices)
    add_variables!(optimization_container, WarmStartVariable, devices)
    add_variables!(optimization_container, HotStartVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commitment_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    ramp_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    time_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    startup_time_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    startup_type_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    startup_initial_condition_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    must_run_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    initial_range_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))
    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalCompactUnitCommitment},
    ::Type{S};,
) where {T <: PSY.ThermalMultiStart, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)
    add_variables!(optimization_container, ReactivePowerVariable, devices)
    commitment_variables!(optimization_container, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commitment_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    ramp_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    time_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    initial_range_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))
    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalCompactUnitCommitment},
    ::Type{S};,
) where {T <: PSY.ThermalMultiStart, S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)
    commitment_variables!(optimization_container, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commitment_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    ramp_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    time_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    initial_range_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))
    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalCompactUnitCommitment},
    ::Type{S};,
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)
    add_variables!(optimization_container, ReactivePowerVariable, devices)
    commitment_variables!(optimization_container, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commitment_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    ramp_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    time_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    feedforward!(optimization_container, devices, model, get_feedforward(model))
    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, ThermalCompactUnitCommitment},
    ::Type{S};,
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)
    commitment_variables!(optimization_container, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commitment_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    ramp_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    time_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    feedforward!(optimization_container, devices, model, get_feedforward(model))
    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S};,
) where {T <: PSY.ThermalGen, D <: ThermalCompactDispatch, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)
    add_variables!(optimization_container, ReactivePowerVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    ramp_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    feedforward!(optimization_container, devices, model, get_feedforward(model))
    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S};,
) where {T <: PSY.ThermalGen, D <: ThermalCompactDispatch, S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    ramp_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    feedforward!(optimization_container, devices, model, get_feedforward(model))
    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end
