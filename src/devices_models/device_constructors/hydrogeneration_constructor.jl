"""
Construct model for HydroGen with FixedOutput Formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{H, FixedOutput},
    network_model::NetworkModel{S},
) where {H <: PSY.HydroGen, S <: PM.AbstractPowerModel}
    devices =
        get_available_components(H, sys, get_attribute(model, "filter_function"))

    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
    add_parameters!(container, ReactivePowerTimeSeriesParameter, devices, model)

    # Expression
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
    ::OptimizationContainer,
    ::PSY.System,
    ::ModelConstructStage,
    ::DeviceModel{H, FixedOutput},
    network_model::NetworkModel{S},
) where {H <: PSY.HydroGen, S <: PM.AbstractPowerModel}
    # FixedOutput doesn't add any constraints to the model. This function covers
    # AbstractPowerModel and AbstractActivePowerModel
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{H, FixedOutput},
    network_model::NetworkModel{S},
) where {H <: PSY.HydroGen, S <: PM.AbstractActivePowerModel}
    devices =
        get_available_components(H, sys, get_attribute(model, "filter_function"))

    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    # Expression
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

#=
"""
Construct model for HydroGen with RunOfRiver (default Hydro model) Dispatch Formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{H, D},
    network_model::NetworkModel{S},
) where {
    H <: PSY.HydroGen,
    D <: Union{HydroDispatchRunOfRiver, HydroCommitmentRunOfRiver},
    S <: PM.AbstractPowerModel,
}
    devices =
        get_available_components(H, sys, get_attribute(model, "filter_function"))

    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())
    add_variables!(container, EnergyOutput, devices, D())
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

    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    add_expressions!(container, ProductionCostExpression, devices, model)

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

    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{H, D},
    network_model::NetworkModel{S},
) where {
    H <: PSY.HydroGen,
    D <: Union{HydroDispatchRunOfRiver, HydroCommitmentRunOfRiver},
    S <: PM.AbstractPowerModel,
}
    devices =
        get_available_components(H, sys, get_attribute(model, "filter_function"))

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
=#

"""
Construct model for HydroGen with RunOfRiver (default Hydro model) Dispatch Formulation
with only Active Power.
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{H, D},
    network_model::NetworkModel{S},
) where {
    H <: PSY.HydroGen,
    D <: HydroDispatchRunOfRiver,
    S <: PM.AbstractActivePowerModel,
}
    devices =
        get_available_components(H, sys, get_attribute(model, "filter_function"))

    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, EnergyOutput, devices, D())
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        network_model,
    )

    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
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

    add_expressions!(container, ProductionCostExpression, devices, model)

    add_feedforward_arguments!(container, model, devices)
    return
end

#=
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{H, D},
    network_model::NetworkModel{S},
) where {
    H <: PSY.HydroGen,
    D <: HydroDispatchRunOfRiver,
    S <: PM.AbstractActivePowerModel,
}
    devices =
        get_available_components(H, sys, get_attribute(model, "filter_function"))

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

    add_feedforward_constraints!(container, model, devices)

    objective_function!(container, devices, model, S)

    add_constraint_dual!(container, sys, model)
    return
end
=#

"""
Construct model for HydroGen with RunOfRiver Commitment Formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{H, D},
    network_model::NetworkModel{S},
) where {H <: PSY.HydroGen, D <: HydroCommitmentRunOfRiver, S <: PM.AbstractPowerModel}
    devices =
        get_available_components(H, sys, get_attribute(model, "filter_function"))

    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())
    add_variables!(container, OnVariable, devices, D())
    add_variables!(container, EnergyOutput, devices, D())
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

    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    add_expressions!(container, ProductionCostExpression, devices, model)

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
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{H, D},
    network_model::NetworkModel{S},
) where {H <: PSY.HydroGen, D <: HydroCommitmentRunOfRiver, S <: PM.AbstractPowerModel}
    devices =
        get_available_components(H, sys, get_attribute(model, "filter_function"))

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

"""
Construct model for HydroGen with RunOfRiver Commitment Formulation
with only Active Power.
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{H, D},
    network_model::NetworkModel{S},
) where {
    H <: PSY.HydroGen,
    D <: HydroCommitmentRunOfRiver,
    S <: PM.AbstractActivePowerModel,
}
    devices =
        get_available_components(H, sys, get_attribute(model, "filter_function"))

    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, OnVariable, devices, D())
    add_variables!(container, EnergyOutput, devices, D())
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        network_model,
    )

    add_expressions!(container, ProductionCostExpression, devices, model)

    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
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

    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{H, D},
    network_model::NetworkModel{S},
) where {
    H <: PSY.HydroGen,
    D <: HydroCommitmentRunOfRiver,
    S <: PM.AbstractActivePowerModel,
}
    devices =
        get_available_components(H, sys, get_attribute(model, "filter_function"))

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

    add_feedforward_constraints!(container, model, devices)

    objective_function!(container, devices, model, S)

    add_constraint_dual!(container, sys, model)
    return
end
