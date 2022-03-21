function add_feedforward_constraints!(
    container::OptimizationContainer,
    model::DeviceModel,
    devices::IS.FlattenIteratorWrapper{V},
) where {V <: PSY.Component}
    for ff in get_feedforwards(model)
        @debug "constraints" ff V _group = LOG_GROUP_FEEDFORWARDS_CONSTRUCTION
        add_feedforward_constraints!(container, model, devices, ff)
    end
    return
end

function add_feedforward_constraints!(
    container::OptimizationContainer,
    model::ServiceModel,
    ::V,
) where {V <: PSY.AbstractReserve}
    for ff in get_feedforwards(model)
        @debug "constraints" ff V _group = LOG_GROUP_FEEDFORWARDS_CONSTRUCTION
        contributing_devices = get_contributing_devices(model)
        add_feedforward_constraints!(container, model, contributing_devices, ff)
    end
    return
end

function _add_feedforward_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::P,
    ::VariableKey{U, V},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel,
) where {T <: ConstraintType, P <: ParameterType, U <: VariableType, V <: PSY.Component}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    constraint_lb =
        add_constraints_container!(container, T(), V, names, time_steps, meta="$(U)lb")
    constraint_ub =
        add_constraints_container!(container, T(), V, names, time_steps, meta="$(U)ub")
    array = get_variable(container, U(), V)
    parameter = get_parameter_array(container, P(), V)
    multiplier = get_parameter_multiplier_array(container, P(), V)
    jump_model = get_jump_model(container)
    upper_bound_range_with_parameter!(
        jump_model,
        constraint_ub,
        array,
        multiplier,
        parameter,
        devices,
    )
    lower_bound_range_with_parameter!(
        jump_model,
        constraint_lb,
        array,
        multiplier,
        parameter,
        devices,
    )
    return
end

