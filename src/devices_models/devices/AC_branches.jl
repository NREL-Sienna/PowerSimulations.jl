
# Note: Any future concrete formulation requires the definition of

# construct_device!(
#     ::OptimizationContainer,
#     ::PSY.System,
#     ::DeviceModel{<:PSY.ACBranch, MyNewFormulation},
#     ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
# ) = nothing

#

# Not implemented yet
# struct TapControl <: AbstractBranchFormulation end

#################################### Branch Variables ##################################################
# Because of the way we integrate with PowerModels, most of the time PowerSimulations will create variables
# for the branch flows either in AC or DC.

#! format: off
get_variable_binary(::FlowActivePowerVariable, ::Type{<:PSY.ACBranch}, ::AbstractBranchFormulation,) = false
get_variable_binary(::PhaseShifterAngle, ::Type{PSY.PhaseShiftingTransformer}, ::AbstractBranchFormulation,) = false

get_parameter_multiplier(::FixValueParameter, ::PSY.ACBranch, ::StaticBranch) = 1.0
get_variable_multiplier(::PhaseShifterAngle, d::PSY.PhaseShiftingTransformer, ::PhaseAngleControl) = 1.0/PSY.get_x(d)

get_initial_conditions_device_model(::OperationModel, ::DeviceModel{T, U}) where {T <: PSY.ACBranch, U <: AbstractBranchFormulation} = DeviceModel(T, U)

#### Properties of slack variables
get_variable_binary(::FlowActivePowerSlackUpperBound, ::Type{<:PSY.ACBranch}, ::AbstractBranchFormulation,) = false
get_variable_binary(::FlowActivePowerSlackLowerBound, ::Type{<:PSY.ACBranch}, ::AbstractBranchFormulation,) = false
# These two methods are defined to avoid ambiguities
get_variable_binary(::FlowActivePowerSlackUpperBound, ::Type{<:PSY.TwoTerminalHVDCLine}, ::AbstractTwoTerminalDCLineFormulation,) = false
get_variable_binary(::FlowActivePowerSlackLowerBound, ::Type{<:PSY.TwoTerminalHVDCLine}, ::AbstractTwoTerminalDCLineFormulation,) = false
get_variable_upper_bound(::FlowActivePowerSlackUpperBound, ::PSY.ACBranch, ::AbstractBranchFormulation) = nothing
get_variable_lower_bound(::FlowActivePowerSlackUpperBound, ::PSY.ACBranch, ::AbstractBranchFormulation) = 0.0
get_variable_upper_bound(::FlowActivePowerSlackLowerBound, ::PSY.ACBranch, ::AbstractBranchFormulation) = nothing
get_variable_lower_bound(::FlowActivePowerSlackLowerBound, ::PSY.ACBranch, ::AbstractBranchFormulation) = 0.0

#! format: on
function get_default_time_series_names(
    ::Type{U},
    ::Type{V},
) where {U <: PSY.ACBranch, V <: AbstractBranchFormulation}
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

function get_default_attributes(
    ::Type{U},
    ::Type{V},
) where {U <: PSY.ACBranch, V <: AbstractBranchFormulation}
    return Dict{String, Any}()
end
#################################### Flow Variable Bounds ##################################################
# Additional Method to be able to filter the branches that are not in the PTDF matrix
function add_variables!(
    container::OptimizationContainer,
    ::Type{T},
    network_model::NetworkModel{PTDFPowerModel},
    devices::IS.FlattenIteratorWrapper{U},
    formulation::AbstractBranchFormulation,
) where {
    T <: Union{
        FlowActivePowerVariable,
        FlowActivePowerSlackUpperBound,
        FlowActivePowerSlackLowerBound,
    },
    U <: PSY.ACBranch}
    time_steps = get_time_steps(container)
    ptdf = get_PTDF_matrix(network_model)
    branches_in_ptdf =
        [b for b in devices if PSY.get_name(b) ∈ Set(PNM.get_branch_ax(ptdf))]
    variable = add_variable_container!(
        container,
        T(),
        U,
        PSY.get_name.(branches_in_ptdf),
        time_steps,
    )

    for d in branches_in_ptdf
        name = PSY.get_name(d)
        # Don't check if names are present when the PTDF has less branches than system
        for t in time_steps
            variable[name, t] = JuMP.@variable(
                get_jump_model(container),
                base_name = "$(T)_$(U)_{$(name), $(t)}",
            )
            ub = get_variable_upper_bound(T(), d, formulation)
            ub !== nothing && JuMP.set_upper_bound(variable[name, t], ub)

            lb = get_variable_lower_bound(T(), d, formulation)
            lb !== nothing && JuMP.set_lower_bound(variable[name, t], lb)
        end
    end
    return
