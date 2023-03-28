################################# Generic AC Branch  Models ################################
# These 3 methods are defined on concrete formulations of the branches to avoid ambiguity
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    device_model::DeviceModel{T, StaticBranch},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
) where {T <: PSY.ACBranch}
    if has_subnetworks(network_model)
        devices = get_available_components(T, sys)
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
            device_model,
            network_model,
        )
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    device_model::DeviceModel{T, StaticBranch},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
) where {T <: PSY.ACBranch}
    if has_subnetworks(network_model)
        devices = get_available_components(T, sys)
        add_constraints!(
            container,
            RateLimitConstraint,
            devices,
            device_model,
            network_model,
        )
        add_constraint_dual!(container, sys, device_model)
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    device_model::DeviceModel{T, StaticBranchBounds},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
) where {T <: PSY.ACBranch}
    if has_subnetworks(network_model)
        devices = get_available_components(T, sys)
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
            device_model,
            network_model,
        )
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    device_model::DeviceModel{T, StaticBranchBounds},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
) where {T <: PSY.ACBranch}
    if has_subnetworks(network_model)
        devices = get_available_components(T, sys)
        branch_rate_bounds!(container, devices, device_model, S)
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    device_model::DeviceModel{T, StaticBranchUnbounded},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
) where {T <: PSY.ACBranch}
    if has_subnetworks(network_model)
        devices = get_available_components(T, sys)
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
            device_model,
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

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    device_model::DeviceModel{T, HVDCP2PLossless},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {T <: PSY.DCBranch}
    if has_subnetworks(network_model)
        devices = get_available_components(T, sys)
        add_variables!(
            container,
            FlowActivePowerVariable,
            network_model,
            devices,
            HVDCP2PLossless(),
        )
        add_to_expression!(
            container,
            ActivePowerBalance,
            FlowActivePowerVariable,
            devices,
            device_model,
            network_model,
        )
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    device_model::DeviceModel{T, HVDCP2PLossless},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {T <: PSY.DCBranch}
    if has_subnetworks(network_model)
        devices = get_available_components(T, sys)
        add_constraints!(
            container,
            FlowRateConstraint,
            devices,
            device_model,
            network_model,
        )
        add_constraint_dual!(container, sys, device_model)
    end
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
    ::OptimizationContainer,
    ::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{T, StaticBranch},
    ::NetworkModel{S},
) where {T <: PSY.ACBranch, S <: PM.AbstractActivePowerModel} end

# For DC Power only. Implements constraints
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    device_model::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: PSY.ACBranch}
    @debug "construct_device" _group = LOG_GROUP_BRANCH_CONSTRUCTIONS

    devices = get_available_components(T, sys)
    add_constraints!(container, RateLimitConstraint, devices, device_model, network_model)
    add_constraint_dual!(container, sys, device_model)
    return
end

# For DC Power only
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{StandardPTDFModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(T, sys)
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
    device_model::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{StandardPTDFModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(T, sys)
    add_constraints!(container, NetworkFlowConstraint, devices, device_model, network_model)
    add_constraints!(container, RateLimitConstraint, devices, device_model, network_model)
    add_constraint_dual!(container, sys, device_model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{T, StaticBranchBounds},
    network_model::NetworkModel{StandardPTDFModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(T, sys)
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
    device_model::DeviceModel{T, StaticBranchBounds},
    network_model::NetworkModel{S},
) where {T <: PSY.ACBranch, S <: StandardPTDFModel}
    devices = get_available_components(T, sys)
    add_constraints!(container, NetworkFlowConstraint, devices, device_model, network_model)
    branch_rate_bounds!(container, devices, device_model, S)
    add_constraint_dual!(container, sys, device_model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{T, StaticBranchUnbounded},
    network_model::NetworkModel{StandardPTDFModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(T, sys)
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
    network_model::NetworkModel{StandardPTDFModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(T, sys)

    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end

# For AC Power only. Implements Bounds on the active power and rating constraints on the aparent power
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, StaticBranch},
    ::NetworkModel{S},
) where {T <: PSY.ACBranch, S <: PM.AbstractPowerModel} end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{S},
) where {T <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)
    branch_rate_bounds!(container, devices, model, S)

    add_constraints!(container, RateLimitConstraintFromTo, devices, model, network_model)
    add_constraints!(container, RateLimitConstraintToFrom, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, StaticBranchBounds},
    ::NetworkModel{S},
) where {T <: PSY.ACBranch, S <: PM.AbstractPowerModel} end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranchBounds},
    ::NetworkModel{S},
) where {T <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)
    branch_rate_bounds!(container, devices, model, S)
    add_constraint_dual!(container, sys, model)
    return
end

################################### P2P HVDC Line Models ###################################
function construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{T, F},
    ::NetworkModel{S},
) where {T <: PSY.DCBranch, F <: HVDCP2PUnbounded, S <: PM.AbstractPowerModel} end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, U},
    ::NetworkModel{S},
) where {T <: PSY.DCBranch, U <: HVDCP2PUnbounded, S <: PM.AbstractPowerModel}
    add_constraint_dual!(container, sys, model)
