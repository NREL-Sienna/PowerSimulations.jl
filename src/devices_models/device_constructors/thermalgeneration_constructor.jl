function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{T, FixedOutput},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        S,
    )
end

function construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ModelConstructStage,
    ::DeviceModel{T, FixedOutput},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    # FixedOutput doesn't add any constraints to the model. This function covers
    # AbstractPowerModel and AbtractActivePowerModel
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

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerVariable,
        devices,
        model,
        S,
    )
    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
    end
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
    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerVariable,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    end
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

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        S,
    )

    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
    end
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
    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerVariable,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    end

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

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerVariable,
        devices,
        model,
        S,
    )
    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
    end
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
    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerVariable,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    end

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

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        S,
    )
    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
    end
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
    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerVariable,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    end

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

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerVariable,
        devices,
        model,
        S,
    )
    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
    end
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
    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerVariable,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    end

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

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        S,
    )
    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
    end
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
    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerVariable,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    end

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

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerVariable,
        devices,
        model,
        S,
    )
    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
    end
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
    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerVariable,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    end

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

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        S,
    )
    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            ActivePowerVariable,
            devices,
            model,
            S,
        )
    end
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
    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerVariable,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    end
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

    add_to_expression!(
        container,
        ActivePowerBalance,
        PowerAboveMinimumVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(container, ActivePowerBalance, OnVariable, devices, model, S)
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerVariable,
        devices,
        model,
        S,
    )
    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
        )
    end
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
    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    end

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

    add_to_expression!(
        container,
        ActivePowerBalance,
        PowerAboveMinimumVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(container, ActivePowerBalance, OnVariable, devices, model, S)
    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
        )
    end
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
    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    end
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

    add_to_expression!(
        container,
        ActivePowerBalance,
        PowerAboveMinimumVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(container, ActivePowerBalance, OnVariable, devices, model, S)
    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
        )
    end
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
    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    end
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

    add_to_expression!(
        container,
        ActivePowerBalance,
        PowerAboveMinimumVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(container, ActivePowerBalance, OnVariable, devices, model, S)
    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
        )
    end
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
    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    end
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

    # This isn't working properly since it isn't adding to the nodal expression the min power
    # we need to add an extra term to the expressions with the mins
    add_to_expression!(
        container,
        ActivePowerBalance,
        PowerAboveMinimumVariable,
        devices,
        model,
        S,
    )
    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
        )
    end
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
    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    end
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

    # This isn't working properly since it isn't adding to the nodal expression the min power
    # we need to add an extra term to the expressions with the mins
    add_to_expression!(
        container,
        ActivePowerBalance,
        PowerAboveMinimumVariable,
        devices,
        model,
        S,
    )

    # Initial Conditions
    initial_conditions!(container, devices, ThermalCompactDispatch())

    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
        )
    end
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
    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            PowerAboveMinimumVariable,
            devices,
            model,
            S,
            get_feedforward(model),
        )
    end
    add_constraints!(container, RampConstraint, devices, model, S, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))
    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))
    add_constraint_dual!(container, sys, model)
end
