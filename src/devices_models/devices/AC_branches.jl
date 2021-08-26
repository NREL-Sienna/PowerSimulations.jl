# Generic Branch Models
abstract type AbstractBranchFormulation <: AbstractDeviceFormulation end

# Abstract Line Models
""" Branch type to add unbounded flow variables and use flow constraints"""
struct StaticBranch <: AbstractBranchFormulation end
""" Branch type to add bounded flow variables and use flow constraints"""
struct StaticBranchBounds <: AbstractBranchFormulation end
""" Branch type to avoid flow constraints"""
struct StaticBranchUnbounded <: AbstractBranchFormulation end

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
# struct PhaseControl <: AbstractBranchFormulation end

#################################### Branch Variables ##################################################
# Because of the way we integrate with PowerModels, most of the time PowerSimulations will create variables
# for the branch flows either in AC or DC.

add_variables!(
    container::OptimizationContainer,
    ::Type{<:AbstractPTDFModel},
    devices::IS.FlattenIteratorWrapper{<:PSY.ACBranch},
    formulation::AbstractBranchFormulation,
) = add_variable!(container, FlowActivePowerVariable(), devices, formulation)

get_variable_binary(
    ::FlowActivePowerVariable,
    ::Type{<:PSY.ACBranch},
    ::AbstractBranchFormulation,
) = false

get_variable_sign(_, ::Type{<:PSY.ACBranch}, _) = NaN
#################################### Flow Variable Bounds ##################################################
function _get_constraint_data(
    devices::IS.FlattenIteratorWrapper{B},
) where {B <: PSY.ACBranch}
    constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limit_values = (min = -1 * PSY.get_rate(d), max = PSY.get_rate(d))
        name = PSY.get_name(d)
        services_ub = Vector{VariableKey}()
        for service in PSY.get_services(d)
            SR = typeof(service)
            push!(services_ub, Symbol("R$(PSY.get_name(service))_$SR"))
        end
        constraint_infos[ix] = DeviceRangeConstraintInfo(
            name,
            limit_values,
            services_ub,
            Vector{VariableKey}(),
        )
    end
    return constraint_infos
end

function branch_rate_bounds!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractBranchFormulation},
    ::Type{<:PM.AbstractDCPModel},
) where {B <: PSY.ACBranch}
    constraint_infos = _get_constraint_data(devices)
    set_variable_bounds!(container, constraint_infos, FlowActivePowerVariable(), B)
    return
end

function branch_rate_bounds!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractBranchFormulation},
    ::Type{<:PM.AbstractPowerModel},
) where {B <: PSY.ACBranch}
    constraint_infos = _get_constraint_data(devices)
    set_variable_bounds!(container, constraint_infos, FlowActivePowerFromToVariable(), B)
    set_variable_bounds!(container, constraint_infos, FlowActivePowerToFromVariable(), B)
    return
end

#################################### Rate Limits constraint_infos ###############################

"""
Min and max limits for Abstract Branch Formulation
"""
function get_min_max_limits(
    device,
    ::Type{<:ConstraintType},
    ::Type{<:AbstractBranchFormulation},
) #  -> Union{Nothing, NamedTuple{(:min, :max), Tuple{Float64, Float64}}}
    (min = -1 * PSY.get_rate(device), max = PSY.get_rate(device))
end

# TODO: Rename these to add_constraints!
"""
Add branch rate limit constraints for ACBranch with AbstractActivePowerModel
"""
function branch_rate_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    X::Type{<:PM.AbstractActivePowerModel},
    feedforward::Nothing,
) where {T <: PSY.ACBranch, U <: AbstractBranchFormulation}
    add_range_constraints!(
        container,
        RateLimitConstraint,
        FlowActivePowerVariable,
        devices,
        model,
        X,
        feedforward,
    )
end

"""
Add rate limit from to constraints for ACBranch with AbstractPowerModel
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{RateLimitFTConstraint},
    devices::IS.FlattenIteratorWrapper{B},
    model::DeviceModel{B, <:AbstractBranchFormulation},
    ::Type{T},
    ::Nothing,
) where {B <: PSY.ACBranch, T <: PM.AbstractPowerModel}
    rating_data = [(PSY.get_name(h), PSY.get_rate(h)) for h in devices]

    time_steps = get_time_steps(container)
    var1 = get_variable(container, FlowActivePowerFromToVariable(), B)
    var2 = get_variable(container, FlowReactivePowerFromToVariable(), B)
    add_cons_container!(container, cons_type(), B, [r[1] for r in rating_data], time_steps)
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
    cons_type::Type{RateLimitTFConstraint},
    devices::IS.FlattenIteratorWrapper{B},
    model::DeviceModel{B, <:AbstractBranchFormulation},
    ::Type{T},
    ::Nothing,
) where {B <: PSY.ACBranch, T <: PM.AbstractPowerModel}
    rating_data = [(PSY.get_name(h), PSY.get_rate(h)) for h in devices]

    time_steps = get_time_steps(container)
    var1 = get_variable(container, FlowActivePowerToFromVariable(), B)
    var2 = get_variable(container, FlowReactivePowerToFromVariable(), B)
    add_cons_container!(container, cons_type(), B, [r[1] for r in rating_data], time_steps)
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
    cons_type::Type{NetworkFlowConstraint},
    devices::IS.FlattenIteratorWrapper{B},
    model::DeviceModel{B, <:AbstractBranchFormulation},
    network_model::NetworkModel{S},
    ::Nothing,
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    ptdf = get_PTDF(network_model)
    branches = PSY.get_name.(devices)
    time_steps = get_time_steps(container)
    branch_flow =
        add_cons_container!(container, NetworkFlowConstraint(), B, branches, time_steps)
    nodal_balance_expressions = get_expression(container, ActivePowerBalance(), S)

    flow_variables = get_variable(container, FlowActivePowerVariable(), B)
    jump_model = get_jump_model(container)
    for br in devices
        name = PSY.get_name(br)
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
# TODO: Write tests for these functions
# TODO: Rename these to add_constraints!
"""
Add branch flow constraints for monitored lines with DC Power Model
"""
function branch_flow_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    X::Type{<:PM.AbstractDCPModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.MonitoredLine, U <: AbstractBranchFormulation}
    add_range_constraints!(
        container,
        FlowLimitConstraint,
        FlowActivePowerVariable,
        devices,
        model,
        X,
        feedforward,
    )
end

"""
Don't add branch flow constraints for monitored lines if formulation is StaticBranchUnbounded
"""
function branch_flow_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::Type{<:PM.AbstractDCPModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.MonitoredLine, U <: StaticBranchUnbounded}
    nothing
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
    (
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
Add branch flow constraints for monitored lines
"""
function branch_flow_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.MonitoredLine, U <: AbstractBranchFormulation}
    add_range_constraints!(
        container,
        FlowLimitFromToConstraint,
        FlowActivePowerFromToVariable,
        devices,
        model,
        X,
        feedforward,
    )
    add_range_constraints!(
        container,
        FlowLimitToFromConstraint,
        FlowActivePowerToFromVariable,
        devices,
        model,
        X,
        feedforward,
    )
end

"""
Don't add branch flow constraints for monitored lines if formulation is StaticBranchUnbounded
"""
function branch_flow_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.MonitoredLine, U <: StaticBranchUnbounded}
    nothing
end
