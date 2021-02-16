# These 3 methods are defined on concrete formulations of the branches to avoid ambiguity
construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranch},
    ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchBounds},
    ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.DCBranch, <:AbstractDCLineFormulation},
    ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    ::Type{<:PM.AbstractPowerModel},
) = nothing

# For DC Power only. Implements constraints
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranch},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

# For DC Power only
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranch},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end

    add_variables!(optimization_container, StandardPTDFModel(), devices)

    # PTDF
    ptdf = get_PTDF(optimization_container)
    buses = PSY.get_components(PSY.Bus, sys)
    time_steps = model_time_steps(optimization_container)
    constraint_val = JuMPConstraintArray(undef, time_steps)
    network_flow =
        add_cons_container!(optimization_container, :network_flow, ptdf.axes[1], time_steps)

    nodal_balance_expressions = optimization_container.expressions[:nodal_balance_active]
    for t in time_steps
        for br in devices
            flow_variable = get_variable(optimization_container, FLOW_ACTIVE_POWER, B)
            name = PSY.get_name(br)
            line_flow =
                model_has_parameters(optimization_container) ? zero(PGAE) :
                JuMP.AffExpr(0.0)
            for b in buses
                bus_number = PSY.get_number(b)
                _flow = ptdf[name, bus_number] * nodal_balance_expressions[bus_number, t]
                JuMP.add_to_expression!(line_flow, _flow)
            end
            network_flow[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                flow_variable[name, t] == line_flow
            )
        end
    end

    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

# For AC Power only. Implements Bounds on the active power and rating constraints on the aparent power
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranch},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_bounds!(optimization_container, devices, model, S)
    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranchBounds},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_bounds!(optimization_container, devices, model, S)
    #branch_rate_bounds!(optimization_container, devices, model, S) #This was duplicated... I think it can be removed
    return
end

# DC Branches
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, <:AbstractDCLineFormulation},
    ::Type{S},
) where {B <: PSY.DCBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, <:AbstractDCLineFormulation},
    ::Type{S},
) where {B <: PSY.DCBranch, S <: StandardPTDFModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end

    add_variables!(optimization_container, StandardPTDFModel(), devices)

    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

#=
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.MonitoredLine, FlowMonitoredLine},
    ::Type{S},
) where {S <: PM.AbstractActivePowerModel}
    devices = get_available_components(PSY.MonitoredLine, sys)
    if !validate_available_devices(PSY.MonitoredLine, devices)
        return
    end
    branch_flow_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.MonitoredLine, FlowMonitoredLine},
    ::Type{S},
) where {S <: PM.AbstractPowerModel}
    devices = get_available_components(PSY.MonitoredLine, sys)
    if !validate_available_devices(PSY.MonitoredLine, devices)
        return
    end
    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    branch_flow_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end
=#
