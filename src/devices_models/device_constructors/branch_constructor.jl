# These 3 methods are defined on concrete formulations of the branches to avoid ambiguity
construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranch},
    ::Union{NetworkModel{CopperPlatePowerModel}, NetworkModel{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchBounds},
    ::Union{NetworkModel{CopperPlatePowerModel}, NetworkModel{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    ::Union{NetworkModel{CopperPlatePowerModel}, NetworkModel{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.DCBranch, <:AbstractDCLineFormulation},
    ::Union{NetworkModel{CopperPlatePowerModel}, NetworkModel{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    ::NetworkModel{<:PM.AbstractPowerModel},
) = nothing

# For DC Power only. Implements constraints
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranch},
    ::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractActivePowerModel}
    @debug "construct_device" _group = :BranchGroup

    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_constraints!(container, devices, model, S, get_feedforward(model))
    return
end

# For DC Power only
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranch},
    network_model::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end

    add_variables!(container, S, devices, StaticBranch())
    add_constraints!(
        container,
        NetworkFlowConstraint,
        devices,
        model,
        network_model,
        get_feedforward(model),
    )

    branch_rate_constraints!(container, devices, model, S, get_feedforward(model)) # TODO: replace when range constraints are available
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranchBounds},
    network_model::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end

    add_variables!(container, S, devices, StaticBranchBounds())
    add_constraints!(
        container,
        NetworkFlowConstraint,
        devices,
        model,
        network_model,
        get_feedforward(model),
    )

    branch_rate_bounds!(container, devices, model, S)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranchUnbounded},
    network_model::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end

    add_variables!(container, S, devices, StaticBranchUnbounded())
    add_constraints!(
        container,
        NetworkFlowConstraint,
        devices,
        model,
        network_model,
        get_feedforward(model),
    )
    return
end

# For AC Power only. Implements Bounds on the active power and rating constraints on the aparent power
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranch},
    ::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end

    branch_rate_bounds!(container, devices, model, S)

    add_constraints!(
        container,
        RateLimitFTConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        RateLimitTFConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranchBounds},
    ::NetworkModel{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_bounds!(container, devices, model, S)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, <:AbstractDCLineFormulation},
    ::NetworkModel{S},
) where {B <: PSY.DCBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_constraints!(container, devices, model, S, get_feedforward(model)) # TODO: replace when range constraints are available
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, U},
    ::NetworkModel{S},
) where {
    B <: PSY.DCBranch,
    U <: Union{HVDCLossless, HVDCUnbounded},
    S <: Union{StandardPTDFModel, PTDFPowerModel},
}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end

    add_variables!(container, FlowActivePowerVariable, devices, U())
    add_variable_to_expression!(container, devices, model, S)
    branch_rate_constraints!(container, devices, model, S, get_feedforward(model)) # TODO: replace when range constraints are available
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, U},
    ::NetworkModel{S},
) where {
    B <: PSY.DCBranch,
    U <: AbstractDCLineFormulation,
    S <: Union{StandardPTDFModel, PTDFPowerModel},
}
    @debug "construct_device" _group = :BranchGroup

    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end

    add_variables!(container, FlowActivePowerVariable, devices, U())

    branch_rate_constraints!(container, devices, model, S, get_feedforward(model)) # TODO: replace when range constraints are available
    return
end
