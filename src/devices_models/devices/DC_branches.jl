abstract type AbstractDCLineFormulation <: AbstractBranchFormulation end
struct HVDCUnbounded <: AbstractDCLineFormulation end
struct HVDCLossless <: AbstractDCLineFormulation end
struct HVDCDispatch <: AbstractDCLineFormulation end
# Not Implemented
# struct VoltageSourceDC <: AbstractDCLineFormulation end

#################################### Branch Variables ##################################################
get_variable_binary(_, ::Type{<:PSY.DCBranch}, ::AbstractDCLineFormulation) = false

get_variable_multiplier(::FlowActivePowerVariable, ::Type{<:PSY.DCBranch}, _) = NaN

get_variable_multiplier(
    ::FlowActivePowerFromToVariable,
    ::Type{<:PSY.DCBranch},
    ::AbstractDCLineFormulation,
) = -1.0
get_variable_multiplier(
    ::FlowActivePowerToFromVariable,
    ::Type{<:PSY.DCBranch},
    ::AbstractDCLineFormulation,
) = 1.0

get_variable_lower_bound(
    ::FlowActivePowerVariable,
    d::PSY.DCBranch,
    ::AbstractDCLineFormulation,
) = max(PSY.get_active_power_limits_from(d).min, PSY.get_active_power_limits_to(d).min)
get_variable_upper_bound(
    ::FlowActivePowerVariable,
    d::PSY.DCBranch,
    ::AbstractDCLineFormulation,
) = min(PSY.get_active_power_limits_from(d).max, PSY.get_active_power_limits_to(d).max)
#! format: on

function get_default_time_series_names(
    ::Type{U},
    ::Type{V},
) where {U <: PSY.DCBranch, V <: AbstractDCLineFormulation}
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

function get_default_attributes(
    ::Type{U},
    ::Type{V},
) where {U <: PSY.DCBranch, V <: AbstractDCLineFormulation}
    return Dict{String, Any}()
end

#################################### Rate Limits Constraints ##################################################
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{FlowRateConstraint},
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, HVDCLossless},
    ::Type{<:PM.AbstractDCPModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {B <: PSY.DCBranch}
    var = get_variable(container, FlowActivePowerVariable(), B)
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    constraint = add_cons_container!(container, cons_type(), B, names, time_steps)
    for t in time_steps, d in devices
        min_rate = max(
            PSY.get_active_power_limits_from(d).min,
            PSY.get_active_power_limits_to(d).min,
        )
        max_rate = min(
            PSY.get_active_power_limits_from(d).max,
            PSY.get_active_power_limits_to(d).max,
        )
        constraint[PSY.get_name(d), t] = JuMP.@constraint(
            container.JuMPmodel,
            min_rate <= var[PSY.get_name(d), t] <= max_rate
        )
    end
    return
end

add_constraints!(
    ::OptimizationContainer,
    ::Type{<:Union{FlowRateConstraintFT, FlowRateConstraintTF, FlowRateConstraint}},
    ::IS.FlattenIteratorWrapper{<:PSY.DCBranch},
    ::DeviceModel{<:PSY.DCBranch, HVDCUnbounded},
    ::Type{<:PM.AbstractPowerModel},
    ::Union{Nothing, AbstractAffectFeedForward},
) = nothing

function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{
        <:Union{FlowRateConstraintFT, FlowRateConstraintTF, FlowRateConstraint},
    },
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractDCLineFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {B <: PSY.DCBranch}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]

    var = get_variable(container, FlowActivePowerVariable(), B)
    constraint = add_cons_container!(container, cons_type(), B, names, time_steps)
    for t in time_steps, d in devices
        min_rate = max(
            PSY.get_active_power_limits_from(d).min,
            PSY.get_active_power_limits_to(d).min,
        )
        max_rate = min(
            PSY.get_active_power_limits_from(d).max,
            PSY.get_active_power_limits_to(d).max,
        )
        constraint[PSY.get_name(d), t] = JuMP.@constraint(
            container.JuMPmodel,
            min_rate <= var[PSY.get_name(d), t] <= max_rate
        )
        # Needs refactoring. This add to expression model doesn't work anymore
        # add_to_expression!(
        #     container.expressions[ExpressionKey(ActivePowerBalance, PSY.Bus)],
        #     PSY.get_number(PSY.get_arc(d).to),
        #     t,
        #     var[PSY.get_name(d), t],
        #     -PSY.get_loss(d).l1,
        #     -PSY.get_loss(d).l0,
        # )
    end
    return
end
