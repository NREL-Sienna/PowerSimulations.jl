function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{L, D},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {
    L <: PSY.ControllableLoad,
    D <: AbstractControllablePowerLoadFormulation,
}
    devices =
        get_available_components(L, sys, get_attribute(model, "filter_function"))

    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())

    # Add Variables to expressions
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
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{L, <:AbstractControllablePowerLoadFormulation},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {L <: PSY.ControllableLoad}
    devices =
        get_available_components(L, sys, get_attribute(model, "filter_function"))

    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
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

    objective_function!(container, devices, model, get_network_formulation(network_model))

    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{L, D},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {
    L <: PSY.ControllableLoad,
    D <: AbstractControllablePowerLoadFormulation,
}
    devices =
        get_available_components(L, sys, get_attribute(model, "filter_function"))

    add_variables!(container, ActivePowerVariable, devices, D())

    # Add Variables to expressions
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        network_model,
    )

    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    add_expressions!(container, ProductionCostExpression, devices, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{L, <:AbstractControllablePowerLoadFormulation},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {L <: PSY.ControllableLoad}
    devices =
        get_available_components(L, sys, get_attribute(model, "filter_function"))

    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
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
    ::ArgumentConstructStage,
    model::DeviceModel{L, PowerLoadInterruption},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {L <: PSY.ControllableLoad}
    devices =
        get_available_components(L, sys, get_attribute(model, "filter_function"))

    add_variables!(container, ActivePowerVariable, devices, PowerLoadInterruption())
    add_variables!(container, ReactivePowerVariable, devices, PowerLoadInterruption())
    add_variables!(container, OnVariable, devices, PowerLoadInterruption())

    # Add Variables to expressions
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
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{L, PowerLoadInterruption},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {L <: PSY.ControllableLoad}
    devices =
        get_available_components(L, sys, get_attribute(model, "filter_function"))

    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
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

    objective_function!(container, devices, model, get_network_formulation(network_model))

    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{L, PowerLoadInterruption},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {L <: PSY.ControllableLoad}
    devices =
        get_available_components(L, sys, get_attribute(model, "filter_function"))

    add_variables!(container, ActivePowerVariable, devices, PowerLoadInterruption())
    add_variables!(container, OnVariable, devices, PowerLoadInterruption())

    # Add Variables to expressions
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        network_model,
    )

    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    add_expressions!(container, ProductionCostExpression, devices, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{L, PowerLoadInterruption},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {L <: PSY.ControllableLoad}
    devices =
        get_available_components(L, sys, get_attribute(model, "filter_function"))

    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
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
    ::ArgumentConstructStage,
    model::DeviceModel{L, StaticPowerLoad},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {L <: PSY.ElectricLoad}
    devices =
        get_available_components(L, sys, get_attribute(model, "filter_function"))

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
    model::DeviceModel{L, StaticPowerLoad},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {L <: PSY.ElectricLoad}
    devices =
        get_available_components(L, sys, get_attribute(model, "filter_function"))

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
    model::DeviceModel{<:PSY.ElectricLoad, StaticPowerLoad},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
)
    # Static PowerLoad doesn't add any constraints to the model. This function covers
    # AbstractPowerModel and AbtractActivePowerModel
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{L, <:AbstractControllablePowerLoadFormulation},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {L <: PSY.StaticLoad}
    devices =
        get_available_components(L, sys, get_attribute(model, "filter_function"))

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
    model::DeviceModel{L, <:AbstractControllablePowerLoadFormulation},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {L <: PSY.StaticLoad}
    devices =
        get_available_components(L, sys, get_attribute(model, "filter_function"))

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
    ccs::ModelConstructStage,
    model::DeviceModel{L, D},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {
    L <: PSY.StaticLoad,
    D <: AbstractControllablePowerLoadFormulation,
}
    if D != StaticPowerLoad
        @warn(
            "The Formulation $(D) only applies to FormulationControllable Loads, \n Consider Changing the Device Formulation to StaticPowerLoad"
        )
    end

    # Makes a new model with the correct formulation of the type. Needs to recover all the other fields
    # slacks, services and duals are not applicable to StaticPowerLoad so those are ignored
    new_model = DeviceModel(
        L,
        StaticPowerLoad;
        feedforwards = model.feedforwards,
        time_series_names = model.time_series_names,
        attributes = model.attributes,
    )
    construct_device!(container, sys, ccs, new_model, network_model)
    return
end
