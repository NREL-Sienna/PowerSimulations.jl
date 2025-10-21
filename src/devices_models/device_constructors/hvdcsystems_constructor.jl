function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.InterconnectingConverter, LossLessConverter},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
)
    devices = get_available_components(
        model,
        sys,
    )
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
    devices = get_available_components(
        model,
        sys,
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
    model::DeviceModel{PSY.InterconnectingConverter, QuadraticLossConverter},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
)
    devices = get_available_components(
        model,
        sys,
    )
    #####################
    ##### Variables #####
    #####################

    # Add Power Variable
    add_variables!(container, ActivePowerVariable, devices, QuadraticLossConverter()) # p_c^{ac}
    #add_variables!(container, ConverterDCPower, devices, QuadraticLossConverter()) # p_c
    add_variables!(container, ConverterPowerDirection, devices, QuadraticLossConverter()) #κ
    # Add Current Variables: i, δ^i, z^i, i+, i-
    add_variables!(container, ConverterCurrent, devices, QuadraticLossConverter()) # i
    add_variables!(container, SquaredConverterCurrent, devices, QuadraticLossConverter()) # i^sq
    add_variables!(
        container,
        InterpolationSquaredCurrentVariable,
        devices,
        QuadraticLossConverter(),
    ) # δ^i
    add_variables!(
        container,
        InterpolationBinarySquaredCurrentVariable,
        devices,
        QuadraticLossConverter(),
    ) #  z^i
    add_variables!(container, ConverterPositiveCurrent, devices, QuadraticLossConverter()) # i^+
    add_variables!(container, ConverterNegativeCurrent, devices, QuadraticLossConverter()) # i^- 
    add_variables!(
        container,
        ConverterBinaryAbsoluteValueCurrent,
        devices,
        QuadraticLossConverter(),
    ) # ν
    # Add Voltage Variables: v^sq, δ^v, z^v
    add_variables!(container, SquaredDCVoltage, devices, QuadraticLossConverter())
    add_variables!(
        container,
        InterpolationSquaredVoltageVariable,
        devices,
        QuadraticLossConverter(),
    ) # δ^v
    add_variables!(
        container,
        InterpolationBinarySquaredVoltageVariable,
        devices,
        QuadraticLossConverter(),
    ) # z^v
    # Add Bilinear Variables: γ, γ^{sq}
    add_variables!(
        container,
        AuxBilinearConverterVariable,
        devices,
        QuadraticLossConverter(),
    ) # γ
    add_variables!(
        container,
        AuxBilinearSquaredConverterVariable,
        devices,
        QuadraticLossConverter(),
    ) # γ^{sq}
    add_variables!(
        container,
        InterpolationSquaredBilinearVariable,
        devices,
        QuadraticLossConverter(),
    ) # δ^γ
    add_variables!(
        container,
        InterpolationBinarySquaredBilinearVariable,
        devices,
        QuadraticLossConverter(),
    ) # z^γ

    #####################
    #### Expressions ####
    #####################

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
        DCCurrentBalance,
        ConverterCurrent,
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
    model::DeviceModel{PSY.InterconnectingConverter, QuadraticLossConverter},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
)
    devices = get_available_components(
        model,
        sys,
    )

    add_constraints!(
        container,
        ConverterPowerCalculationConstraint,
        devices,
        model,
        network_model,
    )
    #add_constraints!(
    #    container,
    #    ConverterDirectionConstraint,
    #    devices,
    #    model,
    #    network_model,
    #)
    add_constraints!(
        container,
        ConverterMcCormickEnvelopes,
        devices,
        model,
        network_model,
    )

    add_feedforward_constraints!(container, model, devices)
    objective_function!(container, devices, model, get_network_formulation(network_model))
    #add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.TModelHVDCLine, LossLessLine},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
)
    devices = get_available_components(
        model,
        sys,
    )
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

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.TModelHVDCLine, DCLossyLine},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
)
    devices = get_available_components(
        model,
        sys,
    )

    add_variables!(container, DCLineCurrent, devices, DCLossyLine())
    add_to_expression!(
        container,
        DCCurrentBalance,
        DCLineCurrent,
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
    model::DeviceModel{PSY.TModelHVDCLine, DCLossyLine},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
)
    devices = get_available_components(
        model,
        sys,
    )
    add_constraints!(
        container,
        DCLineCurrentConstraint,
        devices,
        model,
        network_model,
    )
end
