abstract type AbstractDCLineFormulation <: AbstractBranchFormulation end
struct HVDCUnbounded <: AbstractDCLineFormulation end
struct HVDCLossless <: AbstractDCLineFormulation end
struct HVDCDispatch <: AbstractDCLineFormulation end
# Not Implemented
# struct VoltageSourceDC <: AbstractDCLineFormulation end

#################################### Branch Variables ##################################################
get_variable_binary(_, ::Type{<:PSY.DCBranch}, ::AbstractDCLineFormulation) = false

get_variable_sign(::FlowActivePowerVariable, ::Type{<:PSY.DCBranch}, _) = NaN

get_variable_sign(
    ::FlowActivePowerFromToVariable,
    ::Type{<:PSY.DCBranch},
    ::AbstractDCLineFormulation,
) = -1.0
get_variable_sign(
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

#################################### Flow Variable Bounds ##################################################
function add_variable_to_expression!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractDCLineFormulation},
    ::Type{S},
) where {B <: PSY.DCBranch, S <: Union{StandardPTDFModel, PTDFPowerModel}}
    time_steps = get_time_steps(container)
    var = get_variable(container, FlowActivePowerVariable(), B)

    for d in devices
        for t in time_steps
            flow_variable = var[PSY.get_name(d), t]
            add_to_expression!(
                container.expressions[ExpressionKey(ActivePowerBalance, PSY.Bus)],
                PSY.get_number(PSY.get_arc(d).from),
                t,
                flow_variable,
                -1.0,
            )
            add_to_expression!(
                container.expressions[ExpressionKey(ActivePowerBalance, PSY.Bus)],
                PSY.get_number(PSY.get_arc(d).to),
                t,
                flow_variable,
                1.0,
            )
        end
    end
end

#################################### Rate Limits Constraints ##################################################
function branch_rate_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, HVDCLossless},
    ::Type{<:PM.AbstractDCPModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {B <: PSY.DCBranch}
    var = get_variable(container, FlowActivePowerVariable(), B)
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    constraint = add_cons_container!(container, FlowRateConstraint(), B, names, time_steps)
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

branch_rate_constraints!(
    ::OptimizationContainer,
    ::IS.FlattenIteratorWrapper{<:PSY.DCBranch},
    ::DeviceModel{<:PSY.DCBranch, HVDCUnbounded},
    ::Type{<:PM.AbstractPowerModel},
    ::Union{Nothing, AbstractAffectFeedForward},
) = nothing

function branch_rate_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractDCLineFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {B <: PSY.DCBranch}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    for (var_type, cons_type) in zip(
        (FlowActivePowerVariable(), FlowActivePowerVariable()),
        (FlowRateConstraintFT(), FlowRateConstraintTF()),
    )
        var = get_variable(container, var_type, B)
        constraint = add_cons_container!(container, cons_type, B, names, time_steps)
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
            add_to_expression!(
                container.expressions[ExpressionKey(ActivePowerBalance, PSY.Bus)],
                PSY.get_number(PSY.get_arc(d).to),
                t,
                var[PSY.get_name(d), t],
                -PSY.get_loss(d).l1,
                -PSY.get_loss(d).l0,
            )
        end
    end
    return
end