end

function add_variables!(
    container::OptimizationContainer,
    ::Type{FlowActivePowerVariable},
    network_model::NetworkModel{CopperPlatePowerModel},
    devices::IS.FlattenIteratorWrapper{T},
    formulation::U,
) where {T <: PSY.Branch, U <: AbstractBranchFormulation}
    inter_network_branches = T[]
    for d in devices
        ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
        ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
        if ref_bus_from != ref_bus_to
            push!(inter_network_branches, d)
        end
    end
    if !isempty(inter_network_branches)
        add_variables!(container, FlowActivePowerVariable, inter_network_branches, U())
    end
    return
end

function branch_rate_bounds!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractBranchFormulation},
    network_model::NetworkModel{<:PM.AbstractDCPModel},
) where {B <: PSY.ACBranch}
    var = get_variable(container, FlowActivePowerVariable(), B)

    radial_network_reduction = get_radial_network_reduction(network_model)
    radial_branches_names = PNM.get_radial_branches(radial_network_reduction)

    for d in devices
        name = PSY.get_name(d)
        if name ∈ radial_branches_names
            continue
        end
        for t in get_time_steps(container)
            JuMP.set_upper_bound(var[name, t], PSY.get_rate(d))
            JuMP.set_lower_bound(var[name, t], -1.0 * PSY.get_rate(d))
        end
    end
    return
end

function branch_rate_bounds!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractBranchFormulation},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {B <: PSY.ACBranch}
    vars = [
        get_variable(container, FlowActivePowerFromToVariable(), B),
        get_variable(container, FlowActivePowerToFromVariable(), B),
    ]

    time_steps = get_time_steps(container)
    radial_network_reduction = get_radial_network_reduction(network_model)
    radial_branches_names = PNM.get_radial_branches(radial_network_reduction)

    for d in devices
        name = PSY.get_name(d)
        if name ∈ radial_branches_names
            continue
        end
        for t in time_steps, var in vars
            JuMP.set_upper_bound(var[name, t], PSY.get_rate(d))
            JuMP.set_lower_bound(var[name, t], -1.0 * PSY.get_rate(d))
        end
    end
    return
end

################################## Rate Limits constraint_infos ############################

"""
Min and max limits for Abstract Branch Formulation
"""
function get_min_max_limits(
    device::PSY.ACBranch,
    ::Type{<:ConstraintType},
    ::Type{<:AbstractBranchFormulation},
) #  -> Union{Nothing, NamedTuple{(:min, :max), Tuple{Float64, Float64}}}
    return (min = -1 * PSY.get_rate(device), max = PSY.get_rate(device))
end

"""
Min and max limits for Abstract Branch Formulation
"""
function get_min_max_limits(
    ::PSY.PhaseShiftingTransformer,
    ::Type{PhaseAngleControlLimit},
    ::Type{PhaseAngleControl},
) #  -> Union{Nothing, NamedTuple{(:min, :max), Tuple{Float64, Float64}}}
    return (min = -π / 2, max = π / 2)
end

