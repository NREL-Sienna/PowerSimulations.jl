
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

get_variable_lower_bound(::FlowActivePowerVariable, d::PSY.DCBranch, ::HVDCUnbounded) =
    nothing

get_variable_upper_bound(::FlowActivePowerVariable, d::PSY.DCBranch, ::HVDCUnbounded) =
    nothing

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

get_initial_conditions_device_model(
    ::OperationModel,
    ::DeviceModel{T, <:AbstractDCLineFormulation},
) where {T <: PSY.HVDCLine} = DeviceModel(T, HVDCDispatch)

#################################### Rate Limits Constraints ##################################################
function branch_rate_bounds!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, HVDCLossless},
    ::Type{<:PM.AbstractPowerModel},
) where {B <: PSY.HVDCLine}
    var = get_variable(container, FlowActivePowerVariable(), B)
    for d in devices
        name = PSY.get_name(d)
        for t in get_time_steps(container)
            _var = var[name, t]
            max_val = max(
                PSY.get_active_power_limits_to(d).max,
                PSY.get_active_power_limits_from(d).max,
            )
            min_val = min(
                PSY.get_active_power_limits_to(d).min,
                PSY.get_active_power_limits_from(d).min,
            )
            JuMP.set_upper_bound(_var, max_val)
            JuMP.set_lower_bound(_var, min_val)
        end
    end
    return
end

function branch_rate_bounds!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractDCLineFormulation},
    ::Type{<:PM.AbstractPowerModel},
) where {B <: PSY.HVDCLine}
    vars = [
        get_variable(container, FlowActivePowerVariable(), B),
        get_variable(container, HVDCTotalPowerDeliveredVariable(), B),
    ]
    for d in devices
        name = PSY.get_name(d)
        for t in get_time_steps(container)
            JuMP.set_upper_bound(vars[1][name, t], PSY.get_active_power_limits_from(d).max)
            JuMP.set_lower_bound(vars[1][name, t], PSY.get_active_power_limits_from(d).min)
            JuMP.set_upper_bound(vars[2][name, t], PSY.get_active_power_limits_to(d).max)
            JuMP.set_lower_bound(vars[2][name, t], PSY.get_reactive_power_limits_to(d).min)
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{FlowRateConstraint},
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, HVDCLossless},
    ::Type{<:PM.AbstractDCPModel},
) where {B <: PSY.DCBranch}
    var = get_variable(container, FlowActivePowerVariable(), B)
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    constraint = add_constraints_container!(container, cons_type(), B, names, time_steps)
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
    ::Type{<:Union{FlowRateConstraintFromTo, FlowRateConstraintToFrom, FlowRateConstraint}},
    ::IS.FlattenIteratorWrapper{<:PSY.DCBranch},
    ::DeviceModel{<:PSY.DCBranch, HVDCUnbounded},
    ::Type{<:PM.AbstractPowerModel},
) = nothing

function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{
        <:Union{FlowRateConstraintFromTo, FlowRateConstraintToFrom, FlowRateConstraint},
    },
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractDCLineFormulation},
    ::Type{<:PM.AbstractPowerModel},
) where {B <: PSY.DCBranch}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]

    var = get_variable(container, FlowActivePowerVariable(), B)
    constraint = add_constraints_container!(container, cons_type(), B, names, time_steps)
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

function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{HVDCPowerBalance},
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, <:AbstractDCLineFormulation},
    ::Type{<:PM.AbstractPowerModel},
) where {B <: PSY.DCBranch}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]

    delivered_power_var = get_variable(container, HVDCTotalPowerDeliveredVariable(), B)
    flow_var = get_variable(container, FlowActivePowerVariable(), B)
    constraint = add_constraints_container!(container, cons_type(), B, names, time_steps)
    for t in get_time_steps(container), d in devices
        constraint[PSY.get_name(d), t] = JuMP.@constraint(
            container.JuMPmodel,
            delivered_power_var[PSY.get_name(d), t] ==
            -PSY.get_loss(d).l1 * flow_var[PSY.get_name(d), t] - PSY.get_loss(d).l0,
        )
    end
    return
end
