function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.HybridSystem,
    D <: AbstractHybridFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(T, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())
    add_variables!(container, ActivePowerInVariable, devices, D())
    add_variables!(container, ActivePowerOutVariable, devices, D())
    add_variables!(container, ComponentActivePowerVariable, devices, D())
    add_variables!(container, EnergyVariable, devices, D())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, D())
    end

    # Parameters
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

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
        ComponentActivePowerRangeExpressionLB,
        ComponentActivePowerVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ComponentActivePowerRangeExpressionUB,
        ComponentActivePowerVariable,
        devices,
        model,
        S,
    )
    add_feedforward_arguments!(container, model, devices)

    if has_service_model(model)
        add_variables!(container, ComponentActivePowerReserveUpVariable, devices, D())
        add_variables!(container, ComponentActivePowerReserveDownVariable, devices, D())

        add_to_expression!(
            container,
            ComponentActivePowerRangeExpressionLB,
            ComponentActivePowerReserveDownVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ComponentActivePowerRangeExpressionUB,
            ComponentActivePowerReserveUpVariable,
            devices,
            model,
            S,
        )
        add_expressions!(container, ComponentReserveDownBalanceExpression, devices, model)
        add_expressions!(container, ComponentReserveUpBalanceExpression, devices, model)
    end
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.HybridSystem,
    D <: AbstractHybridFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(T, sys)

    # Constraints
    #TODO: Change to Expressions for Services support
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        ComponentActivePowerVariableLimitsConstraint,
        ComponentActivePowerRangeExpressionLB,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        ComponentActivePowerVariableLimitsConstraint,
        ComponentActivePowerRangeExpressionUB,
        devices,
        model,
        S,
    )

    add_constraints!(container, EnergyBalanceConstraint, devices, model, S)
    add_constraints!(container, PowerOutputRangeConstraint, devices, model, S)

    if has_service_model(model)
        add_constraints!(container, ReserveEnergyConstraint, devices, model, S)
        add_constraints!(container, RangeLimitConstraint, devices, model, S)
        add_constraints!(container, ComponentReserveUpBalance, devices, model, S)
        add_constraints!(container, ComponentReserveDownBalance, devices, model, S)
    end

    add_feedforward_constraints!(container, model, devices)

    # Cost Function
    objective_function!(container, devices, model, S)

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {T <: PSY.HybridSystem, D <: AbstractHybridFormulation, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ActivePowerInVariable, devices, D())
    add_variables!(container, ActivePowerOutVariable, devices, D())
    add_variables!(container, ComponentActivePowerVariable, devices, D())
    add_variables!(container, EnergyVariable, devices, D())

    add_variables!(container, ReactivePowerVariable, devices, D())
    add_variables!(container, ComponentReactivePowerVariable, devices, D())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, D())
    end

    # Parameters
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

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
    add_to_expression!(
        container,
        ComponentActivePowerRangeExpressionLB,
        ComponentActivePowerVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ComponentActivePowerRangeExpressionUB,
        ComponentActivePowerVariable,
        devices,
        model,
        S,
    )

    add_feedforward_arguments!(container, model, devices)

    if has_service_model(model)
        add_variables!(container, ComponentActivePowerReserveUpVariable, devices, D())
        add_variables!(container, ComponentActivePowerReserveDownVariable, devices, D())
        add_to_expression!(
            container,
            ComponentActivePowerRangeExpressionLB,
            ComponentActivePowerReserveDownVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ComponentActivePowerRangeExpressionUB,
            ComponentActivePowerReserveUpVariable,
            devices,
            model,
            S,
        )
        add_expressions!(container, ComponentReserveDownBalanceExpression, devices, model)
        add_expressions!(container, ComponentReserveUpBalanceExpression, devices, model)
    end
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {T <: PSY.HybridSystem, D <: AbstractHybridFormulation, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        ComponentActivePowerVariableLimitsConstraint,
        ComponentActivePowerRangeExpressionLB,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        ComponentActivePowerVariableLimitsConstraint,
        ComponentActivePowerRangeExpressionUB,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )

    # Reactive power Constraints
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        ComponentReactivePowerVariableLimitsConstraint,
        ComponentReactivePowerVariable,
        devices,
        model,
        S,
    )

    # Constraints
    add_constraints!(container, EnergyBalanceConstraint, devices, model, S)
    add_constraints!(container, PowerOutputRangeConstraint, devices, model, S)
    add_constraints!(container, ReactivePowerConstraint, devices, model, S)
    add_constraints!(container, InterConnectionLimitConstraint, devices, model, S)
    if has_service_model(model)
        add_constraints!(container, ReserveEnergyConstraint, devices, model, S)
        add_constraints!(container, RangeLimitConstraint, devices, model, S)
        add_constraints!(container, ComponentReserveUpBalance, devices, model, S)
        add_constraints!(container, ComponentReserveDownBalance, devices, model, S)
    end
    add_feedforward_constraints!(container, model, devices)

    # Cost Function
    objective_function!(container, devices, model, S)

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.HybridSystem,
    D <: StandardHybridDispatch,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(T, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())
    add_variables!(container, ActivePowerInVariable, devices, D())
    add_variables!(container, ActivePowerOutVariable, devices, D())
    add_variables!(container, ComponentActivePowerVariable, devices, D())
    add_variables!(container, EnergyVariable, devices, D())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, D())
    end

    # Parameters
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

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
        ComponentActivePowerRangeExpressionLB,
        ComponentActivePowerVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ComponentActivePowerRangeExpressionUB,
        ComponentActivePowerVariable,
        devices,
        model,
        S,
    )

    add_feedforward_arguments!(container, model, devices)

    if has_service_model(model)
        add_variables!(container, ComponentActivePowerReserveUpVariable, devices, D())
        add_variables!(container, ComponentActivePowerReserveDownVariable, devices, D())
        add_to_expression!(
            container,
            ComponentActivePowerRangeExpressionLB,
            ComponentActivePowerReserveDownVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ComponentActivePowerRangeExpressionUB,
            ComponentActivePowerReserveUpVariable,
            devices,
            model,
            S,
        )
        add_expressions!(container, ComponentReserveDownBalanceExpression, devices, model)
        add_expressions!(container, ComponentReserveUpBalanceExpression, devices, model)
    end
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.HybridSystem,
    D <: StandardHybridDispatch,
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
    )
    add_constraints!(
        container,
        ComponentActivePowerVariableLimitsConstraint,
        ComponentActivePowerRangeExpressionLB,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        ComponentActivePowerVariableLimitsConstraint,
        ComponentActivePowerRangeExpressionUB,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )

    add_constraints!(container, EnergyBalanceConstraint, devices, model, S)
    add_constraints!(container, PowerOutputRangeConstraint, devices, model, S)

    if has_service_model(model)
        add_constraints!(container, ReserveEnergyConstraint, devices, model, S)
        add_constraints!(container, RangeLimitConstraint, devices, model, S)
        add_constraints!(container, ComponentReserveUpBalance, devices, model, S)
        add_constraints!(container, ComponentReserveDownBalance, devices, model, S)
    end

    add_feedforward_constraints!(container, model, devices)

    # Cost Function
    objective_function!(container, devices, model, S)

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {T <: PSY.HybridSystem, D <: StandardHybridDispatch, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ActivePowerInVariable, devices, D())
    add_variables!(container, ActivePowerOutVariable, devices, D())
    add_variables!(container, ComponentActivePowerVariable, devices, D())
    add_variables!(container, EnergyVariable, devices, D())

    add_variables!(container, ReactivePowerVariable, devices, D())
    add_variables!(container, ComponentReactivePowerVariable, devices, D())
    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, D())
    end

    # Parameters
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

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
    add_to_expression!(
        container,
        ComponentActivePowerRangeExpressionLB,
        ComponentActivePowerVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ComponentActivePowerRangeExpressionUB,
        ComponentActivePowerVariable,
        devices,
        model,
        S,
    )

    add_feedforward_arguments!(container, model, devices)

    if has_service_model(model)
        add_variables!(container, ComponentActivePowerReserveUpVariable, devices, D())
        add_variables!(container, ComponentActivePowerReserveDownVariable, devices, D())
        add_to_expression!(
            container,
            ComponentActivePowerRangeExpressionLB,
            ComponentActivePowerReserveDownVariable,
            devices,
            model,
            S,
        )
        add_to_expression!(
            container,
            ComponentActivePowerRangeExpressionUB,
            ComponentActivePowerReserveUpVariable,
            devices,
            model,
            S,
        )
        add_expressions!(container, ComponentReserveDownBalanceExpression, devices, model)
        add_expressions!(container, ComponentReserveUpBalanceExpression, devices, model)
    end
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, D},
    ::Type{S},
) where {T <: PSY.HybridSystem, D <: StandardHybridDispatch, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)
    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        ComponentActivePowerVariableLimitsConstraint,
        ComponentActivePowerRangeExpressionLB,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        ComponentActivePowerVariableLimitsConstraint,
        ComponentActivePowerRangeExpressionUB,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
    )

    # Reactive power Constraints
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
    )
    add_constraints!(
        container,
        ComponentReactivePowerVariableLimitsConstraint,
        ComponentReactivePowerVariable,
        devices,
        model,
        S,
    )

    # Constraints
    add_constraints!(container, EnergyBalanceConstraint, devices, model, S)
    add_constraints!(container, PowerOutputRangeConstraint, devices, model, S)
    add_constraints!(container, ReactivePowerConstraint, devices, model, S)
    add_constraints!(container, InterConnectionLimitConstraint, devices, model, S)

    if has_service_model(model)
        add_constraints!(container, ReserveEnergyConstraint, devices, model, S)
        add_constraints!(container, RangeLimitConstraint, devices, model, S)
        add_constraints!(container, ComponentReserveUpBalance, devices, model, S)
        add_constraints!(container, ComponentReserveDownBalance, devices, model, S)
    end

    add_feedforward_constraints!(container, model, devices)

    # Cost Function
    objective_function!(container, devices, model, S)

    return
end
