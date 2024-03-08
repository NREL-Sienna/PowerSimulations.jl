################################# Generic AC Branch  Models ################################
# These 3 methods are defined on concrete formulations of the branches to avoid ambiguity
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, StaticBranch},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
) where {T <: PSY.ACBranch}
    if has_subnetworks(network_model)
        devices = get_available_components(model, sys)

        if get_use_slacks(model)
            add_variables!(
                container,
                FlowActivePowerSlackUpperBound,
                network_model,
                devices,
                StaticBranch(),
            )
            add_variables!(
                container,
                FlowActivePowerSlackLowerBound,
                network_model,
                devices,
                StaticBranch(),
            )
        end

        add_variables!(
            container,
            FlowActivePowerVariable,
            network_model,
            devices,
            StaticBranch(),
        )
        add_to_expression!(
            container,
            ActivePowerBalance,
            FlowActivePowerVariable,
            devices,
            model,
            network_model,
        )
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranch},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
) where {T <: PSY.ACBranch}
    if has_subnetworks(network_model)
        devices =
            get_available_components(model, sys)
        add_constraints!(
            container,
            RateLimitConstraint,
            devices,
            model,
            network_model,
        )
        add_constraint_dual!(container, sys, model)
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, StaticBranchBounds},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
) where {T <: PSY.ACBranch}
    if get_use_slacks(model)
        throw(ArgumentError("StaticBranchBounds is not compatible with the use of slacks"))
    end
    if has_subnetworks(network_model)
        devices =
            get_available_components(model, sys)
        add_variables!(
            container,
            FlowActivePowerVariable,
            network_model,
            devices,
            StaticBranchBounds(),
        )
        add_to_expression!(
            container,
            ActivePowerBalance,
            FlowActivePowerVariable,
            devices,
            model,
            network_model,
        )
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranchBounds},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
) where {T <: PSY.ACBranch}
    if has_subnetworks(network_model)
        devices =
            get_available_components(model, sys)
        branch_rate_bounds!(
            container,
            devices,
            model,
            network_model,
        )
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, StaticBranchUnbounded},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
) where {T <: PSY.ACBranch}
    if has_subnetworks(network_model)
        devices =
            get_available_components(model, sys)
        add_variables!(
            container,
            FlowActivePowerVariable,
            network_model,
            devices,
            StaticBranchUnbounded(),
        )
        add_to_expression!(
            container,
            ActivePowerBalance,
            FlowActivePowerVariable,
            devices,
            model,
            network_model,
        )
    end
    return
end

function construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ModelConstructStage,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
)
    return
end

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    ::NetworkModel{<:PM.AbstractPowerModel},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ModelConstructStage,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    ::NetworkModel{<:PM.AbstractPowerModel},
) = nothing

# For DC Power only. Implements constraints
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    device_model::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(device_model, sys)
    if get_use_slacks(device_model)
        add_variables!(
            container,
            FlowActivePowerSlackUpperBound,
            devices,
            StaticBranch(),
        )
        add_variables!(
            container,
            FlowActivePowerSlackLowerBound,
            devices,
            StaticBranch(),
        )
    end
    add_feedforward_arguments!(container, device_model, devices)

    add_feedforward_arguments!(container, device_model, devices)
end

# For DC Power only. Implements constraints
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: PSY.ACBranch}
    @debug "construct_device" _group = LOG_GROUP_BRANCH_CONSTRUCTIONS

    devices = get_available_components(device_model, sys)
    add_constraints!(container, RateLimitConstraint, devices, device_model, network_model)
    add_feedforward_constraints!(container, device_model, devices)
    objective_function!(container, devices, device_model, U)
    add_constraint_dual!(container, sys, device_model)
    return
end

# For DC Power only
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{PTDFPowerModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(model, sys)
    if get_use_slacks(model)
        add_variables!(
            container,
            FlowActivePowerSlackUpperBound,
            network_model,
            devices,
            StaticBranch(),
        )
        add_variables!(
            container,
            FlowActivePowerSlackLowerBound,
            network_model,
            devices,
            StaticBranch(),
        )
    end

    add_variables!(
        container,
        FlowActivePowerVariable,
        network_model,
        devices,
        StaticBranch(),
    )
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{PTDFPowerModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(model, sys)
    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    add_constraints!(container, RateLimitConstraint, devices, model, network_model)
    objective_function!(container, devices, model, PTDFPowerModel)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, StaticBranchBounds},
    network_model::NetworkModel{PTDFPowerModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(model, sys)

    if get_use_slacks(model)
        throw(ArgumentError("StaticBranchBounds is not compatible with the use of slacks"))
    end

    add_variables!(
        container,
        FlowActivePowerVariable,
        network_model,
        devices,
        StaticBranchBounds(),
    )
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranchBounds},
    network_model::NetworkModel{PTDFPowerModel},
) where {T <: PSY.ACBranch}
    devices =
        get_available_components(model, sys)
    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    branch_rate_bounds!(
        container,
        devices,
        model,
        network_model,
    )
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, StaticBranchUnbounded},
    network_model::NetworkModel{PTDFPowerModel},
) where {T <: PSY.ACBranch}
    devices =
        get_available_components(model, sys)
    add_variables!(
        container,
        FlowActivePowerVariable,
        network_model,
        devices,
        StaticBranchUnbounded(),
    )
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranchUnbounded},
    network_model::NetworkModel{PTDFPowerModel},
) where {T <: PSY.ACBranch}
    devices =
        get_available_components(model, sys)

    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end

