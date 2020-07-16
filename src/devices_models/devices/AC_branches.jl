#Generic Branch Models
abstract type AbstractBranchFormulation <: AbstractDeviceFormulation end
abstract type AbstractBoundedBranchFormulation <: AbstractBranchFormulation end

#Abstract Line Models
struct StaticLine <: AbstractBranchFormulation end
struct StaticLineBounds <: AbstractBoundedBranchFormulation end
struct StaticLineUnbounded <: AbstractBranchFormulation end
struct FlowMonitoredLine <: AbstractBranchFormulation end

#Abstract Transformer Models
struct StaticTransformer <: AbstractBranchFormulation end
struct StaticTransformerBounds <: AbstractBoundedBranchFormulation end
struct StaticTransformerUnbounded <: AbstractBranchFormulation end

# Not implemented yet
# struct TapControl <: AbstractBranchFormulation end
# struct PhaseControl <: AbstractBranchFormulation end

#################################### Branch Variables ##################################################
# Because of the way we integrate with PowerModels, most of the time PowerSimulations will create variables
# for the branch flows either in AC or DC.
flow_variables!(
    psi_container::PSIContainer,
    ::Type{<:PM.AbstractPowerModel},
    ::IS.FlattenIteratorWrapper{<:PSY.ACBranch},
) = nothing

function flow_variables!(
    psi_container::PSIContainer,
    ::Type{<:StandardPTDFModel},
    devices::IS.FlattenIteratorWrapper{B},
) where {B <: PSY.ACBranch}
    add_variable(psi_container, devices, make_variable_name(FLOW_ACTIVE_POWER, B), false)
    return
end

#################################### Flow Variable Bounds ##################################################
function _get_constraint_data(
    devices::IS.FlattenIteratorWrapper{B},
) where {B <: PSY.ACBranch}
    constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limit_values = (min = -1 * PSY.get_rate(d), max = PSY.get_rate(d))
        name = PSY.get_name(d)
        services_ub = Vector{Symbol}()
        for service in PSY.get_services(d)
            SR = typeof(service)
            push!(services_ub, Symbol("R$(PSY.get_name(service))_$SR"))
        end
        constraint_infos[ix] =
            DeviceRangeConstraintInfo(name, limit_values, services_ub, Vector{Symbol}())
    end
    return constraint_infos
end

function branch_rate_bounds!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{B},
    model::DeviceModel{B, <:AbstractBranchFormulation},
    ::Type{<:PM.AbstractDCPModel},
) where {B <: PSY.ACBranch}
    constraint_infos = _get_constraint_data(devices)
    set_variable_bounds!(psi_container, constraint_infos, FLOW_ACTIVE_POWER, B)
    return
end

function branch_rate_bounds!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{B},
    model::DeviceModel{B, <:AbstractBranchFormulation},
    ::Type{<:PM.AbstractPowerModel},
) where {B <: PSY.ACBranch}
    constraint_infos = _get_constraint_data(devices)
    set_variable_bounds!(psi_container, constraint_infos, FLOW_ACTIVE_POWER_FROM_TO, B)
    set_variable_bounds!(psi_container, constraint_infos, FLOW_ACTIVE_POWER_TO_FROM, B)
    return
end

#################################### Rate Limits constraint_infos ###############################
function branch_rate_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{B},
    model::DeviceModel{B, <:AbstractBranchFormulation},
    ::Type{<:PM.AbstractActivePowerModel},
    feedforward::Nothing,
) where {B <: PSY.ACBranch}
    constraint_infos = _get_constraint_data(devices)
    device_range(
        psi_container,
        RangeConstraintInputsInternal(
            constraint_infos,
            constraint_name(RATE_LIMIT, B),
            make_variable_name(FLOW_ACTIVE_POWER, B),
        ),
    )
    return
end

function branch_rate_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{B},
    model::DeviceModel{B, <:AbstractBranchFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Nothing,
) where {B <: PSY.ACBranch}
    range_data = [(PSY.get_name(h), PSY.get_rate(h)) for h in devices]
    rating_constraint!(
        psi_container,
        range_data,
        constraint_name(RATE_LIMIT_FT, B),
        (
            make_variable_name(FLOW_ACTIVE_POWER_FROM_TO, B),
            make_variable_name(FLOW_REACTIVE_POWER_FROM_TO, B),
        ),
    )

    rating_constraint!(
        psi_container,
        range_data,
        constraint_name(RATE_LIMIT_TF, B),
        (
            make_variable_name(FLOW_ACTIVE_POWER_TO_FROM, B),
            make_variable_name(FLOW_REACTIVE_POWER_TO_FROM, B),
        ),
    )
    return
end

############################## Flow Limits Constraints #####################################
function branch_flow_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.MonitoredLine},
    model::DeviceModel{PSY.MonitoredLine, FlowMonitoredLine},
    ::Type{T},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PM.DCPPowerModel}
    constraint_infos = Vector{PSI.DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        if PSY.get_flowlimits(d).to_from != PSY.get_flowlimits(d).from_to
            @info("Flow limits in Line $(PSY.get_name(d)) aren't equal. The minimum will be used in formulation $(T)")
        end
        limit = min(
            PSY.get_rate(d),
            PSY.get_flowlimits(d).to_from,
            PSY.get_flowlimits(d).from_to,
        )
        minmax = (min = -1 * limit, max = limit)
        constraint_infos[ix] = DeviceRangeConstraintInfo(PSY.get_name(d), minmax)
    end
    device_range(
        psi_container,
        RangeConstraintInputsInternal(
            constraint_infos,
            constraint_name(FLOW_LIMIT, PSY.MonitoredLine),
            make_variable_name(FLOW_ACTIVE_POWER, PSY.MonitoredLine),
        ),
    )
    return
end

function branch_flow_constraints!(
    psi_container::PSIContainer,
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
        limit_values_FT[ix] =
            (min = -1 * PSY.get_flowlimits(d).from_to, max = PSY.get_flowlimits(d).from_to)
        limit_values_TF[ix] =
            (min = -1 * PSY.get_flowlimits(d).to_from, max = PSY.get_flowlimits(d).to_from)
        names[ix] = PSY.get_name(d)
        to[ix] = DeviceRangeConstraintInfo(names[ix], limit_values_FT[ix])
        from[ix] = DeviceRangeConstraintInfo(names[ix], limit_values_TF[ix])
    end

    device_range(
        psi_container,
        RangeConstraintInputsInternal(
            to,
            constraint_name(FLOW_LIMIT_FROM_TO, PSY.MonitoredLine),
            make_variable_name(FLOW_ACTIVE_POWER_FROM_TO, PSY.MonitoredLine),
        ),
    )
    device_range(
        psi_container,
        RangeConstraintInputsInternal(
            from,
            constraint_name(FLOW_LIMIT_TO_FROM, PSY.MonitoredLine),
            make_variable_name(FLOW_ACTIVE_POWER_TO_FROM, PSY.MonitoredLine),
        ),
    )
    return
end
