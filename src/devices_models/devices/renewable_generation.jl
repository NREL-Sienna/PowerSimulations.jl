#! format: off

abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end
abstract type AbstractRenewableDispatchFormulation <: AbstractRenewableFormulation end
struct RenewableFullDispatch <: AbstractRenewableDispatchFormulation end
struct RenewableConstantPowerFactor <: AbstractRenewableDispatchFormulation end

get_variable_sign(_, ::Type{<:PSY.RenewableGen}, ::AbstractRenewableFormulation) = 1.0
########################### ActivePowerVariable, RenewableGen #################################

get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.RenewableGen}, ::AbstractRenewableFormulation) = false

get_variable_expression_name(::ActivePowerVariable, ::Type{<:PSY.RenewableGen}) = :nodal_balance_active

get_variable_lower_bound(::ActivePowerVariable, d::PSY.RenewableGen, ::AbstractRenewableFormulation) = 0.0
get_variable_upper_bound(::ActivePowerVariable, d::PSY.RenewableGen, ::AbstractRenewableFormulation) = PSY.get_max_active_power(d)

########################### ReactivePowerVariable, RenewableGen #################################

get_variable_binary(::ReactivePowerVariable, ::Type{<:PSY.RenewableGen}, ::AbstractRenewableFormulation) = false

get_variable_expression_name(::ReactivePowerVariable, ::Type{<:PSY.RenewableGen}) = :nodal_balance_reactive

#! format: on

####################################### Reactive Power constraint_infos #########################
function DeviceRangeConstraintSpec(
    ::Type{<:ReactivePowerVariableLimitsConstraint},
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractDeviceFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
) where {T <: PSY.RenewableGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_type = ReactivePowerVariableLimitsConstraint(),
            variable_type = ReactivePowerVariable(),
            limits_func = x -> PSY.get_reactive_power_limits(x),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
            component_type = T,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:ReactivePowerVariableLimitsConstraint},
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::Type{<:RenewableConstantPowerFactor},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
) where {T <: PSY.RenewableGen}
    return DeviceRangeConstraintSpec(;
        custom_optimization_container_func = custom_reactive_power_constraints!,
    )
end

function custom_reactive_power_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{RenewableConstantPowerFactor},
) where {T <: PSY.RenewableGen}
    names = [PSY.get_name(d) for d in devices]
    time_steps = get_time_steps(container)
    p_var = get_variable(container, ActivePowerVariable(), T)
    q_var = get_variable(container, ReactivePowerVariable(), T)
    jump_model = get_jump_model(container)
    constraint = add_cons_container!(container, EqualityConstraint(), T, names, time_steps)
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(acos(PSY.get_power_factor(d)))
        constraint[name, t] =
            JuMP.@constraint(jump_model, q_var[name, t] == p_var[name, t] * pf)
    end
    return
end

function DeviceRangeConstraintSpec(
    ::Type{<:ActivePowerVariableLimitsConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractRenewableDispatchFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
) where {T <: PSY.RenewableGen}
    return DeviceRangeConstraintSpec(;
        timeseries_range_constraint_spec = TimeSeriesConstraintSpec(;
            constraint_type = ActivePowerVariableLimitsConstraint(),
            variable_type = ActivePowerVariable(),
            parameter = ActivePowerTimeSeriesParameter("max_active_power"),
            multiplier_func = x -> PSY.get_max_active_power(x),
            constraint_func = use_parameters ? device_timeseries_param_ub! :
                              device_timeseries_ub!,
            component_type = T,
        ),
    )
end

########################## Addition to the nodal balances ##################################
function NodalExpressionSpec(
    ::Type{T},
    parameter::ReactivePowerTimeSeriesParameter,
) where {T <: PSY.RenewableGen}
    return NodalExpressionSpec(
        parameter,
        T,
        x -> PSY.get_max_reactive_power(x),
        1.0,
        :nodal_balance_reactive,
    )
end

function NodalExpressionSpec(
    ::Type{T},
    parameter::ActivePowerTimeSeriesParameter,
) where {T <: PSY.RenewableGen}
    return NodalExpressionSpec(
        parameter,
        T,
        x -> PSY.get_max_active_power(x),
        1.0,
        :nodal_balance_active,
    )
end

##################################### renewable generation cost ############################
function AddCostSpec(
    ::Type{T},
    ::Type{U},
    ::OptimizationContainer,
) where {T <: PSY.RenewableDispatch, U <: AbstractRenewableDispatchFormulation}
    # TODO: remove once cost_function is required
    cost_function = x -> (x === nothing ? 1.0 : PSY.get_variable(x))
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        variable_cost = cost_function,
        multiplier = OBJECTIVE_FUNCTION_NEGATIVE,
    )
end