# For AC Power only. Implements Bounds on the active power and rating constraints on the aparent power
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    device_model::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(device_model, sys)

    if get_use_slacks(device_model)
        # Only one slack is needed for this formulations in AC
        add_variables!(
            container,
            FlowActivePowerSlackUpperBound,
            devices,
            StaticBranch(),
        )
    end

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: PSY.ACBranch}
    devices =
        get_available_components(model, sys)
    branch_rate_bounds!(container, devices, model, network_model)

    add_constraints!(container, RateLimitConstraintFromTo, devices, model, network_model)
    add_constraints!(container, RateLimitConstraintToFrom, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    device_model::DeviceModel{T, StaticBranchBounds},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: PSY.ACBranch}
    if get_use_slacks(device_model)
        throw(
            ArgumentError(
                "StaticBranchBounds is not compatible with the use of slacks",
            ),
        )
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranchBounds},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(device_model, sys)
    branch_rate_bounds!(container, devices, device_model, network_model)
    add_constraints!(
        container,
        RateLimitConstraintFromTo,
        devices,
        device_model,
        network_model,
    )
    add_constraints!(
        container,
        RateLimitConstraintToFrom,
        devices,
        device_model,
        network_model,
    )
    add_constraint_dual!(container, sys, device_model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    device_model::DeviceModel{T, StaticBranchBounds},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(device_model, sys)
    branch_rate_bounds!(container, devices, device_model, network_model)
    add_constraint_dual!(container, sys, device_model)
    return
end

################################### TwoTerminal HVDC Line Models ###################################
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalLossless},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {T <: TwoTerminalHVDCTypes}
    if has_subnetworks(network_model)
        devices = get_available_components(model, sys)
        add_variables!(
            container,
            FlowActivePowerVariable,
            network_model,
            devices,
            HVDCTwoTerminalLossless(),
        )
        add_to_expression!(
            container,
            ActivePowerBalance,
            FlowActivePowerVariable,
            devices,
            model,
            network_model,
        )
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalLossless},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {T <: TwoTerminalHVDCTypes}
    if has_subnetworks(network_model)
        devices =
            get_available_components(model, sys)
        add_constraints!(
            container,
            FlowRateConstraint,
            devices,
            model,
            network_model,
        )
        add_constraint_dual!(container, sys, model)
    end
    return
end

function construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{T, HVDCTwoTerminalUnbounded},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: TwoTerminalHVDCTypes}
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::IS.ModelConstructStage,
    device_model::DeviceModel{<:TwoTerminalHVDCTypes, HVDCTwoTerminalUnbounded},
    ::NetworkModel{<:PM.AbstractPowerModel},
)
    add_constraint_dual!(container, sys, device_model)
    return
end

# Repeated method to avoid ambiguity between HVDCTwoTerminalUnbounded and HVDCTwoTerminalLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalUnbounded},
    network_model::NetworkModel{PTDFPowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices =
        get_available_components(model, sys)
    add_variables!(container, FlowActivePowerVariable, devices, HVDCTwoTerminalUnbounded())
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerVariable,
        devices,
        model,
        network_model,
    )
    return
end

