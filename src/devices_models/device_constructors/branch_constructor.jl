################################# Generic AC Branch  Models ################################
# These 3 methods are defined on concrete formulations of the branches to avoid ambiguity
construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{<:PSY.ACBranch, StaticBranch},
    ::Union{NetworkModel{CopperPlatePowerModel}, NetworkModel{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ModelConstructStage,
    ::DeviceModel{<:PSY.ACBranch, StaticBranch},
    ::Union{NetworkModel{CopperPlatePowerModel}, NetworkModel{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchBounds},
    ::Union{NetworkModel{CopperPlatePowerModel}, NetworkModel{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ModelConstructStage,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchBounds},
    ::Union{NetworkModel{CopperPlatePowerModel}, NetworkModel{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    ::Union{NetworkModel{CopperPlatePowerModel}, NetworkModel{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ModelConstructStage,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    ::Union{NetworkModel{CopperPlatePowerModel}, NetworkModel{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{<:PSY.DCBranch, HVDCP2PLossless},
    ::NetworkModel{CopperPlatePowerModel},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ModelConstructStage,
    ::DeviceModel{<:PSY.DCBranch, HVDCP2PLossless},
    ::NetworkModel{CopperPlatePowerModel},
) = nothing

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
    model::DeviceModel{B, StaticBranch},
    ::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(B, sys)
    if get_use_slacks(model)
        add_variables!(
            container,
            BoundSlackUpperBound,
            network_model,
            devices,
            StaticBranch(),
        )
        add_variables!(
            container,
            BoundSlackLowerBound,
            network_model,
            devices,
            StaticBranch(),
        )
    end
    return
end

# For DC Power only. Implements constraints
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{B, StaticBranch},
    ::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractActivePowerModel}
    @debug "construct_device" _group = LOG_GROUP_BRANCH_CONSTRUCTIONS

    devices = get_available_components(B, sys)
    add_constraints!(container, RateLimitConstraint, devices, model, S)
    add_constraint_dual!(container, sys, model)
    if get_use_slacks(model)
        objective_function!(container, B, model, S)
    end
    return
end

# For DC Power only
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, StaticBranch},
    network_model::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    devices = get_available_components(B, sys)
    add_variables!(container, network_model, devices, StaticBranch())
    if get_use_slacks(model)
        add_variables!(
            container,
            BoundSlackUpperBound,
            network_model,
            devices,
            StaticBranch(),
        )
        add_variables!(
            container,
            BoundSlackLowerBound,
            network_model,
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
    model::DeviceModel{B, StaticBranch},
    network_model::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    devices = get_available_components(B, sys)
    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    add_constraints!(container, RateLimitConstraint, devices, model, S)
    add_constraint_dual!(container, sys, model)
    if get_use_slacks(model)
        objective_function!(container, B, model, S)
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, StaticBranchBounds},
    network_model::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    if get_use_slacks(model)
        error()
    end
    devices = get_available_components(B, sys)
    add_variables!(container, network_model, devices, StaticBranchBounds())
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{B, StaticBranchBounds},
    network_model::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    devices = get_available_components(B, sys)
    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    branch_rate_bounds!(container, devices, model, S)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, StaticBranchUnbounded},
    network_model::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    devices = get_available_components(B, sys)
    add_variables!(container, network_model, devices, StaticBranchUnbounded())
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{B, StaticBranchUnbounded},
    network_model::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    devices = get_available_components(B, sys)

    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end

# For AC Power only. Implements Bounds on the active power and rating constraints on the aparent power
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, StaticBranch},
    ::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    if get_use_slacks(model)
        add_variables!(
            container,
            BoundSlackUpperBound,
            network_model,
            devices,
            StaticBranch(),
        )
        add_variables!(
            container,
            BoundSlackLowerBound,
            network_model,
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
    model::DeviceModel{B, StaticBranch},
    ::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    branch_rate_bounds!(container, devices, model, S)

    add_constraints!(container, RateLimitConstraintFromTo, devices, model, S)
    add_constraints!(container, RateLimitConstraintToFrom, devices, model, S)
    add_constraint_dual!(container, sys, model)
    if get_use_slacks(model)
        objective_function!(container, B, model, S)
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, StaticBranchBounds},
    ::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    if get_use_slacks(model)
        add_variables!(
            container,
            BoundSlackUpperBound,
            network_model,
            devices,
            StaticBranch(),
        )
        add_variables!(
            container,
            BoundSlackLowerBound,
            network_model,
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
    model::DeviceModel{B, StaticBranchBounds},
    ::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    branch_rate_bounds!(container, devices, model, S)
    add_constraint_dual!(container, sys, model)
    if get_use_slacks(model)
        objective_function!(container, B, model, S)
    end
    return
end

################################### P2P HVDC Line Models ###################################
function construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{B, F},
    ::NetworkModel{S},
) where {B <: PSY.DCBranch, F <: HVDCP2PUnbounded, S <: PM.AbstractPowerModel} end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{B, U},
    ::NetworkModel{S},
) where {B <: PSY.DCBranch, U <: HVDCP2PUnbounded, S <: PM.AbstractPowerModel}
    add_constraint_dual!(container, sys, model)
end

# Repeated method to avoid ambiguity between HVDCP2PUnbounded and HVDCP2PLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, U},
    ::NetworkModel{S},
) where {
    B <: PSY.DCBranch,
    U <: HVDCP2PUnbounded,
    S <: Union{StandardPTDFModel, PTDFPowerModel},
}
    devices = get_available_components(B, sys)
    add_variables!(container, FlowActivePowerVariable, devices, U())
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerVariable,
        devices,
        model,
        S,
    )
    return
end

# Repeated method to avoid ambiguity between HVDCP2PUnbounded and HVDCP2PLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{B, U},
    ::NetworkModel{S},
) where {
    B <: PSY.DCBranch,
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
    ::DeviceModel{B, F},
    ::NetworkModel{S},
) where {B <: PSY.DCBranch, F <: HVDCP2PLossless, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    if get_use_slacks(model)
        add_variables!(
            container,
            BoundSlackUpperBound,
            network_model,
            devices,
            StaticBranch(),
        )
        add_variables!(
            container,
            BoundSlackLowerBound,
            network_model,
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
    model::DeviceModel{B, U},
    ::NetworkModel{S},
) where {B <: PSY.DCBranch, U <: HVDCP2PLossless, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    add_constraints!(container, FlowRateConstraint, devices, model, S)
    add_constraint_dual!(container, sys, model)
    if get_use_slacks(model)
        objective_function!(container, B, model, S)
    end
    return
end

# Repeated method to avoid ambiguity between HVDCP2PUnbounded and HVDCP2PLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, U},
    ::NetworkModel{S},
) where {
    B <: PSY.DCBranch,
    U <: HVDCP2PLossless,
    S <: Union{StandardPTDFModel, PTDFPowerModel},
}
    devices = get_available_components(B, sys)
    add_variables!(container, FlowActivePowerVariable, devices, U())
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerVariable,
        devices,
        model,
        S,
    )
    if get_use_slacks(model)
        add_variables!(
            container,
            BoundSlackUpperBound,
            network_model,
            devices,
            StaticBranch(),
        )
        add_variables!(
            container,
            BoundSlackLowerBound,
            network_model,
            devices,
            StaticBranch(),
        )
    end
    return
end

# Repeated method to avoid ambiguity between HVDCP2PUnbounded and HVDCP2PLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{B, U},
    ::NetworkModel{S},
) where {
    B <: PSY.HVDCLine,
    U <: HVDCP2PLossless,
    S <: Union{StandardPTDFModel, PTDFPowerModel},
}
    devices = get_available_components(B, sys)
    add_constraints!(container, FlowRateConstraint, devices, model, S)
    add_constraint_dual!(container, sys, model)
    if get_use_slacks(model)
        objective_function!(container, B, model, S)
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.HVDCLine, HVDCP2PDispatch},
    ::NetworkModel{StandardPTDFModel},
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
        StandardPTDFModel,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerFromToVariable,
        devices,
        model,
        StandardPTDFModel,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        HVDCLosses,
        devices,
        model,
        StandardPTDFModel,
    )
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.HVDCLine, HVDCP2PDispatch},
    ::NetworkModel{StandardPTDFModel},
)
    devices = get_available_components(PSY.HVDCLine, sys)
    add_constraints!(container, FlowRateConstraintFromTo, devices, model, StandardPTDFModel)
    add_constraints!(container, FlowRateConstraintToFrom, devices, model, StandardPTDFModel)
    add_constraints!(container, HVDCPowerBalance, devices, model, StandardPTDFModel)
    add_constraints!(container, HVDCLossesAbsoluteValue, devices, model, StandardPTDFModel)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.HVDCLine, HVDCP2PDispatch},
    ::NetworkModel{T},
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
        T,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerFromToVariable,
        devices,
        model,
        T,
    )
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.HVDCLine, HVDCP2PDispatch},
    ::NetworkModel{T},
) where {T <: PM.AbstractActivePowerModel}
    devices = get_available_components(PSY.HVDCLine, sys)
    add_constraints!(container, FlowRateConstraintFromTo, devices, model, T)
    add_constraints!(container, FlowRateConstraintToFrom, devices, model, T)
    add_constraints!(container, HVDCPowerBalance, devices, model, T)
    add_constraints!(container, HVDCDirection, devices, model, T)
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
    ::NetworkModel{PM.DCPPowerModel},
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
        PM.DCPPowerModel,
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
        StandardPTDFModel,
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
