function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    ::DeviceModel{T, FixedOutput},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    nodal_expression!(
        container,
        devices,
        ActivePowerTimeSeriesParameter(PSY.Deterministic, "max_active_power"),
    )
    add_constraint_dual!(container, sys, model)
end

"""
This function creates the arguments for the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractStandardUnitCommitment,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(T, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())
    add_variables!(container, OnVariable, devices, D())
    add_variables!(container, StartVariable, devices, D())
    add_variables!(container, StopVariable, devices, D())

    # Aux Variables
    add_variables!(container, TimeDurationOn, devices, D())
    add_variables!(container, TimeDurationOff, devices, D())

    # Initial Conditions
    initial_conditions!(container, devices, D())
end

"""
This function creates the constraints for the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractStandardUnitCommitment,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(T, sys)
    # Constraints
    # TODO DT: why aren't these passing variable and constraint instances?
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        CommitmentConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(container, RampConstraint, devices, model, S, get_feedforward(model))
    add_constraints!(
        container,
        DurationConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))
    add_constraint_dual!(container, sys, model)
end

"""
This function creates the arguments model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractStandardUnitCommitment,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(T, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, OnVariable, devices, D())
    add_variables!(container, StartVariable, devices, D())
    add_variables!(container, StopVariable, devices, D())

    # Aux Variables
    add_variables!(container, TimeDurationOn, devices, D())
    add_variables!(container, TimeDurationOff, devices, D())

    # Initial Conditions
    initial_conditions!(container, devices, D())
end

"""
This function creates the constraints for the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractStandardUnitCommitment,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(T, sys)
    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        CommitmentConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(container, RampConstraint, devices, model, S, get_feedforward(model))
    add_constraints!(
        container,
        DurationConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))
    add_constraint_dual!(container, sys, model)
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, ThermalBasicUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, ThermalBasicUnitCommitment())
    add_variables!(container, ReactivePowerVariable, devices, ThermalBasicUnitCommitment())
    add_variables!(container, OnVariable, devices, ThermalBasicUnitCommitment())
    add_variables!(container, StartVariable, devices, ThermalBasicUnitCommitment())
    add_variables!(container, StopVariable, devices, ThermalBasicUnitCommitment())

    # Initial Conditions
    initial_conditions!(container, devices, ThermalBasicUnitCommitment())
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, ThermalBasicUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    # Constraints
    # TODO: active_power_constraints
    # TODO: refactor constraints such that ALL variables for all devices are added first, and then the constraint creation is trigged
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        CommitmentConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))
    add_constraint_dual!(container, sys, model)
end

"""
This function creates the arguments for the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, ThermalBasicUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, ThermalBasicUnitCommitment())
    add_variables!(container, OnVariable, devices, ThermalBasicUnitCommitment())
    add_variables!(container, StartVariable, devices, ThermalBasicUnitCommitment())
    add_variables!(container, StopVariable, devices, ThermalBasicUnitCommitment())

    # Initial Conditions
    initial_conditions!(container, devices, ThermalBasicUnitCommitment())
end

"""
This function creates the constraints for the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, ThermalBasicUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        CommitmentConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))
    add_constraint_dual!(container, sys, model)
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, ThermalRampLimited},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, ThermalRampLimited())
    add_variables!(container, ReactivePowerVariable, devices, ThermalRampLimited())

    # Initial Conditions
    initial_conditions!(container, devices, ThermalRampLimited())
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, ThermalRampLimited},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(container, RampConstraint, devices, model, S, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))
    add_constraint_dual!(container, sys, model)
end

