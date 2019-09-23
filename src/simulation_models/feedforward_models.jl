@doc raw"""
        ub_ff(canonical_model::CanonicalModel,
              cons_name::Symbol,
              param_reference::UpdateRef,
              var_name::Symbol)

Constructs a parametrized upper bound constraint to implement feedforward from other models.
The Parameters are initialized using the uppper boundary values of the provided variables.

# Constraints
``` variable[var_name, t] <= param_reference[var_name] ```

# LaTeX

`` x \leq param^{max}``

# Arguments
* canonical_model::CanonicalModel : the canonical model built in PowerSimulations
* cons_name::Symbol : name of the constraint
* param_reference : Reference to the Parameter used to determine the upperbound
* var_name::Symbol : the name of the continuous variable
"""
function ub_ff(canonical_model::CanonicalModel,
               cons_name::Symbol,
               param_reference::UpdateRef,
               var_name::Symbol)

    time_steps = model_time_steps(canonical_model)
    ub_name = _middle_rename(cons_name, "_", "ub")
    variable = var(canonical_model, var_name)

    axes = JuMP.axes(variable)
    set_name = axes[1]

    @assert axes[2] == time_steps
    _add_param_container!(canonical_model, param_reference, set_name)
    param_ub = par(canonical_model, param_reference)

    _add_cons_container!(canonical_model, ub_name, set_name, time_steps)
    con_ub = con(canonical_model, ub_name)

    for name in axes[1]
        value = JuMP.upper_bound(variable[name, 1])
        param_ub[name] = PJ.add_parameter(canonical_model.JuMPmodel, value)
        for t in axes[2]
            con_ub[name, t] = JuMP.@constraint(canonical_model.JuMPmodel,
                                                variable[name, t] <= param_ub[name])
        end
    end

    return

end

@doc raw"""
        range_ff(canonical_model::CanonicalModel,
                        cons_name::Symbol,
                        param_reference::NTuple{2, UpdateRef},
                        var_name::Symbol)

Constructs min/max range parametrized constraint from device variable to include feedforward.

# Constraints

``` param_reference[1][var_name] <= variable[var_name, t] ```
``` variable[var_name, t] <= param_reference[2][var_name] ```

where r in range_data.

# LaTeX

`` param^{min} \leq x ``
`` x \leq param^{max}``

# Arguments
* canonical_model::CanonicalModel : the canonical model built in PowerSimulations
* param_reference::NTuple{2, UpdateRef} : Tuple with the lower bound and upper bound parameter reference
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
"""
function range_ff(canonical_model::CanonicalModel,
                  cons_name::Symbol,
                  param_reference::NTuple{2, UpdateRef},
                  var_name::Symbol)

    time_steps = model_time_steps(canonical_model)
    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")

    variable = var(canonical_model, var_name)
    axes = JuMP.axes(variable)
    set_name = axes[1]
    @assert axes[2] == time_steps

    #Create containers for the constraints
    _add_param_container!(canonical_model, param_reference[1], set_name)
    param_lb = par(canonical_model, param_reference[1])
    _add_param_container!(canonical_model, param_reference[2], set_name)
    param_ub = par(canonical_model, param_reference[2])

    #Create containers for the parameters
    _add_cons_container!(canonical_model, lb_name, set_name, time_steps)
    con_lb = con(canonical_model, lb_name)
    _add_cons_container!(canonical_model, ub_name, set_name, time_steps)
    con_ub = con(canonical_model, ub_name)

    for name in axes[1]
        param_lb[name] = PJ.add_parameter(canonical_model.JuMPmodel,
                                          JuMP.lower_bound(variable[name, 1]))
        param_ub[name] = PJ.add_parameter(canonical_model.JuMPmodel,
                                          JuMP.upper_bound(variable[name, 1]))
        for t in axes[2]
            con_ub[name, t] = JuMP.@constraint(canonical_model.JuMPmodel,
                                            variable[name, t] <= param_ub[name])
            con_lb[name, t] = JuMP.@constraint(canonical_model.JuMPmodel,
                                            variable[name, t] >= param_lb[name])
        end
    end

    return

end


@doc raw"""
            semicontinuousrange_ff(canonical_model::CanonicalModel,
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    param_reference::UpdateRef)

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
* canonical_model::CanonicalModel : the canonical model built in PowerSimulations
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
* param_reference::UpdateRef : UpdateRef of the parameter
"""
function semicontinuousrange_ff(canonical_model::CanonicalModel,
                                cons_name::Symbol,
                                param_reference::UpdateRef,
                                var_name::Symbol)



    time_steps = model_time_steps(canonical_model)
    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")

    variable = var(canonical_model, var_name)

    axes = JuMP.axes(variable)
    set_name = axes[1]
    @assert axes[2] == time_steps

    _add_param_container!(canonical_model, param_reference, set_name)
    param = par(canonical_model, param_reference)

    _add_cons_container!(canonical_model, ub_name, set_name, time_steps)
    _add_cons_container!(canonical_model, lb_name, set_name, time_steps)
    con_ub = con(canonical_model, ub_name)
    con_lb = con(canonical_model, lb_name)

    for name in axes[1]
        ub_value = JuMP.upper_bound(variable[name, 1])
        lb_value = JuMP.lower_bound(variable[name, 1])
        param[name] = PJ.add_parameter(canonical_model.JuMPmodel, 1.0)
        for t in axes[2]
            con_ub[name, t] = JuMP.@constraint(canonical_model.JuMPmodel,
                                            variable[name, t] <= ub_value*param[name])
            con_lb[name, t] = JuMP.@constraint(canonical_model.JuMPmodel,
                                        variable[name, t] >= lb_value*param[name])
        end
    end

    # If the variable was a lower bound != 0, not removing the LB can cause infeasibilities
    for v in variable
        if JuMP.has_lower_bound(v)
            JuMP.set_lower_bound(v, 0.0)
        end
    end

    return

end

########################## FeedForward Constraints #########################################

function feedforward!(canonical_model::CanonicalModel,
                     device_type::Type{T},
                     ff_model::Nothing) where {T<:PSY.Component}
    return
end

function feedforward!(canonical_model::CanonicalModel,
                     device_type::Type{I},
                     ff_model::UpperBoundFF) where {I<:PSY.Injection}

    for prefix in get_vars_prefix(ff_model)
        var_name = Symbol(prefix, "_$(I)")
        parameter_ref = UpdateRef{JuMP.VariableRef}(var_name)
        ub_ff(canonical_model,
              Symbol("FF_$(I)"),
                     parameter_ref,
                     var_name)
    end

    return

end

function feedforward!(canonical_model::CanonicalModel,
                     device_type::Type{I},
                     ff_model::SemiContinuousFF) where {I<:PSY.Injection}

    bin_var = Symbol(get_bin_prefix(ff_model), "_$(I)")
    parameter_ref = UpdateRef{JuMP.VariableRef}(bin_var)
    for prefix in get_vars_prefix(ff_model)
        var_name = Symbol(prefix, "_$(I)")
        semicontinuousrange_ff(canonical_model,
                               Symbol("FFbin_$(I)"),
                               parameter_ref,
                               var_name)
    end

    return

end