"""
Add branch rate limit constraints for ACBranch with AbstractActivePowerModel
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{RateLimitConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    device_model::DeviceModel{T, U},
    network_model::NetworkModel{V},
) where {
    T <: PSY.ACBranch,
    U <: AbstractBranchFormulation,
    V <: PM.AbstractActivePowerModel,
}
    time_steps = get_time_steps(container)
    radial_network_reduction = get_radial_network_reduction(network_model)
    if isempty(radial_network_reduction)
        device_names = [PSY.get_name(d) for d in devices]
    else
        device_names = PNM.get_meshed_branches(radial_network_reduction)
    end

    con_lb =
        add_constraints_container!(
            container,
            cons_type(),
            T,
            device_names,
            time_steps;
            meta = "lb",
        )
    con_ub =
        add_constraints_container!(
            container,
            cons_type(),
            T,
            device_names,
            time_steps;
            meta = "ub",
        )

    array = get_variable(container, FlowActivePowerVariable(), T)

    use_slacks = get_use_slacks(device_model)
    if use_slacks
        slack_ub = get_variable(container, FlowActivePowerSlackUpperBound(), T)
        slack_lb = get_variable(container, FlowActivePowerSlackLowerBound(), T)
    end

    for device in devices
        ci_name = PSY.get_name(device)
        if ci_name ∈ PNM.get_radial_branches(radial_network_reduction)
            continue
        end
        limits = get_min_max_limits(device, RateLimitConstraint, U) # depends on constraint type and formulation type
        for t in time_steps
            con_ub[ci_name, t] =
                JuMP.@constraint(get_jump_model(container),
                    array[ci_name, t] - (use_slacks ? slack_ub[ci_name, t] : 0.0) <=
                    limits.max)
            con_lb[ci_name, t] =
                JuMP.@constraint(get_jump_model(container),
                    array[ci_name, t] + (use_slacks ? slack_lb[ci_name, t] : 0.0) >=
                    limits.min)
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{RateLimitConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {T <: PSY.ACBranch, U <: AbstractBranchFormulation}
    inter_network_branches = T[]
    for d in devices
        ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
        ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
        if ref_bus_from != ref_bus_to
            push!(inter_network_branches, d)
        end
    end
    if !isempty(inter_network_branches)
        add_range_constraints!(
            container,
            RateLimitConstraint,
            FlowActivePowerVariable,
            devices,
            model,
            CopperPlatePowerModel,
        )
    end
    return
end

function _constraint_without_slacks!(
    container::OptimizationContainer,
    constraint::JuMPConstraintArray,
    rating_data::Vector{Tuple{String, Float64}},
    time_steps::UnitRange{Int64},
    radial_branches_names::Set{String},
    var1::JuMPVariableArray,
    var2::JuMPVariableArray,
)
    for (branch_name, branch_rate) in rating_data
        if branch_name ∈ radial_branches_names
            continue
        end
        for t in time_steps
            constraint[branch_name, t] = JuMP.@constraint(
                get_jump_model(container),
                var1[branch_name, t]^2 + var2[branch_name, t]^2 <= branch_rate^2
            )
        end
    end
    return
end

function _constraint_with_slacks!(
    container::OptimizationContainer,
    constraint::JuMPConstraintArray,
    rating_data::Vector{Tuple{String, Float64}},
    time_steps::UnitRange{Int64},
    radial_branches_names::Set{String},
    var1::JuMPVariableArray,
    var2::JuMPVariableArray,
    slack_ub::JuMPVariableArray,
)
    for (branch_name, branch_rate) in rating_data
        if branch_name ∈ radial_branches_names
            continue
        end
        for t in time_steps
            constraint[branch_name, t] = JuMP.@constraint(
                get_jump_model(container),
                var1[branch_name, t]^2 + var2[branch_name, t]^2 -
                slack_ub[branch_name, t] <= branch_rate^2
            )
        end
    end
end

"""
Add rate limit from to constraints for ACBranch with AbstractPowerModel
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{RateLimitConstraintFromTo},
    devices::IS.FlattenIteratorWrapper{B},
    device_model::DeviceModel{B, <:AbstractBranchFormulation},
    network_model::NetworkModel{T},
) where {B <: PSY.ACBranch, T <: PM.AbstractPowerModel}
    rating_data = [(PSY.get_name(h), PSY.get_rate(h)) for h in devices]

    time_steps = get_time_steps(container)
    var1 = get_variable(container, FlowActivePowerFromToVariable(), B)
    var2 = get_variable(container, FlowReactivePowerFromToVariable(), B)
    add_constraints_container!(
        container,
        cons_type(),
        B,
        [r[1] for r in rating_data],
        time_steps,
    )
    constraint = get_constraint(container, cons_type(), B)

    radial_network_reduction = get_radial_network_reduction(network_model)
    radial_branches_names = PNM.get_radial_branches(radial_network_reduction)

    use_slacks = get_use_slacks(device_model)
    if use_slacks
        slack_ub = get_variable(container, FlowActivePowerSlackUpperBound(), B)
        _constraint_with_slacks!(
            container,
            constraint,
            rating_data,
            time_steps,
            radial_branches_names,
            var1,
            var2,
            slack_ub,
        )
    end

    _constraint_without_slacks!(
        container,
        constraint,
        rating_data,
        time_steps,
        radial_branches_names,
        var1,
        var2,
    )

    return