"""
This function creates the arguments for the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, ThermalRampLimited},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, ThermalRampLimited())

    # Initial Conditions
    initial_conditions!(container, devices, ThermalRampLimited())
end

"""
This function creates the constraints for the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, ThermalRampLimited},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(container, RampConstraint, devices, model, S, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))
    add_constraint_dual!(container, sys, model)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalDispatchFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(T, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalDispatchFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(T, sys)

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))
    add_constraint_dual!(container, sys, model)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalDispatchFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(T, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: AbstractThermalDispatchFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(T, sys)

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S};
    kwargs...,
) where {S <: PM.AbstractPowerModel}
    devices = PSY.get_components(PSY.ThermalMultiStart, sys)

    # Variables
    add_variables!(
        container,
        PowerAboveMinimumVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(
        container,
        ReactivePowerVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(container, OnVariable, devices, ThermalMultiStartUnitCommitment())
    add_variables!(container, StopVariable, devices, ThermalMultiStartUnitCommitment())
    add_variables!(container, StartVariable, devices, ThermalMultiStartUnitCommitment())
    add_variables!(container, ColdStartVariable, devices, ThermalMultiStartUnitCommitment())
    add_variables!(container, WarmStartVariable, devices, ThermalMultiStartUnitCommitment())
    add_variables!(container, HotStartVariable, devices, ThermalMultiStartUnitCommitment())

    # Aux Variables
    add_variables!(container, TimeDurationOn, devices, ThermalMultiStartUnitCommitment())
    add_variables!(container, TimeDurationOff, devices, ThermalMultiStartUnitCommitment())
    add_variables!(container, PowerOutput, devices, ThermalMultiStartUnitCommitment())
    # Initial Conditions
    initial_conditions!(container, devices, ThermalMultiStartUnitCommitment())
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S};
    kwargs...,
) where {S <: PM.AbstractPowerModel}
    devices = PSY.get_components(PSY.ThermalMultiStart, sys)

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        PowerAboveMinimumVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        CommitmentConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(container, RampConstraint, devices, model, S, get_feedforward(model))
    add_constraints!(
        container,
        DurationConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        StartupTimeLimitTemperatureConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        StartTypeConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        StartupInitialConditionConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        MustRunConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ActiveRangeICConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(container, devices, model, get_feedforward(model))
    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))
    add_constraint_dual!(container, sys, model)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S},
) where {S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(PSY.ThermalMultiStart, sys)

    # Variables
    add_variables!(
        container,
        PowerAboveMinimumVariable,
        devices,
        ThermalMultiStartUnitCommitment(),
    )
    add_variables!(container, OnVariable, devices, ThermalMultiStartUnitCommitment())
    add_variables!(container, StopVariable, devices, ThermalMultiStartUnitCommitment())
    add_variables!(container, StartVariable, devices, ThermalMultiStartUnitCommitment())
    add_variables!(container, ColdStartVariable, devices, ThermalMultiStartUnitCommitment())
    add_variables!(container, WarmStartVariable, devices, ThermalMultiStartUnitCommitment())
    add_variables!(container, HotStartVariable, devices, ThermalMultiStartUnitCommitment())

    # Aux Variables
    add_variables!(container, TimeDurationOn, devices, ThermalMultiStartUnitCommitment())
    add_variables!(container, TimeDurationOff, devices, ThermalMultiStartUnitCommitment())
    add_variables!(container, PowerOutput, devices, ThermalMultiStartUnitCommitment())
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    ::Type{S},
) where {S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(PSY.ThermalMultiStart, sys)

    # Initial Conditions
    initial_conditions!(container, devices, ThermalMultiStartUnitCommitment())

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        PowerAboveMinimumVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        CommitmentConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(container, RampConstraint, devices, model, S, get_feedforward(model))
    add_constraints!(
        container,
        DurationConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        StartupTimeLimitTemperatureConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        StartTypeConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        StartupInitialConditionConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        MustRunConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ActiveRangeICConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(container, devices, model, get_feedforward(model))
    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))
    add_constraint_dual!(container, sys, model)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, ThermalCompactUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(T, sys)

    # Variables
    add_variables!(
        container,
        PowerAboveMinimumVariable,
        devices,
        ThermalCompactUnitCommitment(),
    )
    add_variables!(
        container,
        ReactivePowerVariable,
        devices,
        ThermalCompactUnitCommitment(),
    )
    add_variables!(container, OnVariable, devices, ThermalCompactUnitCommitment())
    add_variables!(container, StartVariable, devices, ThermalCompactUnitCommitment())
    add_variables!(container, StopVariable, devices, ThermalCompactUnitCommitment())

    # Aux Variables
    add_variables!(container, TimeDurationOn, devices, ThermalCompactUnitCommitment())
    add_variables!(container, TimeDurationOff, devices, ThermalCompactUnitCommitment())
    add_variables!(container, PowerOutput, devices, ThermalCompactUnitCommitment())

    # Initial Conditions
    initial_conditions!(container, devices, ThermalCompactUnitCommitment())
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, ThermalCompactUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(T, sys)
    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        PowerAboveMinimumVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        CommitmentConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(container, RampConstraint, devices, model, S, get_feedforward(model))
    add_constraints!(
        container,
        DurationConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    feedforward!(container, devices, model, get_feedforward(model))
    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))
    add_constraint_dual!(container, sys, model)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, ThermalCompactUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(T, sys)

    # Variables
    add_variables!(
        container,
        PowerAboveMinimumVariable,
        devices,
        ThermalCompactUnitCommitment(),
    )
    add_variables!(container, OnVariable, devices, ThermalCompactUnitCommitment())
    add_variables!(container, StartVariable, devices, ThermalCompactUnitCommitment())
    add_variables!(container, StopVariable, devices, ThermalCompactUnitCommitment())

    # Aux Variables
    add_variables!(container, TimeDurationOn, devices, ThermalCompactUnitCommitment())
    add_variables!(container, TimeDurationOff, devices, ThermalCompactUnitCommitment())
    add_variables!(container, PowerOutput, devices, ThermalCompactUnitCommitment())

    # Initial Conditions
    initial_conditions!(container, devices, ThermalCompactUnitCommitment())
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, ThermalCompactUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(T, sys)
    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        PowerAboveMinimumVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        CommitmentConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(container, RampConstraint, devices, model, S, get_feedforward(model))
    add_constraints!(
        container,
        DurationConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(container, devices, model, get_feedforward(model))
    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))
    add_constraint_dual!(container, sys, model)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, ThermalCompactDispatch},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(T, sys)

    # Variables
    add_variables!(container, PowerAboveMinimumVariable, devices, ThermalCompactDispatch())
    add_variables!(container, ReactivePowerVariable, devices, ThermalCompactDispatch())

    # Aux Variables
    add_variables!(container, PowerOutput, devices, ThermalCompactDispatch())

    # Initial Conditions
    initial_conditions!(container, devices, ThermalCompactDispatch())
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, ThermalCompactDispatch},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    devices = PSY.get_components(T, sys)

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        PowerAboveMinimumVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(container, RampConstraint, devices, model, S, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))
    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))
    add_constraint_dual!(container, sys, model)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, ThermalCompactDispatch},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(T, sys)

    # Variables
    add_variables!(container, PowerAboveMinimumVariable, devices, ThermalCompactDispatch())

    # Aux Variables
    add_variables!(container, PowerOutput, devices, ThermalCompactDispatch())

    # Initial Conditions
    initial_conditions!(container, devices, ThermalCompactDispatch())
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, ThermalCompactDispatch},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = PSY.get_components(T, sys)

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        PowerAboveMinimumVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(container, RampConstraint, devices, model, S, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))
    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))
    add_constraint_dual!(container, sys, model)
end
