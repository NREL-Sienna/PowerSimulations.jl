function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.InterconnectingConverter, LossLessConverter},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
)
    devices = get_available_components(PSY.InterconnectingConverter, sys)
    add_variables!(container, ActivePowerVariable, devices, LossLessConverter())
    add_to_expression!(
        container,
        ActivePowerBalance,
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
    model::DeviceModel{PSY.InterconnectingConverter, LossLessConverter},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
)
    devices = get_available_components(PSY.InterconnectingConverter, sys)
    add_feedforward_constraints!(container, model, devices)
    objective_function!(container, devices, model, get_network_formulation(network_model))
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.TModelHVDCLine, LossLessLine},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
)
    devices = get_available_components(PSY.TModelHVDCLine, sys)
    add_variables!(container, FlowActivePowerVariable, devices, LossLessLine())
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    ::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.TModelHVDCLine, LossLessLine},
    ::NetworkModel{<:PM.AbstractActivePowerModel},
)
end
