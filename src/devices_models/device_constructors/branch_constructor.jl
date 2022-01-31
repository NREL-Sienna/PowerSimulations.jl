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
    ::DeviceModel{<:PSY.DCBranch, HVDCDispatch},
    ::NetworkModel{CopperPlatePowerModel},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ModelConstructStage,
    ::DeviceModel{<:PSY.DCBranch, HVDCDispatch},
    ::NetworkModel{CopperPlatePowerModel},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{<:PSY.DCBranch, HVDCLossless},
    ::NetworkModel{CopperPlatePowerModel},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ModelConstructStage,
    ::DeviceModel{<:PSY.DCBranch, HVDCLossless},
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
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, StaticBranch},
    ::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractActivePowerModel} end

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

    add_variables!(container, S, devices, StaticBranch())
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
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, StaticBranchBounds},
    network_model::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    devices = get_available_components(B, sys)
    add_variables!(container, S, devices, StaticBranchBounds())
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
    add_variables!(container, S, devices, StaticBranchUnbounded())
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
) where {B <: PSY.ACBranch, S <: PM.AbstractPowerModel} end

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
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, StaticBranchBounds},
    ::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractPowerModel} end

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
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, F},
    ::NetworkModel{S},
) where {B <: PSY.DCBranch, F <: HVDCLossless, S <: PM.AbstractPowerModel} end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, F},
    ::NetworkModel{S},
) where {B <: PSY.DCBranch, F <: HVDCUnbounded, S <: PM.AbstractPowerModel} end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, F},
    ::NetworkModel{S},
) where {B <: PSY.DCBranch, F <: HVDCDispatch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    add_variables!(container, HVDCTotalPowerDeliveredVariable, devices, F())
    add_to_expression!(
        container,
        ActivePowerBalance,
        HVDCTotalPowerDeliveredVariable,
        devices,
        model,
        S,
    )
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{B, F},
    ::NetworkModel{S},
) where {B <: PSY.DCBranch, F <: HVDCDispatch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)

    add_constraints!(container, FlowRateConstraintFromTo, devices, model, S)
    add_constraints!(container, FlowRateConstraintToFrom, devices, model, S)
    add_constraints!(container, HVDCPowerBalance, devices, model, S)

    add_constraint_dual!(container, sys, model)
    return
end

# Repeated method to avoid ambiguity between HVDCUnbounded and HVDCLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, U},
    ::NetworkModel{S},
) where {
    B <: PSY.DCBranch,
    U <: HVDCLossless,
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
end

# Repeated method to avoid ambiguity between HVDCUnbounded and HVDCLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, U},
    ::NetworkModel{S},
) where {
    B <: PSY.DCBranch,
    U <: HVDCUnbounded,
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
end

# Repeated method to avoid ambiguity between HVDCUnbounded and HVDCLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{B, U},
    ::NetworkModel{S},
) where {
    B <: PSY.DCBranch,
    U <: HVDCUnbounded,
    S <: Union{StandardPTDFModel, PTDFPowerModel},
}
    devices = get_available_components(B, sys)

    add_constraints!(container, FlowRateConstraint, devices, model, S)
    add_constraint_dual!(container, sys, model)
    return
end

# Repeated method to avoid ambiguity between HVDCUnbounded and HVDCLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{B, U},
    ::NetworkModel{S},
) where {
    B <: PSY.DCBranch,
    U <: HVDCLossless,
    S <: Union{StandardPTDFModel, PTDFPowerModel},
}
    devices = get_available_components(B, sys)

    add_constraints!(container, FlowRateConstraint, devices, model, S)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{B, U},
    ::NetworkModel{S},
) where {
    B <: PSY.DCBranch,
    U <: Union{HVDCLossless, HVDCUnbounded},
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(B, sys)

    add_constraints!(container, FlowRateConstraintFromTo, devices, model, S)
    add_constraints!(container, FlowRateConstraintToFrom, devices, model, S)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{B, U},
    ::NetworkModel{S},
) where {
    B <: PSY.DCBranch,
    U <: HVDCDispatch,
    S <: Union{StandardPTDFModel, PTDFPowerModel},
}
    devices = get_available_components(B, sys)

    add_variables!(container, FlowActivePowerVariable, devices, U())
    # Note: Don't add the flow variables to the expressions for PTDF Models in this constructor
    # otherwise the flow calculation will include the flow variables as part of the nodal balances
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{B, U},
    ::NetworkModel{S},
) where {
    B <: PSY.DCBranch,
    U <: HVDCDispatch,
    S <: Union{StandardPTDFModel, PTDFPowerModel},
}
    devices = get_available_components(B, sys)

    add_constraints!(container, FlowRateConstraint, devices, model, S)
    add_constraint_dual!(container, sys, model)
    return
end
