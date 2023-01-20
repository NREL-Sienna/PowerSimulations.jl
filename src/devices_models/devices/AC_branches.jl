
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

get_variable_multiplier(_, ::Type{<:PSY.ACBranch}, _) = NaN
get_variable_multiplier(::PhaseShifterAngle, d::PSY.PhaseShiftingTransformer, ::PhaseAngleControl) = 1.0/PSY.get_x(d)

get_initial_conditions_device_model(::OperationModel, ::DeviceModel{T, <:AbstractBranchFormulation}) where {T <: PSY.ACBranch} = DeviceModel(T, StaticBranch)
get_initial_conditions_device_model(::OperationModel, ::DeviceModel{T, <:AbstractBranchFormulation},) where {T <: PSY.MonitoredLine} = DeviceModel(T, StaticBranchUnbounded)

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

add_variables!(
    container::OptimizationContainer,
    ::NetworkModel{<:AbstractPTDFModel},
    devices::IS.FlattenIteratorWrapper{<:PSY.ACBranch},
    formulation::AbstractBranchFormulation,
) = add_variable!(container, FlowActivePowerVariable(), devices, formulation)

add_variables!(
    container::OptimizationContainer,
    network_model::NetworkModel{StandardPTDFModel},
    devices::IS.FlattenIteratorWrapper{<:PSY.ACBranch},
    formulation::AbstractBranchFormulation,
) = _add_variable!(
    container,
    FlowActivePowerVariable(),
    network_model,
    devices,
    formulation,
)

function _add_variable!(
    container::OptimizationContainer,
    variable_type::T,
    network_model::NetworkModel{StandardPTDFModel},
    devices::IS.FlattenIteratorWrapper{U},
    formulation::AbstractBranchFormulation,
) where {T <: VariableType, U <: PSY.ACBranch}
    time_steps = get_time_steps(container)
    ptdf = get_PTDF(network_model)
    branches_in_ptdf = [b for b in devices if PSY.get_name(b) ∈ ptdf.axes[1]]
    variable = add_variable_container!(
        container,
        variable_type,
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
            ub = get_variable_upper_bound(variable_type, d, formulation)
            ub !== nothing && JuMP.set_upper_bound(variable[name, t], ub)

            lb = get_variable_lower_bound(variable_type, d, formulation)
            lb !== nothing && !binary && JuMP.set_lower_bound(variable[name, t], lb)
        end
    end
end

function branch_rate_bounds!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractBranchFormulation},
    ::Type{<:PM.AbstractDCPModel},
) where {B <: PSY.ACBranch}
    var = get_variable(container, FlowActivePowerVariable(), B)
    for d in devices
        name = PSY.get_name(d)
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
    ::Type{<:PM.AbstractPowerModel},
) where {B <: PSY.ACBranch}
    vars = [
        get_variable(container, FlowActivePowerFromToVariable(), B),
        get_variable(container, FlowActivePowerToFromVariable(), B),
    ]
    for d in devices
        name = PSY.get_name(d)
        for t in get_time_steps(container), var in vars
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
    return (min=-1 * PSY.get_rate(device), max=PSY.get_rate(device))
end

"""
Min and max limits for Abstract Branch Formulation
"""
function get_min_max_limits(
    ::PSY.PhaseShiftingTransformer,
    ::Type{PhaseAngleControlLimit},
    ::Type{PhaseAngleControl},
) #  -> Union{Nothing, NamedTuple{(:min, :max), Tuple{Float64, Float64}}}
    return (min=-π / 2, max=π / 2)
end

"""
Add branch rate limit constraints for ACBranch with AbstractActivePowerModel
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{RateLimitConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    X::Type{<:PM.AbstractActivePowerModel},
) where {T <: PSY.ACBranch, U <: AbstractBranchFormulation}
    add_range_constraints!(container, cons_type, FlowActivePowerVariable, devices, model, X)
    return
end

"""
Add rate limit from to constraints for ACBranch with AbstractPowerModel
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{RateLimitConstraintFromTo},
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractBranchFormulation},
    ::Type{T},
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

    for r in rating_data
        for t in time_steps
            constraint[r[1], t] = JuMP.@constraint(
                container.JuMPmodel,
                var1[r[1], t]^2 + var2[r[1], t]^2 <= r[2]^2
            )
        end
    end
end

"""
Add rate limit to from constraints for ACBranch with AbstractPowerModel
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{RateLimitConstraintToFrom},
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractBranchFormulation},
    ::Type{T},
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

    for r in rating_data
        for t in time_steps
            constraint[r[1], t] = JuMP.@constraint(
                container.JuMPmodel,
                var1[r[1], t]^2 + var2[r[1], t]^2 <= r[2]^2
            )
        end
    end
end

"""
Add network flow constraints for ACBranch and NetworkModel with StandardPTDFModel
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{NetworkFlowConstraint},
    devices::IS.FlattenIteratorWrapper{B},
    model::DeviceModel{B, <:AbstractBranchFormulation},
    network_model::NetworkModel{StandardPTDFModel},
) where {B <: PSY.ACBranch}
    ptdf = get_PTDF(network_model)
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
        get_expression(container, ActivePowerBalance(), StandardPTDFModel)

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
Add network flow constraints for PhaseShiftingTransformer and NetworkModel with StandardPTDFModel
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{NetworkFlowConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, PhaseAngleControl},
    network_model::NetworkModel{StandardPTDFModel},
) where {T <: PSY.PhaseShiftingTransformer}
    ptdf = get_PTDF(network_model)
    branches = PSY.get_name.(devices)
    time_steps = get_time_steps(container)
    branch_flow = add_constraints_container!(
        container,
        NetworkFlowConstraint(),
        T,
        branches,
        time_steps,
    )
    nodal_balance_expressions = get_expression(container, ActivePowerBalance(), PSY.Bus)
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
    minmax = (min=-1 * limit, max=limit)
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
    ::Type{<:PM.AbstractDCPModel},
) where {T <: PSY.MonitoredLine, U <: StaticBranchUnbounded}
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
        min=-1 * PSY.get_flow_limits(device).from_to,
        max=PSY.get_flow_limits(device).from_to,
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
        min=-1 * PSY.get_flow_limits(device).to_from,
        max=PSY.get_flow_limits(device).to_from,
    )
end

"""
Add branch flow constraints for monitored lines
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{FlowLimitFromToConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.MonitoredLine, U <: AbstractBranchFormulation}
    add_range_constraints!(
        container,
        FlowLimitFromToConstraint,
        FlowActivePowerFromToVariable,
        devices,
        model,
        X,
    )
    add_range_constraints!(
        container,
        FlowLimitToFromConstraint,
        FlowActivePowerToFromVariable,
        devices,
        model,
        X,
    )
    return
end

"""
Don't add branch flow constraints for monitored lines if formulation is StaticBranchUnbounded
"""
function add_constraints!(
    ::OptimizationContainer,
    ::Type{FlowLimitToFromConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.MonitoredLine, U <: StaticBranchUnbounded}
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
    bus_angle_variables = get_variable(container, VoltageAngle(), PSY.Bus)
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