end

# Repeated method to avoid ambiguity between HVDCP2PUnbounded and HVDCP2PLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, U},
    network_model::NetworkModel{S},
) where {
    T <: PSY.DCBranch,
    U <: HVDCP2PUnbounded,
    S <: Union{StandardPTDFModel, PTDFPowerModel},
}
    devices = get_available_components(T, sys)
    add_variables!(container, FlowActivePowerVariable, devices, U())
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

# Repeated method to avoid ambiguity between HVDCP2PUnbounded and HVDCP2PLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, U},
    network_model::NetworkModel{S},
) where {
    T <: PSY.DCBranch,
    U <: HVDCP2PUnbounded,
    S <: Union{StandardPTDFModel, PTDFPowerModel},
}
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{T, F},
    ::NetworkModel{S},
) where {T <: PSY.DCBranch, F <: HVDCP2PLossless, S <: PM.AbstractPowerModel} end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, U},
    network_model::NetworkModel{S},
) where {T <: PSY.DCBranch, U <: HVDCP2PLossless, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)
    add_constraints!(container, FlowRateConstraint, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end

# Repeated method to avoid ambiguity between HVDCP2PUnbounded and HVDCP2PLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, U},
    network_model::NetworkModel{<:Union{StandardPTDFModel, PTDFPowerModel}},
) where {T <: PSY.DCBranch, U <: HVDCP2PLossless}
    devices = get_available_components(T, sys)
    add_variables!(container, FlowActivePowerVariable, devices, U())
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

# Repeated method to avoid ambiguity between HVDCP2PUnbounded and HVDCP2PLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, U},
    network_model::NetworkModel{<:Union{StandardPTDFModel, PTDFPowerModel}},
) where {T <: PSY.HVDCLine, U <: HVDCP2PLossless}
    devices = get_available_components(T, sys)
    add_constraints!(container, FlowRateConstraint, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.HVDCLine, HVDCP2PDispatch},
    network_model::NetworkModel{StandardPTDFModel},
)
    devices = get_available_components(PSY.HVDCLine, sys)
    add_variables!(container, FlowActivePowerToFromVariable, devices, HVDCP2PDispatch())
    add_variables!(container, FlowActivePowerFromToVariable, devices, HVDCP2PDispatch())
    add_variables!(container, HVDCLosses, devices, HVDCP2PDispatch())
    add_variables!(container, HVDCFlowDirectionVariable, devices, HVDCP2PDispatch())
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
    model::DeviceModel{PSY.HVDCLine, HVDCP2PDispatch},
    network_model::NetworkModel{StandardPTDFModel},
)
    devices = get_available_components(PSY.HVDCLine, sys)
    add_constraints!(container, FlowRateConstraintFromTo, devices, model, network_model)
    add_constraints!(container, FlowRateConstraintToFrom, devices, model, network_model)
    add_constraints!(container, HVDCPowerBalance, devices, model, network_model)
    add_constraints!(container, HVDCLossesAbsoluteValue, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.HVDCLine, HVDCP2PDispatch},
    network_model::NetworkModel{T},
) where {T <: PM.AbstractActivePowerModel}
    devices = get_available_components(PSY.HVDCLine, sys)
    add_variables!(container, FlowActivePowerToFromVariable, devices, HVDCP2PDispatch())
    add_variables!(container, FlowActivePowerFromToVariable, devices, HVDCP2PDispatch())
    add_variables!(container, HVDCFlowDirectionVariable, devices, HVDCP2PDispatch())
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
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.HVDCLine, HVDCP2PDispatch},
    network_model::NetworkModel{T},
) where {T <: PM.AbstractActivePowerModel}
    devices = get_available_components(PSY.HVDCLine, sys)
    add_constraints!(container, FlowRateConstraintFromTo, devices, model, network_model)
    add_constraints!(container, FlowRateConstraintToFrom, devices, model, network_model)
    add_constraints!(container, HVDCPowerBalance, devices, model, network_model)
    add_constraints!(container, HVDCDirection, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{PSY.HVDCLine, HVDCP2PDispatch},
    ::NetworkModel{T},
) where {T <: PM.AbstractPowerModel}
    return
end

function construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ModelConstructStage,
    ::DeviceModel{PSY.HVDCLine, HVDCP2PDispatch},
    ::NetworkModel{T},
) where {T <: PM.AbstractPowerModel}
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
    devices = get_available_components(PSY.PhaseShiftingTransformer, sys)
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
    network_model::NetworkModel{StandardPTDFModel},
)
    devices = get_available_components(PSY.PhaseShiftingTransformer, sys)
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
    devices = get_available_components(PSY.PhaseShiftingTransformer, sys)
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
    network_model::NetworkModel{StandardPTDFModel},
)
    devices = get_available_components(PSY.PhaseShiftingTransformer, sys)
    add_constraints!(container, FlowLimitConstraint, devices, model, network_model)
    add_constraints!(container, PhaseAngleControlLimit, devices, model, network_model)
    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end