end

"""
Add rate limit to from constraints for ACBranch with AbstractPowerModel
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{RateLimitConstraintToFrom},
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractBranchFormulation},
    network_model::NetworkModel{T},
) where {B <: PSY.ACBranch, T <: PM.AbstractPowerModel}
    rating_data = [(PSY.get_name(h), PSY.get_rate(h)) for h in devices]

    time_steps = get_time_steps(container)
    var1 = get_variable(container, FlowActivePowerToFromVariable(), B)
    var2 = get_variable(container, FlowReactivePowerToFromVariable(), B)
    add_constraints_container!(
        container,
        cons_type(),
        B,
        [r[1] for r in rating_data],
        time_steps,
    )
    constraint = get_constraint(container, cons_type(), B)

    radial_network_reduction = get_radial_network_reduction(network_model)
    radial_branches_names = PNM.get_radial_branches(radial_network_reduction)

    for r in rating_data
        if r[1] ∈ radial_branches_names
            continue
        end
        for t in time_steps
            constraint[r[1], t] = JuMP.@constraint(
                get_jump_model(container),
                var1[r[1], t]^2 + var2[r[1], t]^2 <= r[2]^2
            )
        end
    end
end

"""
Add network flow constraints for ACBranch and NetworkModel with PTDFPowerModel
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{NetworkFlowConstraint},
    devices::IS.FlattenIteratorWrapper{B},
    model::DeviceModel{B, <:AbstractBranchFormulation},
    network_model::NetworkModel{PTDFPowerModel},
) where {B <: PSY.ACBranch}
    ptdf = get_PTDF_matrix(network_model)
    # This is a workaround to not call the same list comprehension to find
    # The subset of branches of type B in the PTDF
    flow_variables = get_variable(container, FlowActivePowerVariable(), B)
    branches = flow_variables.axes[1]
    time_steps = get_time_steps(container)
    branch_flow = add_constraints_container!(
        container,
        NetworkFlowConstraint(),
        B,
        branches,
        time_steps,
    )
    nodal_balance_expressions =
        get_expression(container, ActivePowerBalance(), PSY.ACBus)

    flow_variables = get_variable(container, FlowActivePowerVariable(), B)
    jump_model = get_jump_model(container)
    for name in branches
        ptdf_col = ptdf[name, :]
        flow_variables_ = flow_variables[name, :]
        for t in time_steps
            branch_flow[name, t] = JuMP.@constraint(
                jump_model,
                sum(
                    ptdf_col[i] * nodal_balance_expressions.data[i, t] for
                    i in 1:length(ptdf_col)
                ) - flow_variables_[t] == 0.0
            )
        end
    end
end