function _add_sc_feedforward_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::P,
    ::VariableKey{U, V},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {
    T <: FeedforwardSemiContinousConstraint,
    P <: ParameterType,
    U <: Union{ActivePowerVariable, PowerAboveMinimumVariable},
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    constraint_lb =
        add_constraints_container!(container, T(), V, names, time_steps, meta="$(U)lb")
    constraint_ub =
        add_constraints_container!(container, T(), V, names, time_steps, meta="$(U)ub")
    array_lb = get_expression(container, ActivePowerRangeExpressionLB(), V)
    array_ub = get_expression(container, ActivePowerRangeExpressionUB(), V)
    parameter = get_parameter_array(container, P(), V)
    upper_bounds = [get_variable_upper_bound(U(), d, W()) for d in devices]
    lower_bounds = [get_variable_lower_bound(U(), d, W()) for d in devices]
    if any(isnothing.(upper_bounds)) || any(isnothing.(lower_bounds))
        throw(IS.InvalidValueError("Bounds for variable $U $V not defined correctly"))
    end
    mult_ub = DenseAxisArray(repeat(upper_bounds, 1, time_steps[end]), names, time_steps)
    mult_lb = DenseAxisArray(repeat(lower_bounds, 1, time_steps[end]), names, time_steps)
    jump_model = get_jump_model(container)
    upper_bound_range_with_parameter!(
        jump_model,
        constraint_ub,
        array_ub,
        mult_ub,
        parameter,
        devices,
    )
    lower_bound_range_with_parameter!(
        jump_model,
        constraint_lb,
        array_lb,
        mult_lb,
        parameter,
        devices,
    )
    return
end

function _add_sc_feedforward_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::P,
    ::VariableKey{U, V},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {
    T <: FeedforwardSemiContinousConstraint,
    P <: ParameterType,
    U <: VariableType,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    constraint_lb =
        add_constraints_container!(container, T(), V, names, time_steps, meta="$(U)lb")
    constraint_ub =
        add_constraints_container!(container, T(), V, names, time_steps, meta="$(U)ub")
    variable = get_variable(container, U(), V)
    parameter = get_parameter_array(container, P(), V)
    upper_bounds = [get_variable_upper_bound(U(), d, W()) for d in devices]
    lower_bounds = [get_variable_lower_bound(U(), d, W()) for d in devices]
    if any(isnothing.(upper_bounds)) || any(isnothing.(lower_bounds))
        throw(IS.InvalidValueError("Bounds for variable $U $V not defined correctly"))
    end
    mult_ub = DenseAxisArray(repeat(upper_bounds, 1, time_steps[end]), names, time_steps)
    mult_lb = DenseAxisArray(repeat(lower_bounds, 1, time_steps[end]), names, time_steps)
    jump_model = get_jump_model(container)
    upper_bound_range_with_parameter!(
        jump_model,
        constraint_ub,
        variable,
        mult_ub,
        parameter,
        devices,
    )
    lower_bound_range_with_parameter!(
        jump_model,
        constraint_lb,
        variable,
        mult_lb,
        parameter,
        devices,
    )
    return
end

function add_feedforward_constraints!(
    container::OptimizationContainer,
    model::DeviceModel,
    devices::IS.FlattenIteratorWrapper{T},
    ff::SemiContinuousFeedforward,
) where {T <: PSY.Component}
    parameter_type = get_default_parameter_type(ff, T)
    time_steps = get_time_steps(container)
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        axes = JuMP.axes(variable)
        IS.@assert_op axes[1] == [PSY.get_name(d) for d in devices]
        IS.@assert_op axes[2] == time_steps
        # If the variable was a lower bound != 0, not removing the LB can cause infeasibilities
        for v in variable
            if JuMP.has_lower_bound(v) && JuMP.lower_bound(v) > 0.0
                @debug "lb reset" JuMP.lower_bound(v) v _group =
                    LOG_GROUP_FEEDFORWARDS_CONSTRUCTION
                JuMP.set_lower_bound(v, 0.0)
            end
        end
        _add_sc_feedforward_constraints!(
            container,
            FeedforwardSemiContinousConstraint,
            parameter_type,
            var,
            devices,
            model,
        )
    end
    return
end

@doc raw"""
        ub_ff(container::OptimizationContainer,
              cons_name::Symbol,
              constraint_infos,
              param_reference,
              var_key::VariableKey)

Constructs a parameterized upper bound constraint to implement feedforward from other models.
The Parameters are initialized using the uppper boundary values of the provided variables.


``` variable[var_name, t] <= param_reference[var_name] ```

# LaTeX

`` x \leq param^{max}``

# Arguments
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* cons_name::Symbol : name of the constraint
* param_reference : Reference to the PJ.ParameterRef used to determine the upperbound
* var_key::VariableKey : the name of the continuous variable
"""
function add_feedforward_constraints!(
    container::OptimizationContainer,
    ::DeviceModel,
    devices::IS.FlattenIteratorWrapper{T},
    ff::UpperBoundFeedforward,
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    parameter_type = get_default_parameter_type(ff, T)
    param_ub = get_parameter_array(container, parameter_type, T)
    multiplier_ub = get_parameter_multiplier_array(container, parameter_type, T)
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        set_name, set_time = JuMP.axes(variable)
        IS.@assert_op set_name == [PSY.get_name(d) for d in devices]
        IS.@assert_op set_time == time_steps

        var_type = get_entry_type(var)
        con_ub = add_constraints_container!(
            container,
            FeedforwardUpperBoundConstraint(),
            T,
            set_name,
            time_steps,
            meta="$(var_type)ub",
        )

        for t in time_steps, name in set_name
            con_ub[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                variable[name, t] <= param_ub[name, t] * multiplier_ub[name, t]
            )
        end
    end
    return
end

@doc raw"""
        lb_ff(container::OptimizationContainer,
              cons_name::Symbol,
              constraint_infos,
              param_reference,
              var_key::VariableKey)

Constructs a parameterized upper bound constraint to implement feedforward from other models.
The Parameters are initialized using the uppper boundary values of the provided variables.


``` variable[var_name, t] <= param_reference[var_name] ```

# LaTeX

`` x \leq param^{max}``

# Arguments
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* cons_name::Symbol : name of the constraint
* param_reference : Reference to the PJ.ParameterRef used to determine the upperbound
* var_key::VariableKey : the name of the continuous variable
"""
function add_feedforward_constraints!(
    container::OptimizationContainer,
    ::DeviceModel,
    devices::IS.FlattenIteratorWrapper{T},
    ff::LowerBoundFeedforward,
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    parameter_type = get_default_parameter_type(ff, T)
    param_ub = get_parameter_array(container, parameter_type, T)
    multiplier_ub = get_parameter_multiplier_array(container, parameter_type, T)
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        set_name, set_time = JuMP.axes(variable)
        IS.@assert_op set_name == [PSY.get_name(d) for d in devices]
        IS.@assert_op set_time == time_steps

        var_type = get_entry_type(var)
        con_ub = add_constraints_container!(
            container,
            FeedforwardLowerBoundConstraint(),
            T,
            set_name,
            time_steps,
            meta="$(var_type)lb",
        )

        for t in time_steps, name in set_name
            con_ub[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                variable[name, t] >= param_ub[name, t] * multiplier_ub[name, t]
            )
        end
    end
    return
end

function add_feedforward_constraints!(
    container::OptimizationContainer,
    ::ServiceModel,
    contributing_devices::Vector{T},
    ff::LowerBoundFeedforward,
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    parameter_type = get_default_parameter_type(ff, T)
    param_ub = get_parameter_array(container, parameter_type, T)
    multiplier_ub = get_parameter_multiplier_array(container, parameter_type, T)
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        set_name, set_time = JuMP.axes(variable)
        IS.@assert_op set_name == [PSY.get_name(d) for d in contributing_devices]
        IS.@assert_op set_time == time_steps

        var_type = get_entry_type(var)
        con_ub = add_constraints_container!(
            container,
            FeedforwardLowerBoundConstraint(),
            T,
            set_name,
            time_steps,
            meta="$(var_type)lb",
        )

        for t in time_steps, name in set_name
            con_ub[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                variable[name, t] >= param_ub[name, t] * multiplier_ub[name, t]
            )
        end
    end
    return
end

@doc raw"""
        add_feedforward_constraints(container::OptimizationContainer,
                        cons_name::Symbol,
                        param_reference,
                        var_key::VariableKey)

Constructs a parameterized integral limit constraint to implement feedforward from other models.
The Parameters are initialized using the upper boundary values of the provided variables.


``` sum(variable[var_name, t] for t in 1:affected_periods)/affected_periods <= param_reference[var_name] ```

# LaTeX

`` \sum_{t} x \leq param^{max}``

# Arguments
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* model::DeviceModel : the device model
* devices::IS.FlattenIteratorWrapper{T} : list of devices
* ff::FixValueFeedforward : a instance of the FixValue Feedforward
"""
function add_feedforward_constraints!(
    container::OptimizationContainer,
    ::DeviceModel,
    devices::IS.FlattenIteratorWrapper{T},
    ff::EnergyLimitFeedforward,
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    parameter_type = get_default_parameter_type(ff, T)
    param = get_parameter_array(container, parameter_type, T)
    multiplier = get_parameter_multiplier_array(container, parameter_type, T)
    affected_periods = get_number_of_periods(ff)
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        set_name, set_time = JuMP.axes(variable)
        IS.@assert_op set_name == [PSY.get_name(d) for d in devices]
        IS.@assert_op set_time == time_steps

        if affected_periods > set_time[end]
            error(
                "The number of affected periods $affected_periods is larger than the periods available $(set_time[end])",
            )
        end
        no_trenches = set_time[end] ÷ affected_periods
        var_type = get_entry_type(var)
        con_ub = add_constraints_container!(
            container,
            FeedforwardIntegralLimitConstraint(),
            T,
            set_name,
            1:no_trenches,
            meta="$(var_type)integral",
        )

        for name in set_name, i in 1:no_trenches
            con_ub[name, i] = JuMP.@constraint(
                container.JuMPmodel,
                sum(
                    variable[name, t] for
                    t in (1 + (i - 1) * affected_periods):(i * affected_periods)
                ) <= sum(
                    param[name, t] * multiplier[name, t] for
                    t in (1 + (i - 1) * affected_periods):(i * affected_periods)
                )
            )
        end
    end
    return
end

@doc raw"""
        add_feedforward_constraints(
            container::OptimizationContainer,
            ::DeviceModel,
            devices::IS.FlattenIteratorWrapper{T},
            ff::FixValueFeedforward,
        ) where {T <: PSY.Component}

Constructs a equality constraint to a fix a variable in one model using the variable value from other model results.


``` variable[var_name, t] == param[var_name, t] ```

# LaTeX

`` x == param``

# Arguments
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* model::DeviceModel : the device model
* devices::IS.FlattenIteratorWrapper{T} : list of devices
* ff::FixValueFeedforward : a instance of the FixValue Feedforward
"""
function add_feedforward_constraints!(
    container::OptimizationContainer,
    ::DeviceModel,
    devices::IS.FlattenIteratorWrapper{T},
    ff::FixValueFeedforward,
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    parameter_type = get_default_parameter_type(ff, T)
    param = get_parameter_array(container, parameter_type, T)
    multiplier = get_parameter_multiplier_array(container, parameter_type, T)
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        set_name, set_time = JuMP.axes(variable)
        IS.@assert_op set_name == [PSY.get_name(d) for d in devices]
        IS.@assert_op set_time == time_steps

        for t in time_steps, name in set_name
            JuMP.fix(variable[name, t], param[name, t] * multiplier[name, t]; force=true)
        end
    end
    return
end

@doc raw"""
        add_feedforward_constraints(
            container::OptimizationContainer,
            ::DeviceModel,
            devices::IS.FlattenIteratorWrapper{T},
            ff::EnergyTargetFeedforward,
        ) where {T <: PSY.Component}

Constructs a equality constraint to a fix a variable in one model using the variable value from other model results.


``` variable[var_name, t] + slack[var_name, t] >= param[var_name, t] ```

# LaTeX

`` x + slack >= param``

# Arguments
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* model::DeviceModel : the device model
* devices::IS.FlattenIteratorWrapper{T} : list of devices
* ff::EnergyTargetFeedforward : a instance of the FixValue Feedforward
"""
function add_feedforward_constraints!(
    container::OptimizationContainer,
    ::DeviceModel,
    devices::IS.FlattenIteratorWrapper{T},
    ff::EnergyTargetFeedforward,
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    parameter_type = get_default_parameter_type(ff, T)
    param = get_parameter_array(container, parameter_type, T)
    multiplier = get_parameter_multiplier_array(container, parameter_type, T)
    target_period = ff.target_period
    penalty_cost = ff.penalty_cost
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        slack_var = get_variable(container, EnergyShortageVariable(), T)
        set_name, set_time = JuMP.axes(variable)
        IS.@assert_op set_name == [PSY.get_name(d) for d in devices]
        IS.@assert_op set_time == time_steps

        var_type = get_entry_type(var)
        con_ub = add_constraints_container!(
            container,
            FeedforwardEnergyTargetConstraint(),
            T,
            set_name,
            meta="$(var_type)target",
        )

        for d in devices
            name = PSY.get_name(d)
            con_ub[name] = JuMP.@constraint(
                container.JuMPmodel,
                variable[name, target_period] + slack_var[name, target_period] >=
                param[name, target_period] * multiplier[name, target_period]
            )
            add_to_objective_invariant_expression!(
                container,
                slack_var[name, target_period] * penalty_cost,
            )
        end
    end
    return
end
