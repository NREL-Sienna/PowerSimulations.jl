function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::IS.ArgumentConstructStage,
    model::DeviceModel{R, D},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {
    R <: PSY.RenewableGen,
    D <: AbstractRenewableDispatchFormulation,
}
    devices =
        get_available_components(model, sys)

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
    ::IS.ModelConstructStage,
    model::DeviceModel{R, <:AbstractRenewableDispatchFormulation},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {R <: PSY.RenewableGen}
    devices =
        get_available_components(model, sys)

    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            network_model,
        )
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

    objective_function!(container, devices, model, get_network_formulation(network_model))

    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::IS.ArgumentConstructStage,
    model::DeviceModel{R, D},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {
    R <: PSY.RenewableGen,
    D <: AbstractRenewableDispatchFormulation,
}
    devices =
        get_available_components(model, sys)

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
    ::IS.ModelConstructStage,
    model::DeviceModel{R, <:AbstractRenewableDispatchFormulation},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {R <: PSY.RenewableGen}
    devices =
        get_available_components(model, sys)

    if has_service_model(model)
        add_constraints!(
            container,
            ActivePowerVariableLimitsConstraint,
            ActivePowerRangeExpressionLB,
            devices,
            model,
            network_model,
        )
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

    objective_function!(container, devices, model, get_network_formulation(network_model))

    add_constraint_dual!(container, sys, model)

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::IS.ArgumentConstructStage,
    model::DeviceModel{R, FixedOutput},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {R <: PSY.RenewableGen}
    devices =
        get_available_components(model, sys)

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
    ::IS.ArgumentConstructStage,
    model::DeviceModel{R, FixedOutput},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {R <: PSY.RenewableGen}
    devices =
        get_available_components(model, sys)

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
    ::IS.ModelConstructStage,
    model::DeviceModel{<:PSY.RenewableGen, FixedOutput},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
)
    # FixedOutput doesn't add any constraints to the model. This function covers
    # AbstractPowerModel and AbtractActivePowerModel
    return
end
