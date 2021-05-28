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
    ::Type{<:RangeConstraint},
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractDeviceFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.RenewableGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(
                RangeConstraint,
                ReactivePowerVariable,
                T,
            ),
             variable_key = VariableKey(ReactivePowerVariable, T),
            limits_func = x -> PSY.get_reactive_power_limits(x),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::Type{<:RenewableConstantPowerFactor},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.RenewableGen}
    return DeviceRangeConstraintSpec(;
        custom_optimization_container_func = custom_reactive_power_constraints!,
    )
end

function custom_reactive_power_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{RenewableConstantPowerFactor},
) where {T <: PSY.RenewableGen}
    names = [PSY.get_name(d) for d in devices]
    time_steps = model_time_steps(optimization_container)
    p_var = get_variable(optimization_container, ActivePowerVariable(), T)
    q_var = get_variable(optimization_container, ReactivePowerVariable(), T)
    jump_model = get_jump_model(optimization_container)
    constraint = add_cons_container!(optimization_container, EqualityConstraint(), ReactivePowerVariable(), T, names, time_steps)
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(acos(PSY.get_power_factor(d)))
        constraint[name, t] = JuMP.@constraint(
            jump_model,
            q_var[name, t] == p_var[name, t] * pf
        )
    end
    return
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractRenewableDispatchFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.RenewableGen}
    if !use_parameters && !use_forecasts
        return DeviceRangeConstraintSpec(;
            range_constraint_spec = RangeConstraintSpec(;
                constraint_name = make_constraint_name(
                    RangeConstraint,
                    ActivePowerVariable,
                    T,
                ),
                 variable_key = VariableKey(ActivePowerVariable, T),
                limits_func = x -> (min = 0.0, max = PSY.get_active_power(x)),
                constraint_func = device_range!,
                constraint_struct = DeviceRangeConstraintInfo,
            ),
        )
    end

    return DeviceRangeConstraintSpec(;
        timeseries_range_constraint_spec = TimeSeriesConstraintSpec(;
            constraint_name = make_constraint_name(RangeConstraint, ActivePowerVariable, T),
             variable_key = VariableKey(ActivePowerVariable, T),
            parameter_name = use_parameters ? "P" : nothing,
            forecast_label = "max_active_power",
            multiplier_func = x -> PSY.get_max_active_power(x),
            constraint_func = use_parameters ? device_timeseries_param_ub! :
                              device_timeseries_ub!,
        ),
    )
end

########################## Addition to the nodal balances ##################################
function NodalExpressionSpec(
    ::Type{T},
    ::Type{<:PM.AbstractPowerModel},
    use_forecasts::Bool,
) where {T <: PSY.RenewableGen}
    return NodalExpressionSpec(
        "max_active_power",
        "Q",
        use_forecasts ? x -> PSY.get_max_reactive_power(x) : x -> PSY.get_reactive_power(x),
        1.0,
        T,
    )
end

function NodalExpressionSpec(
    ::Type{T},
    ::Type{<:PM.AbstractActivePowerModel},
    use_forecasts::Bool,
) where {T <: PSY.RenewableGen}
    return NodalExpressionSpec(
        "max_active_power",
        "P",
        use_forecasts ? x -> PSY.get_max_active_power(x) : x -> PSY.get_active_power(x),
        1.0,
        T,
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