# Repeated method to avoid ambiguity between HVDCTwoTerminalUnbounded and HVDCTwoTerminalLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{<:TwoTerminalHVDCTypes, HVDCTwoTerminalUnbounded},
    network_model::NetworkModel{PTDFPowerModel},
)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{T, HVDCTwoTerminalLossless},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: TwoTerminalHVDCTypes}
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalLossless},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices =
        get_available_components(model, sys)
    add_constraints!(container, FlowRateConstraint, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end

# Repeated method to avoid ambiguity between HVDCTwoTerminalUnbounded and HVDCTwoTerminalLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalLossless},
    network_model::NetworkModel{PTDFPowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices =
        get_available_components(model, sys)
    add_variables!(container, FlowActivePowerVariable, devices, HVDCTwoTerminalLossless())
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerVariable,
        devices,
        model,
        network_model,
    )
    return
end

# Repeated method to avoid ambiguity between HVDCTwoTerminalUnbounded and HVDCTwoTerminalLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalLossless},
    network_model::NetworkModel{U},
) where {
    T <: TwoTerminalHVDCTypes,
    U <: PTDFPowerModel,
}
    devices =
        get_available_components(model, sys)
    add_constraints!(container, FlowRateConstraint, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalDispatch},
    network_model::NetworkModel{PTDFPowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices =
        get_available_components(model, sys)
    add_variables!(
        container,
        FlowActivePowerToFromVariable,
        devices,
        HVDCTwoTerminalDispatch(),
    )
    add_variables!(
        container,
        FlowActivePowerFromToVariable,
        devices,
        HVDCTwoTerminalDispatch(),
    )
    add_variables!(container, HVDCLosses, devices, HVDCTwoTerminalDispatch())
    add_variables!(container, HVDCFlowDirectionVariable, devices, HVDCTwoTerminalDispatch())
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerToFromVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerFromToVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        HVDCLosses,
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
    model::DeviceModel{T, HVDCTwoTerminalDispatch},
    network_model::NetworkModel{PTDFPowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices =
        get_available_components(model, sys)
    add_constraints!(container, FlowRateConstraintFromTo, devices, model, network_model)
    add_constraints!(container, FlowRateConstraintToFrom, devices, model, network_model)
    add_constraints!(container, HVDCPowerBalance, devices, model, network_model)
    add_constraints!(container, HVDCLossesAbsoluteValue, devices, model, network_model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalDispatch},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices =
        get_available_components(model, sys)
    add_variables!(
        container,
        FlowActivePowerToFromVariable,
        devices,
        HVDCTwoTerminalDispatch(),
    )
    add_variables!(
        container,
        FlowActivePowerFromToVariable,
        devices,
        HVDCTwoTerminalDispatch(),
    )
    add_variables!(container, HVDCFlowDirectionVariable, devices, HVDCTwoTerminalDispatch())
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerToFromVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerFromToVariable,
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
    model::DeviceModel{T, HVDCTwoTerminalDispatch},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices =
        get_available_components(model, sys)
    @warn "CopperPlatePowerModel models with HVDC ignores inter-area losses"
    add_constraints!(container, FlowRateConstraintFromTo, devices, model, network_model)
    add_constraints!(container, FlowRateConstraintToFrom, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalDispatch},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices =
        get_available_components(model, sys)
    add_constraints!(container, FlowRateConstraintFromTo, devices, model, network_model)
    add_constraints!(container, FlowRateConstraintToFrom, devices, model, network_model)
    add_constraints!(container, HVDCPowerBalance, devices, model, network_model)
    add_constraints!(container, HVDCDirection, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    add_feedforward_constraints!(container, model, devices)
    return
end

############################# Phase Shifter Transformer Models #############################

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.PhaseShiftingTransformer, PhaseAngleControl},
    network_model::NetworkModel{PM.DCPPowerModel},
)
    devices = get_available_components(
        model,
        sys,
    )
    add_variables!(container, FlowActivePowerVariable, devices, PhaseAngleControl())
    add_variables!(container, PhaseShifterAngle, devices, PhaseAngleControl())
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerVariable,
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
    model::DeviceModel{PSY.PhaseShiftingTransformer, PhaseAngleControl},
    network_model::NetworkModel{PTDFPowerModel},
)
    devices = get_available_components(
        model,
        sys,
    )
    add_variables!(container, FlowActivePowerVariable, devices, PhaseAngleControl())
    add_variables!(container, PhaseShifterAngle, devices, PhaseAngleControl())
    add_to_expression!(
        container,
        ActivePowerBalance,
        PhaseShifterAngle,
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
    model::DeviceModel{PSY.PhaseShiftingTransformer, PhaseAngleControl},
    network_model::NetworkModel{PM.DCPPowerModel},
)
    devices = get_available_components(
        model,
        sys,
    )
    add_constraints!(container, FlowLimitConstraint, devices, model, network_model)
    add_constraints!(container, PhaseAngleControlLimit, devices, model, network_model)
    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.PhaseShiftingTransformer, PhaseAngleControl},
    network_model::NetworkModel{PTDFPowerModel},
)
    devices = get_available_components(
        model,
        sys,
    )
    add_constraints!(container, FlowLimitConstraint, devices, model, network_model)
    add_constraints!(container, PhaseAngleControlLimit, devices, model, network_model)
    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end
