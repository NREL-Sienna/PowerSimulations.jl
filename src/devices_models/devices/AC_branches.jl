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
function branch_rate_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractBranchFormulation},
    ::Type{<:PM.AbstractActivePowerModel},
    feedforward::Nothing,
) where {B <: PSY.ACBranch}
    constraint_infos = _get_constraint_data(devices)
    device_range!(
        container,
        RangeConstraintSpecInternal(
            constraint_infos,
            RateLimitConstraint(),
            FlowActivePowerVariable(),
            B,
        ),
    )
    return
end

function branch_rate_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractBranchFormulation},
    ::Type{<:PM.AbstractPowerModel},
    ::Nothing,
) where {B <: PSY.ACBranch}
    range_data = [(PSY.get_name(h), PSY.get_rate(h)) for h in devices]
    rating_constraint!(
        container,
        range_data,
        RateLimitFTConstraint(),
        (FlowActivePowerFromToVariable(), FlowReactivePowerFromToVariable()),
        B,
    )

    rating_constraint!(
        container,
        range_data,
        RateLimitTFConstraint(),
        (FlowActivePowerToFromVariable(), FlowReactivePowerToFromVariable()),
        B,
    )
    return
end

function _branch_flow_constraint!(
    jump_model::JuMP.Model,
    ptdf_col::Vector{Float64},
    nodal_balance_expressions,
    flow_variables,
    t::Int,
)
    return JuMP.@constraint(
        jump_model,
        sum(ptdf_col[i] * nodal_balance_expressions[i, t] for i in 1:length(ptdf_col)) -
        flow_variables[t] == 0.0
    )
end

function branch_flow_values!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractBranchFormulation},
    network_model::NetworkModel{StandardPTDFModel},
) where {B <: PSY.ACBranch}
    ptdf = get_PTDF(network_model)
    branches = PSY.get_name.(devices)
    time_steps = get_time_steps(container)
    branch_flow =
        add_cons_container!(container, NetworkFlowConstraint(), B, branches, time_steps)
    nodal_balance_expressions = container.expressions[:nodal_balance_active]
    flow_variables = get_variable(container, FlowActivePowerVariable(), B)
    jump_model = get_jump_model(container)
    for br in devices
        name = PSY.get_name(br)
        ptdf_col = ptdf[name, :]
        flow_variables_ = flow_variables[name, :]
        for t in time_steps
            branch_flow[name, t] = _branch_flow_constraint!(
                jump_model,
                ptdf_col,
                nodal_balance_expressions.data,
                flow_variables_,
                t,
            )
        end
    end
end

#=
############################## Flow Limits Constraints #####################################
function branch_flow_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{PSY.MonitoredLine},
    model::DeviceModel{PSY.MonitoredLine, FlowMonitoredLine},
    ::Type{T},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PM.AbstractDCPModel}
    constraint_infos = Vector{PSI.DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        if PSY.get_flow_limits(d).to_from != PSY.get_flow_limits(d).from_to
            @info(
                "Flow limits in Line $(PSY.get_name(d)) aren't equal. The minimum will be used in formulation $(T)"
            )
        end
        limit = min(
            PSY.get_rate(d),
            PSY.get_flow_limits(d).to_from,
            PSY.get_flow_limits(d).from_to,
        )
        minmax = (min = -1 * limit, max = limit)
        constraint_infos[ix] = DeviceRangeConstraintInfo(PSY.get_name(d), minmax)
    end
    device_range!(
        container,
        RangeConstraintSpecInternal(
            constraint_infos,
            FlowLimitConstraint(),
            FlowActivePowerVariable(),
            PSY.MonitoredLine,
        ),
    )
    return
end

function branch_flow_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{PSY.MonitoredLine},
    model::DeviceModel{PSY.MonitoredLine, FlowMonitoredLine},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
)
    names = Vector{String}(undef, length(devices))
    limit_values_FT = Vector{MinMax}(undef, length(devices))
    limit_values_TF = Vector{MinMax}(undef, length(devices))
    to = Vector{PSI.DeviceRangeConstraintInfo}(undef, length(devices))
    from = Vector{PSI.DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limit_values_FT[ix] = (
            min = -1 * PSY.get_flow_limits(d).from_to,
            max = PSY.get_flow_limits(d).from_to,
        )
        limit_values_TF[ix] = (
            min = -1 * PSY.get_flow_limits(d).to_from,
            max = PSY.get_flow_limits(d).to_from,
        )
        names[ix] = PSY.get_name(d)
        to[ix] = DeviceRangeConstraintInfo(names[ix], limit_values_FT[ix])
        from[ix] = DeviceRangeConstraintInfo(names[ix], limit_values_TF[ix])
    end

    device_range!(
        container,
        RangeConstraintSpecInternal(
            to,
            FlowLimitFromToConstraint(),
            FlowActivePowerFromToVariable(),
            PSY.MonitoredLine,
        ),
    )
    device_range!(
        container,
        RangeConstraintSpecInternal(
            from,
            FlowLimitToFromConstraint(),
            FlowActivePowerToFromVariable(),
            PSY.MonitoredLine,
        ),
    )
    return
end
=#