"""
Add network flow constraints for PhaseShiftingTransformer and NetworkModel with PTDFPowerModel
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{NetworkFlowConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, PhaseAngleControl},
    network_model::NetworkModel{PTDFPowerModel},
) where {T <: PSY.PhaseShiftingTransformer}
    ptdf = get_PTDF_matrix(network_model)
    branches = PSY.get_name.(devices)
    time_steps = get_time_steps(container)
    branch_flow = add_constraints_container!(
        container,
        NetworkFlowConstraint(),
        T,
        branches,
        time_steps,
    )
    nodal_balance_expressions = get_expression(container, ActivePowerBalance(), PSY.ACBus)
    flow_variables = get_variable(container, FlowActivePowerVariable(), T)
    angle_variables = get_variable(container, PhaseShifterAngle(), T)
    jump_model = get_jump_model(container)
    for br in devices
        name = PSY.get_name(br)
        ptdf_col = ptdf[name, :]
        inv_x = 1 / PSY.get_x(br)
        for t in time_steps
            branch_flow[name, t] = JuMP.@constraint(
                jump_model,
                sum(
                    ptdf_col[i] * nodal_balance_expressions.data[i, t] for
                    i in 1:length(ptdf_col)
                ) + inv_x * angle_variables[name, t] - flow_variables[name, t] == 0.0
            )
        end
    end
end

"""
Min and max limits for monitored line
"""
function get_min_max_limits(
    device::PSY.MonitoredLine,
    ::Type{<:ConstraintType},
    ::Type{<:AbstractBranchFormulation},
)
    if PSY.get_flow_limits(device).to_from != PSY.get_flow_limits(device).from_to
        @warn(
            "Flow limits in Line $(PSY.get_name(device)) aren't equal. The minimum will be used in formulation $(T)"
        )
    end
    limit = min(
        PSY.get_rate(device),
        PSY.get_flow_limits(device).to_from,
        PSY.get_flow_limits(device).from_to,
    )
    minmax = (min = -1 * limit, max = limit)
    return minmax
end

############################## Flow Limits Constraints #####################################
"""
Add branch flow constraints for monitored lines with DC Power Model
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{FlowLimitConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::NetworkModel{V},
) where {
    T <: Union{PSY.PhaseShiftingTransformer, PSY.MonitoredLine},
    U <: AbstractBranchFormulation,
    V <: PM.AbstractDCPModel,
}
    add_range_constraints!(
        container,
        FlowLimitConstraint,
        FlowActivePowerVariable,
        devices,
        model,
        V,
    )
    return
end

"""
Don't add branch flow constraints for monitored lines if formulation is StaticBranchUnbounded
"""
function add_constraints!(
    ::OptimizationContainer,
    ::Type{RateLimitConstraintFromTo},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::NetworkModel{V},
) where {
    T <: PSY.MonitoredLine,
    U <: StaticBranchUnbounded,
    V <: PM.AbstractActivePowerModel,
}
    return
end

"""
Min and max limits for flow limit from-to constraint
"""
function get_min_max_limits(
    device::PSY.MonitoredLine,
    ::Type{FlowLimitFromToConstraint},
    ::Type{<:AbstractBranchFormulation},
)
    if PSY.get_flow_limits(device).to_from != PSY.get_flow_limits(device).from_to
        @warn(
            "Flow limits in Line $(PSY.get_name(device)) aren't equal. The minimum will be used in formulation $(T)"
        )
    end
    return (
        min = -1 * PSY.get_flow_limits(device).from_to,
        max = PSY.get_flow_limits(device).from_to,
    )
end

"""
Min and max limits for flow limit to-from constraint
"""
function get_min_max_limits(
    device::PSY.MonitoredLine,
    ::Type{FlowLimitToFromConstraint},
    ::Type{<:AbstractBranchFormulation},
)
    if PSY.get_flow_limits(device).to_from != PSY.get_flow_limits(device).from_to
        @warn(
            "Flow limits in Line $(PSY.get_name(device)) aren't equal. The minimum will be used in formulation $(T)"
        )
    end
    return (
        min = -1 * PSY.get_flow_limits(device).to_from,
        max = PSY.get_flow_limits(device).to_from,
    )
