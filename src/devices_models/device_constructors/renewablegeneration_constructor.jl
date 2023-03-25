function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{R, D},
    network_model::NetworkModel{S},
) where {
    R <: PSY.RenewableGen,
    D <: AbstractRenewableDispatchFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(R, sys)

    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())

    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    add_expressions!(container, ProductionCostExpression, devices, model)

    # Expression
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerVariable,
        devices,
        model,
        network_model,
    )
    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            ActivePowerVariable,
            devices,
            model,
            network_model,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            ActivePowerVariable,
            devices,
            model,
            network_model,
        )
    end
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{R, D},
    network_model::NetworkModel{S},
) where {
    R <: PSY.RenewableGen,
    D <: AbstractRenewableDispatchFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(R, sys)

    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            network_model,
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerVariable,
            devices,
            model,
            network_model,
        )
    end

    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_feedforward_constraints!(container, model, devices)

    objective_function!(container, devices, model, S)

    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{R, D},
    network_model::NetworkModel{S},
) where {
    R <: PSY.RenewableGen,
    D <: AbstractRenewableDispatchFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(R, sys)

    add_variables!(container, ActivePowerVariable, devices, D())

    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    add_expressions!(container, ProductionCostExpression, devices, model)

    # Expression
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        network_model,
    )
    if has_service_model(model)
        add_to_expression!(
            container,
            ActivePowerRangeExpressionLB,
            ActivePowerVariable,
            devices,
            model,
            network_model,
        )
        add_to_expression!(
            container,
            ActivePowerRangeExpressionUB,
            ActivePowerVariable,
            devices,
            model,
            network_model,
        )
    end
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{R, D},
    network_model::NetworkModel{S},
) where {
    R <: PSY.RenewableGen,
    D <: AbstractRenewableDispatchFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(R, sys)

    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            network_model,
        )
    else
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerVariable,
            devices,
            model,
            network_model,
        )
    end
    add_feedforward_constraints!(container, model, devices)

    objective_function!(container, devices, model, S)

    add_constraint_dual!(container, sys, model)

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{R, FixedOutput},
    network_model::NetworkModel{S},
) where {R <: PSY.RenewableGen, S <: PM.AbstractPowerModel}
    devices = get_available_components(R, sys)

    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
    add_parameters!(container, ReactivePowerTimeSeriesParameter, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerTimeSeriesParameter,
        devices,
        model,
        network_model,
    )
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{R, FixedOutput},
    network_model::NetworkModel{S},
) where {R <: PSY.RenewableGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(R, sys)

    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        network_model,
    )
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{R, FixedOutput},
    network_model::NetworkModel{S},
) where {R <: PSY.RenewableGen, S <: PM.AbstractPowerModel}
    # FixedOutput doesn't add any constraints to the model. This function covers
    # AbstractPowerModel and AbtractActivePowerModel
    return
end
