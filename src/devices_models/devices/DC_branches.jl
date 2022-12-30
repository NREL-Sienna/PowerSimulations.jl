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

get_variable_lower_bound(::FlowActivePowerVariable, d::PSY.DCBranch, ::HVDCP2PUnbounded) =
    nothing

get_variable_upper_bound(::FlowActivePowerVariable, d::PSY.DCBranch, ::HVDCP2PUnbounded) =
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
) where {T <: PSY.HVDCLine} = DeviceModel(T, HVDCP2PDispatch)

#################################### Rate Limits Constraints ##################################################
function branch_rate_bounds!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, HVDCP2PLossless},
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
    ::DeviceModel{B, HVDCP2PLossless},
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
            get_jump_model(container),
            min_rate <= var[PSY.get_name(d), t] <= max_rate
        )
    end
    return
end

add_constraints!(
    ::OptimizationContainer,
    ::Type{<:Union{FlowRateConstraintFromTo, FlowRateConstraintToFrom, FlowRateConstraint}},
    ::IS.FlattenIteratorWrapper{<:PSY.DCBranch},
    ::DeviceModel{<:PSY.DCBranch, HVDCP2PUnbounded},
    ::Type{<:PM.AbstractPowerModel},
) = nothing

function _get_flow_bounds(d::PSY.HVDCLine)
    from_min = PSY.get_active_power_limits_from(d).min
    to_min = PSY.get_active_power_limits_to(d).min
    from_max = PSY.get_active_power_limits_from(d).max
    to_max = PSY.get_active_power_limits_to(d).max

    if from_max < from_min || to_max < to_min
        throw(
            IS.ConflictingInputsError(
                "Limits in HVDC Line $(PSY.get_name(d)) are inconsistent",
            ),
        )
    end

    if from_max < to_min
        throw(
            IS.ConflictingInputsError(
                "From Max $(from_max) can't be a smaller value than To Min $(to_min)",
            ),
        )
    elseif to_max < from_min
        throw(
            IS.ConflictingInputsError(
                "To Max $(to_max) can't be a smaller value than From Min $(from_min)",
            ),
        )
    end

    if from_max <= to_max && from_min <= to_min
        # Case bounds dominated by from side of HVDC Line
        max_rate = from_max
        min_rate = from_min
    elseif from_max >= to_max && from_min >= to_min
        # Case bounds dominated by to side of HVDC Line
        max_rate = to_max
        min_rate = to_min
    elseif from_max >= to_max && from_min <= to_min
        # Case bounds mix upper bound set by to side and lower bound set by from side
        max_rate = to_max
        min_rate = from_min
    elseif from_max <= to_max && from_min >= to_min
        # Case bounds mix lower bound set by to side and upper bound set by from side
        max_rate = from_max
        min_rate = to_min
    else
        @assert false
    end

    return min_rate, max_rate
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    devices::IS.FlattenIteratorWrapper{U},
    ::DeviceModel{U, <:AbstractDCLineFormulation},
    ::Type{<:PM.AbstractPowerModel},
) where {
    T <: Union{FlowRateConstraintFromTo, FlowRateConstraintToFrom, FlowRateConstraint},
    U <: PSY.DCBranch,
}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]

    var = get_variable(container, FlowActivePowerVariable(), U)
    constraint_ub =
        add_constraints_container!(container, T(), U, names, time_steps; meta="ub")
    constraint_lb =
        add_constraints_container!(container, T(), U, names, time_steps; meta="lb")
    for d in devices
        min_rate, max_rate = _get_flow_bounds(d)
        for t in time_steps
            constraint_ub[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                var[PSY.get_name(d), t] <= max_rate
            )
            constraint_lb[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                min_rate <= var[PSY.get_name(d), t]
            )
        end
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
            get_jump_model(container),
            delivered_power_var[PSY.get_name(d), t] ==
            -PSY.get_loss(d).l1 * flow_var[PSY.get_name(d), t] - PSY.get_loss(d).l0,
        )
    end
    return
end
