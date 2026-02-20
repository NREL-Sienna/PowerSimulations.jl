"""
Check whether any Source device has a specific named time series, so that we can skip adding
time series parameters when the defaults are populated but the devices lack the data.
Unlike most other components, Source devices may have cost time series without having
power limit time series, so a generic `has_time_series` check is insufficient.
"""
function _has_source_ts(
    container::OptimizationContainer,
    model::DeviceModel,
    devices,
    ::Type{P},
) where {P <: TimeSeriesParameter}
    ts_names = get_time_series_names(model)
    haskey(ts_names, P) || return false
    ts_name = ts_names[P]
    ts_type = get_default_time_series_type(container)
    return any(d -> PSY.has_time_series(d, ts_type, ts_name), devices)
end

"""
This function creates the arguments for the model for an import/export formulation for Source devices
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, D},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {
    T <: PSY.Source,
    D <: ImportExportSourceModel,
}
    devices = get_available_components(model, sys)

    add_variables!(container, ActivePowerInVariable, devices, D())
    add_variables!(container, ActivePowerOutVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())
    add_expressions!(container, NetActivePower, devices, model)

    if _has_source_ts(container, model, devices, ActivePowerOutTimeSeriesParameter)
        add_parameters!(container, ActivePowerOutTimeSeriesParameter, devices, model)
    end
    if _has_source_ts(container, model, devices, ActivePowerInTimeSeriesParameter)
        add_parameters!(container, ActivePowerInTimeSeriesParameter, devices, model)
    end

    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, D())
    end

    process_import_export_parameters!(container, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerOutVariable,
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

    add_expressions!(container, ProductionCostExpression, devices, model)

    add_to_expression!(
        container,
        ActivePowerRangeExpressionLB,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerRangeExpressionUB,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )

    add_feedforward_arguments!(container, model, devices)
    return
end

"""
This function creates the constraints for the model for an import/export formulation for Source devices
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, D},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {
    T <: PSY.Source,
    D <: ImportExportSourceModel,
}
    devices = get_available_components(model, sys)

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
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_constraints!(container, ImportExportBudgetConstraint, devices, model, network_model)

    if _has_source_ts(container, model, devices, ActivePowerOutTimeSeriesParameter)
        add_constraints!(
            container,
            ActivePowerOutVariableTimeSeriesLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            network_model,
        )
    end
    if _has_source_ts(container, model, devices, ActivePowerInTimeSeriesParameter)
        add_constraints!(
            container,
            ActivePowerInVariableTimeSeriesLimitsConstraint,
            ActivePowerInVariable,
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

"""
This function creates the arguments for the model for an import/export formulation for Source devices
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, D},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {
    T <: PSY.Source,
    D <: ImportExportSourceModel,
}
    devices = get_available_components(model, sys)

    add_variables!(container, ActivePowerInVariable, devices, D())
    add_variables!(container, ActivePowerOutVariable, devices, D())
    add_expressions!(container, NetActivePower, devices, model)

    if _has_source_ts(container, model, devices, ActivePowerOutTimeSeriesParameter)
        add_parameters!(container, ActivePowerOutTimeSeriesParameter, devices, model)
    end
    if _has_source_ts(container, model, devices, ActivePowerInTimeSeriesParameter)
        add_parameters!(container, ActivePowerInTimeSeriesParameter, devices, model)
    end

    if get_attribute(model, "reservation")
        add_variables!(container, ReservationVariable, devices, D())
    end

    process_import_export_parameters!(container, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )

    add_to_expression!(
        container,
        NetActivePower,
        ActivePowerInVariable(),
        devices,
        model,
    )
    add_to_expression!(
        container,
        NetActivePower,
        ActivePowerOutVariable(),
        devices,
        model,
    )

    add_expressions!(container, ProductionCostExpression, devices, model)

    add_to_expression!(
        container,
        ActivePowerRangeExpressionLB,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerRangeExpressionUB,
        ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )

    add_feedforward_arguments!(container, model, devices)
    return
end

"""
This function creates the constraints for the model for an import/export formulation for Source devices
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, D},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {
    T <: PSY.Source,
    D <: ImportExportSourceModel,
}
    devices = get_available_components(model, sys)

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
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        network_model,
    )

    add_constraints!(container, ImportExportBudgetConstraint, devices, model, network_model)

    if _has_source_ts(container, model, devices, ActivePowerOutTimeSeriesParameter)
        add_constraints!(
            container,
            ActivePowerOutVariableTimeSeriesLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            network_model,
        )
    end
    if _has_source_ts(container, model, devices, ActivePowerInTimeSeriesParameter)
        add_constraints!(
            container,
            ActivePowerInVariableTimeSeriesLimitsConstraint,
            ActivePowerInVariable,
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
