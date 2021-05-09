function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::DeviceModel{T, FixedOutput},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    nodal_expression!(optimization_container, devices, S)

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
    D <: AbstractStandardUnitCommitment,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices, D())
    add_variables!(optimization_container, ReactivePowerVariable, devices, D())
    add_variables!(optimization_container, OnVariable, devices, D())
    add_variables!(optimization_container, StartVariable, devices, D())
    add_variables!(optimization_container, StopVariable, devices, D())

    # Aux Variables
    add_variables!(optimization_container, TimeDurationON, devices, D())
    add_variables!(optimization_container, TimeDurationOFF, devices, D())

    # Initial Conditions
    initial_conditions!(optimization_container, devices, D())

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
    D <: AbstractStandardUnitCommitment,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices, D())
    add_variables!(optimization_container, OnVariable, devices, D())
    add_variables!(optimization_container, StartVariable, devices, D())
    add_variables!(optimization_container, StopVariable, devices, D())

    # Aux Variables
    add_variables!(optimization_container, TimeDurationON, devices, D())
    add_variables!(optimization_container, TimeDurationOFF, devices, D())

    # Initial Conditions
    initial_conditions!(optimization_container, devices, D())

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
    add_variables!(
        optimization_container,
        ActivePowerVariable,
        devices,
        ThermalBasicUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        ReactivePowerVariable,
        devices,
        ThermalBasicUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        OnVariable,
        devices,
        ThermalBasicUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        StartVariable,
        devices,
        ThermalBasicUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        StopVariable,
        devices,
        ThermalBasicUnitCommitment(),
    )

    # Initial Conditions
    initial_conditions!(optimization_container, devices, ThermalBasicUnitCommitment())

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
    add_variables!(
        optimization_container,
        ActivePowerVariable,
        devices,
        ThermalBasicUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        OnVariable,
        devices,
        ThermalBasicUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        StartVariable,
        devices,
        ThermalBasicUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        StopVariable,
        devices,
        ThermalBasicUnitCommitment(),
    )

    # Initial Conditions
    initial_conditions!(optimization_container, devices, ThermalBasicUnitCommitment())

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
    add_variables!(
        optimization_container,
        ActivePowerVariable,
        devices,
        ThermalRampLimited(),
    )
    add_variables!(
        optimization_container,
        ReactivePowerVariable,
        devices,
        ThermalRampLimited(),
    )

    # Initial Conditions
    initial_conditions!(optimization_container, devices, ThermalRampLimited())

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
    add_variables!(
        optimization_container,
        ActivePowerVariable,
        devices,
        ThermalRampLimited(),
    )

    # Initial Conditions
    initial_conditions!(optimization_container, devices, ThermalRampLimited())

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
    add_variables!(optimization_container, ActivePowerVariable, devices, D())
    add_variables!(optimization_container, ReactivePowerVariable, devices, D())

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
    add_variables!(optimization_container, ActivePowerVariable, devices, D())

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
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S};
    kwargs...,
) where {S <: PM.AbstractPowerModel}
    devices = PSY.get_components(PSY.ThermalMultiStart, sys)

    if !validate_available_devices(PSY.ThermalMultiStart, devices)
        return
    end

    # Variables
    add_variables!(
        optimization_container,
        ActivePowerVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        ReactivePowerVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        OnVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        StopVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        StartVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        ColdStartVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        WarmStartVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        HotStartVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )

    # Aux Variables
    add_variables!(
        optimization_container,
        TimeDurationON,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        TimeDurationOFF,
        devices,
        ThermalMultiStartUnitCommitment(),
    )

    # Initial Conditions
    initial_conditions!(optimization_container, devices, ThermalMultiStartUnitCommitment())

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
    ::Type{S},
) where {S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(PSY.ThermalMultiStart, sys)

    if !validate_available_devices(PSY.ThermalMultiStart, devices)
        return
    end

    # Variables
    add_variables!(
        optimization_container,
        ActivePowerVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        OnVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        StopVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        StartVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        ColdStartVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        WarmStartVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        HotStartVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )

    # Aux Variables
    add_variables!(optimization_container, TimeDurationON, devices, ThermalMultiStartUnitCommitment())
    add_variables!(optimization_container, TimeDurationOFF, devices, ThermalMultiStartUnitCommitment())

    # Initial Conditions
    initial_conditions!(optimization_container, devices, ThermalMultiStartUnitCommitment())

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
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(
        optimization_container,
        ActivePowerVariable,
        devices,
        ThermalCompactUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        ReactivePowerVariable,
        devices,
        ThermalCompactUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        OnVariable,
        devices,
        ThermalCompactUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        StartVariable,
        devices,
        ThermalCompactUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        StopVariable,
        devices,
        ThermalCompactUnitCommitment(),
    )

    # Aux Variables
    add_variables!(optimization_container, TimeDurationON, devices, ThermalCompactUnitCommitment())
    add_variables!(optimization_container, TimeDurationOFF, devices, ThermalCompactUnitCommitment())

    # Initial Conditions
    initial_conditions!(optimization_container, devices, ThermalCompactUnitCommitment())

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
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(
        optimization_container,
        ActivePowerVariable,
        devices,
        ThermalCompactUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        OnVariable,
        devices,
        ThermalCompactUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        StartVariable,
        devices,
        ThermalCompactUnitCommitment(),
    )
    add_variables!(
        optimization_container,
        StopVariable,
        devices,
        ThermalCompactUnitCommitment(),
    )

    # Aux Variables
    add_variables!(optimization_container, TimeDurationON, devices, ThermalCompactUnitCommitment())
    add_variables!(optimization_container, TimeDurationOFF, devices, ThermalCompactUnitCommitment())

    # Initial Conditions
    initial_conditions!(optimization_container, devices, ThermalCompactUnitCommitment())

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
    model::DeviceModel{T, ThermalCompactDispatch},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(
        optimization_container,
        ActivePowerVariable,
        devices,
        ThermalCompactDispatch(),
    )
    add_variables!(
        optimization_container,
        ReactivePowerVariable,
        devices,
        ThermalCompactDispatch(),
    )

    # Initial Conditions
    initial_conditions!(optimization_container, devices, ThermalCompactDispatch())

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
    model::DeviceModel{T, ThermalCompactDispatch},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(
        optimization_container,
        ActivePowerVariable,
        devices,
        ThermalCompactDispatch(),
    )

    # Initial Conditions
    initial_conditions!(optimization_container, devices, ThermalCompactDispatch())

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
