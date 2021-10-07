####################### Feed Forward Affects ###############################################
@doc raw"""
        range_ff(container::OptimizationContainer,
                        cons_name::Symbol,
                        param_reference::NTuple{2, UpdateRef},
                        var_key::VariableKey)

Constructs min/max range parameterized constraint from device variable to include feedforward.

# Constraints

``` param_reference[1][var_name] <= variable[var_name, t] ```
``` variable[var_name, t] <= param_reference[2][var_name] ```

where r in range_data.

# LaTeX

`` param^{min} \leq x ``
`` x \leq param^{max}``

# Arguments
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* param_reference::NTuple{2, UpdateRef} : Tuple with the lower bound and upper bound parameter reference
* cons_name::Symbol : name of the constraint
* var_key::VariableKey : the name of the continuous variable
"""
function range_ff(
    container::OptimizationContainer,
    cons_type_lb::ConstraintType,
    cons_type_ub::ConstraintType,
    constraint_infos,
    param_reference::NTuple{2, <:VariableValueParameter},
    var_type::VariableType,
    ::Type{T},
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    variable = get_variable(container, var_type)
    # Used to make sure the names are consistent between the variable and the infos
    axes = JuMP.axes(variable)
    set_name = axes[1]
    @assert axes[2] == time_steps

    # Create containers for the constraints
    container_lb = add_param_container!(container, param_reference[1], T, set_name)
    param_lb = get_parameter_array(container_lb)
    multiplier_lb = get_multiplier_array(container_lb)
    container_ub = add_param_container!(container, param_reference[2], T, set_name)
    param_ub = get_parameter_array(container_ub)
    multiplier_ub = get_multiplier_array(container_ub)
    # Create containers for the parameters
    con_lb = add_cons_container!(container, cons_type_lb, T, set_name, time_steps)
    con_ub = add_cons_container!(container, cons_type_ub, T, set_name, time_steps)

    # for constraint_info in constraint_infos
    #     name = get_component_name(constraint_info)
    #     param_lb[name] =
    #         add_parameter(container.JuMPmodel, JuMP.lower_bound(variable[name, 1]))
    #     param_ub[name] =
    #         add_parameter(container.JuMPmodel, JuMP.upper_bound(variable[name, 1]))
    #     # default set to 1.0, as this implementation doesn't use multiplier
    #     multiplier_ub[name] = 1.0
    #     multiplier_lb[name] = 1.0
    #     for t in time_steps
    #         expression_ub = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
    #         for val in constraint_info.additional_terms_ub
    #             JuMP.add_to_expression!(expression_ub, variable[name, t])
    #         end
    #         expression_lb = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
    #         for val in constraint_info.additional_terms_lb
    #             JuMP.add_to_expression!(expression_lb, variable[name, t], -1.0)
    #         end
    #         con_ub[name, t] = JuMP.@constraint(
    #             container.JuMPmodel,
    #             expression_ub <= param_ub[name] * multiplier_ub[name]
    #         )
    #         con_lb[name, t] = JuMP.@constraint(
    #             container.JuMPmodel,
    #             expression_lb >= param_lb[name] * multiplier_lb[name]
    #         )
    #     end
    # end

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