end

"""
Don't add branch flow constraints for monitored lines if formulation is StaticBranchUnbounded
"""
function add_constraints!(
    ::OptimizationContainer,
    ::Type{FlowLimitToFromConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::NetworkModel{V},
) where {
    T <: PSY.MonitoredLine,
    U <: StaticBranchUnbounded,
    V <: PM.AbstractActivePowerModel,
}
    return
end

"""
Add phase angle limits for phase shifters
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{PhaseAngleControlLimit},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, PhaseAngleControl},
    ::NetworkModel{U},
) where {T <: PSY.PhaseShiftingTransformer, U <: PM.AbstractActivePowerModel}
    add_range_constraints!(
        container,
        PhaseAngleControlLimit,
        PhaseShifterAngle,
        devices,
        model,
        U,
    )
    return
end

"""
Add network flow constraints for PhaseShiftingTransformer and NetworkModel with PM.DCPPowerModel
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{NetworkFlowConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, PhaseAngleControl},
    ::NetworkModel{PM.DCPPowerModel},
) where {T <: PSY.PhaseShiftingTransformer}
    time_steps = get_time_steps(container)
    flow_variables = get_variable(container, FlowActivePowerVariable(), T)
    ps_angle_variables = get_variable(container, PhaseShifterAngle(), T)
    bus_angle_variables = get_variable(container, VoltageAngle(), PSY.ACBus)
    jump_model = get_jump_model(container)
    branch_flow = add_constraints_container!(
        container,
        NetworkFlowConstraint(),
        T,
        axes(flow_variables)[1],
        time_steps,
    )

    for br in devices
        name = PSY.get_name(br)
        inv_x = 1.0 / PSY.get_x(br)
        flow_variables_ = flow_variables[name, :]
        from_bus = PSY.get_name(PSY.get_from(PSY.get_arc(br)))
        to_bus = PSY.get_name(PSY.get_to(PSY.get_arc(br)))
        angle_variables_ = ps_angle_variables[name, :]
        bus_angle_from = bus_angle_variables[from_bus, :]
        bus_angle_to = bus_angle_variables[to_bus, :]
        @assert inv_x > 0.0
        for t in time_steps
            branch_flow[name, t] = JuMP.@constraint(
                jump_model,
                flow_variables_[t] ==
                inv_x * (bus_angle_from[t] - bus_angle_to[t] + angle_variables_[t])
            )
        end
    end
    return
end

function objective_function!(
    container::OptimizationContainer,
    ::IS.FlattenIteratorWrapper{T},
    device_model::DeviceModel{T, <:AbstractBranchFormulation},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ACBranch}
    if get_use_slacks(device_model)
        variable_up = get_variable(container, FlowActivePowerSlackUpperBound(), T)
        # Use device names because there might be a radial network reduction
        for name in axes(variable_up, 1)
            for t in get_time_steps(container)
                add_to_objective_invariant_expression!(
                    container,
                    variable_up[name, t] * CONSTRAINT_VIOLATION_SLACK_COST,
                )
            end
        end
    end
    return
end

function objective_function!(
    container::OptimizationContainer,
    ::IS.FlattenIteratorWrapper{T},
    device_model::DeviceModel{T, <:AbstractBranchFormulation},
    ::Type{<:PM.AbstractActivePowerModel},
) where {T <: PSY.ACBranch}
    if get_use_slacks(device_model)
        variable_up = get_variable(container, FlowActivePowerSlackUpperBound(), T)
        variable_dn = get_variable(container, FlowActivePowerSlackLowerBound(), T)
        # Use device names because there might be a radial network reduction
        for name in axes(variable_up, 1)
            for t in get_time_steps(container)
                add_to_objective_invariant_expression!(
                    container,
                    (variable_dn[name, t] + variable_up[name, t]) *
                    CONSTRAINT_VIOLATION_SLACK_COST,
                )
            end
        end
    end
    return
end
