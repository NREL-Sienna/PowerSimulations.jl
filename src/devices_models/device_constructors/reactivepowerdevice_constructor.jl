function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{R, D},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {
    R <: PSY.SynchronousCondenser,
    D <: AbstractReactivePowerDeviceFormulation,
}
    devices = get_available_components(model, sys)
    add_variables!(container, ReactivePowerVariable, devices, D())
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_feedforward_arguments!(container, model, devices)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{R, D},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {
    R <: PSY.SynchronousCondenser,
    D <: AbstractReactivePowerDeviceFormulation,
}
    devices = get_available_components(model, sys)
    # No constraints
    # Add FFs
    add_feedforward_constraints!(container, model, devices)
    # No objective function
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{R, D},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {
    R <: PSY.SynchronousCondenser,
    D <: AbstractReactivePowerDeviceFormulation,
}
    # Do Nothing in Active Power Only Models
    return
end
