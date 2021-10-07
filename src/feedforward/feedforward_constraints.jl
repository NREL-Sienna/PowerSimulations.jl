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

@doc raw"""
            semicontinuousrange_ff(container::OptimizationContainer,
                                    cons_name::Symbol,
                                    var_key::VariableKey,
                                    param_reference)

Constructs min/max range constraint from device variable with parameter setting.

# Constraints
If device min = 0:

``` variable[var_name, t] <= r[2].max*param_reference[var_name] ```

Otherwise:

``` variable[var_name, t] <= r[2].max*param_reference[var_name] ```

``` variable[var_name, t] >= r[2].min*param_reference[var_name] ```

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
    ff::SemiContinuousFeedForward,
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        axes = JuMP.axes(variable)
        @assert axes[1] == [PSY.get_name(d) for d in devices]
        @assert axes[2] == time_steps
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

# Constraints
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
    ff::UpperBoundFeedForward,
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    parameter_type = get_default_parameter_type(ff, T)
    param_ub = get_parameter_array(container, parameter_type, T)
    multiplier_ub = get_parameter_multiplier_array(container, parameter_type, T)
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        axes = JuMP.axes(variable)
        set_name = [PSY.get_name(d) for d in devices]
        @assert axes[2] == time_steps

        var_type = get_entry_type(var)
        con_ub = add_cons_container!(
            container,
            FeedforwardUpperBoundConstraint(),
            T,
            set_name,
            time_steps,
            meta = "$(var_type)up",
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

# Constraints
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
    ff::LowerBoundFeedForward,
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    parameter_type = get_default_parameter_type(ff, T)
    param_ub = get_parameter_array(container, parameter_type, T)
    multiplier_ub = get_parameter_multiplier_array(container, parameter_type, T)
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        axes = JuMP.axes(variable)
        set_name = [PSY.get_name(d) for d in devices]
        @assert axes[2] == time_steps

        var_type = get_entry_type(var)
        con_ub = add_cons_container!(
            container,
            FeedforwardUpperBoundConstraint(),
            T,
            set_name,
            time_steps,
            meta = "$(var_type)up",
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
        integral_limit_ff(container::OptimizationContainer,
                        cons_name::Symbol,
                        param_reference,
                        var_key::VariableKey)

Constructs a parameterized integral limit constraint to implement feedforward from other models.
The Parameters are initialized using the upper boundary values of the provided variables.

# Constraints
``` sum(variable[var_name, t] for t in time_steps)/length(time_steps) <= param_reference[var_name] ```

# LaTeX

`` \sum_{t} x \leq param^{max}``
`` \sum_{t} x * DeltaT_lower \leq param^{max} * DeltaT_upper ``
    `` P_LL - P_max * ON_upper <= 0.0 ``
    `` P_LL - P_min * ON_upper >= 0.0 ``

# Arguments
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* cons_name::Symbol : name of the constraint
* param_reference : Reference to the PJ.ParameterRef used to determine the upperbound
* var_key::VariableKey : the name of the continuous variable
"""
#function add_feedforward_constraints!(
#    container::OptimizationContainer,
#    ::DeviceModel,
#    devices::IS.FlattenIteratorWrapper{T},
#    ff::IntegralLimitFeedForward,
#) where {T <: PSY.Component}
#    time_steps = get_time_steps(container)
#    variable = get_variable(container, variable_type, T)
#
#    axes = JuMP.axes(variable)
#    set_name = axes[1]
#
#    @assert axes[2] == time_steps
#    container_ub = add_param_container!(container, param_type, T, set_name)
#    param_ub = get_parameter_array(container_ub)
#    multiplier_ub = get_multiplier_array(container_ub)
#    con_ub = add_cons_container!(container, constraint_type, T, set_name)
#
#    # for name in axes[1]
#    #     value = JuMP.upper_bound(variable[name, 1])
#    #     param_ub[name] = add_parameter(container.JuMPmodel, value)
#    #     # default set to 1.0, as this implementation doesn't use multiplier
#    #     multiplier_ub[name] = 1.0
#    #     con_ub[name] = JuMP.@constraint(
#    #         container.JuMPmodel,
#    #         sum(variable[name, t] for t in time_steps) / length(time_steps) <=
#    #         param_ub[name] * multiplier_ub[name]
#    #     )
#    # end
#    return
#end
