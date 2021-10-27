function add_feedforward_constraints!(
    container::OptimizationContainer,
    model::DeviceModel,
    devices::IS.FlattenIteratorWrapper{V},
) where {V <: PSY.Component}
    for ff in get_feedforwards(model)
        @debug "constraints" ff V
        add_feedforward_constraints!(container, model, devices, ff)
    end
    return
end

function add_feedforward_constraints!(
    container::OptimizationContainer,
    model::ServiceModel,
    service::V,
) where {V <: PSY.AbstractReserve}
    for ff in get_feedforwards(model)
        @debug "constraints" ff V
        contributing_devices = get_contributing_devices(model)
        add_feedforward_constraints!(container, model, contributing_devices, ff)
    end
    return
end

@doc raw"""
            semicontinuousrange_ff(container::OptimizationContainer,
                                    cons_name::Symbol,
                                    var_key::VariableKey,
                                    param_reference)

Constructs min/max range constraint from device variable with parameter setting.


If device min = 0:

``` variable[var_name, t] <= r.max*param_reference[var_name] ```

Otherwise:

``` variable[var_name, t] <= r.max*param_reference[var_name] ```

``` variable[var_name, t] >= r.min*param_reference[var_name] ```

where r in range_data.

# LaTeX

`` 0.0 \leq x^{var} \leq r^{max} x^{param}, \text{ for } r^{min} = 0 ``

`` r^{min} x^{param} \leq x^{var} \leq r^{min} x^{param}, \text{ otherwise } ``

# Arguments
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* cons_name::Symbol : name of the constraint
* var_key::VariableKey : the name of the continuous variable
* param_reference : UpdateRef of the parameter
"""
function add_feedforward_constraints!(
    container::OptimizationContainer,
    ::DeviceModel,
    devices::IS.FlattenIteratorWrapper{T},
    ff::SemiContinuousFeedforward,
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        axes = JuMP.axes(variable)
        IS.@assert_op axes[1] == [PSY.get_name(d) for d in devices]
        IS.@assert_op axes[2] == time_steps
        # # If the variable was a lower bound != 0, not removing the LB can cause infeasibilities
        for v in variable
            if JuMP.has_lower_bound(v)
                @debug "lb reset" v
                JuMP.set_lower_bound(v, 0.0)
            end
        end
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
            meta = "$(var_type)ub",
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
            meta = "$(var_type)lb",
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
            meta = "$(var_type)lb",
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
    ff::IntegralLimitFeedforward,
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    parameter_type = get_default_parameter_type(ff, T)
    param = get_parameter_array(container, parameter_type, T)
    multiplier = get_parameter_multiplier_array(container, parameter_type, T)
    affected_periods = ff.number_of_periods
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        set_name, set_time = JuMP.axes(variable)
        IS.@assert_op set_name == [PSY.get_name(d) for d in devices]
        IS.@assert_op set_time == time_steps

        var_type = get_entry_type(var)
        con_ub = add_constraints_container!(
            container,
            FeedforwardIntegralLimitConstraint(),
            T,
            set_name,
            meta = "$(var_type)integral",
        )

        for name in set_name
            con_ub[name] = JuMP.@constraint(
                container.JuMPmodel,
                sum(variable[name, t] for t in 1:affected_periods) / affected_periods <=
                sum(param[name, t] * multiplier[name, t] for t in 1:affected_periods)
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
            JuMP.fix(variable[name, t], param[name, t] * multiplier[name, t]; force = true)
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
            meta = "$(var_type)target",
        )

        for d in devices
            name = PSY.get_name(d)
            con_ub[name] = JuMP.@constraint(
                container.JuMPmodel,
                variable[name, target_period] + slack_var[name, target_period] >=
                param[name, target_period] * multiplier[name, target_period]
            )
            linear_gen_cost!(
                container,
                EnergyShortageVariable(),
                d,
                penalty_cost,
                target_period,
            )
        end
    end
    return
end
