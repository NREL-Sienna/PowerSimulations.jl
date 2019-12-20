@doc raw"""
    device_timeseries_ub(psi_container::PSIContainer,
                     ts_data::DeviceTimeSeries,
                     range_data::DeviceRange,
                     cons_name::Symbol,
                     var_name::Symbol)

Constructs upper bound for given variable and time series data and a multiplier.

# Constraint

```variable[name, t] <= ts_data.multipliers[ix]*ts_data.ts_vectors[ix][t] ```

# LaTeX

`` x_t \leq r^{val} r_t, \forall t ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::DeviceTimeSeries : container of device time series data and scaling factors
* range_data::DeviceRange : container of device range constraint modification data
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the variable
"""
function device_timeseries_ub(psi_container::PSIContainer,
                              ts_data::DeviceTimeSeries,
                              range_data::DeviceRange,
                              cons_name::Symbol,
                              var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    names = ts_data.names
    variable = get_variable(psi_container, var_name)
    ub_name = _middle_rename(cons_name, "_", "ub")
    con_ub = add_cons_container!(psi_container, ub_name, names, time_steps)
    add_lower_bound = !all(isempty.(range_data.additional_terms_lb))
    if add_lower_bound
        lb_name = _middle_rename(cons_name, "_", "lb")
        con_lb = add_cons_container!(psi_container, lb_name, names, time_steps)
    end

    for (ix, name) in enumerate(range_data.names)
        @assert name == names[ix]
        for t in time_steps
            expression_ub = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
            for val in range_data.additional_terms_ub[ix]
                JuMP.add_to_expression!(expression_ub, 
                                        get_variable(psi_container, val)[name, t])
            end
            con_ub[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                               expression_ub <= ts_data.multipliers[ix] *ts_data.ts_vectors[ix][t])
            if add_lower_bound
                expression_lb = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
                for val in range_data.additional_terms_lb[ix]
                    JuMP.add_to_expression!(expression_lb, 
                                            get_variable(psi_container, val)[name, t], -1.0)
                end
                con_lb[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                                expression_lb >= 0.0)
            end
        end
    end

    return
end

@doc raw"""
    device_timeseries_lb(psi_container::PSIContainer,
                     ts_data::DeviceTimeSeries,
                     range_data::DeviceRange,
                     cons_name::Symbol,
                     var_name::Symbol)

Constructs lower bound for given variable subject to time series data and a multiplier.

# Constraint

``` ts_data.multipliers[ix]*ts_data.ts_vectors[ix][t] <= variable[name, t] ```

# LaTeX

`` r^{val} r_t \leq x_t, \forall t ``

where (ix, name) in enumerate(ts_data.names).

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::DeviceTimeSeries : container of device time series data and scaling factors
* range_data::DeviceRange : container of device range constraint modification data
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the variable
"""
function device_timeseries_lb(psi_container::PSIContainer,
                              ts_data::DeviceTimeSeries,
                              range_data::DeviceRange,
                              cons_name::Symbol,
                              var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    lb_name = _middle_rename(cons_name, "_", "lb")
    names = ts_data.names
    constraint = add_cons_container!(psi_container, lb_name, names, time_steps)

    for (ix, name) in enumerate(range_data.names)
        @assert name == names[ix]
        for t in time_steps
            expression_lb = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
            for val in range_data.additional_terms_lb[ix]
                JuMP.add_to_expression!(expression_lb, 
                                        get_variable(psi_container, val)[name, t], -1.0)
            end
            constraint[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                                   expression_lb >= ts_data.multipliers[ix] * ts_data.ts_vector[ix][t])
        end
    end

    return
end

#NOTE: there is a floating, unnamed lower bound constraint in this function. This may need to be changed.
@doc raw"""
    device_timeseries_param_ub(psi_container::PSIContainer,
                                    ts_data::DeviceTimeSeries,
                                    range_data::DeviceRange,
                                    cons_name::Symbol,
                                    param_reference::UpdateRef,
                                    var_name::Symbol)

Constructs upper bound for given variable using a parameter. The constraint is
    built with a time series data vector and a multiplier

# Constraint

``` variable[name, t] <= ts_data.multipliers[ix]*param[name, t] ```

# LaTeX

`` x^{var}_t \leq r^{val} x^{param}_t, \forall t ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::DeviceTimeSeries : container of device time series data and scaling factors
* range_data::DeviceRange : container of device range constraint modification data
* cons_name::Symbol : name of the constraint
* param_reference::UpdateRef : UpdateRef to access the parameter
* var_name::Symbol : the name of the variable
"""
function device_timeseries_param_ub(psi_container::PSIContainer,
                                    ts_data::DeviceTimeSeries,
                                    range_data::DeviceRange,
                                    cons_name::Symbol,
                                    param_reference::UpdateRef,
                                    var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    names = ts_data.names
    variable = get_variable(psi_container, var_name)
    ub_name = _middle_rename(cons_name, "_", "ub")
    con_ub = add_cons_container!(psi_container, ub_name, names, time_steps)
    param = _add_param_container!(psi_container, param_reference, names, time_steps)
    add_lower_bound = !all(isempty.(range_data.additional_terms_lb))
    if add_lower_bound
        lb_name = _middle_rename(cons_name, "_", "lb")
        con_lb = add_cons_container!(psi_container, lb_name, names, time_steps)
    end

    for (ix, name) in enumerate(range_data.names)
        @assert name == names[ix]
        for t in time_steps
            expression_ub = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
            for val in range_data.additional_terms_ub[ix]
                JuMP.add_to_expression!(expression_ub, 
                                        get_variable(psi_container, val)[name, t])
            end
            param[name, t] = PJ.add_parameter(psi_container.JuMPmodel, 
                                              ts_data.ts_vectors[ix][t])
            con_ub[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                               expression_ub <= ts_data.multipliers[ix] * param[name, t])
            if add_lower_bound
                expression_lb = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
                for val in range_data.additional_terms_lb[ix]
                    JuMP.add_to_expression!(expression_lb, 
                                            get_variable(psi_container, val)[name, t], -1.0)
                end
                con_lb[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                                expression_lb >= 0.0)
            end
        end
    end

    return
end

@doc raw"""
    device_timeseries_param_lb(psi_container::PSIContainer,
                                    ts_data::DeviceTimeSeries,
                                    range_data::DeviceRange,
                                    cons_name::Symbol,
                                    param_reference::UpdateRef,
                                    var_name::Symbol)

Constructs lower bound for given variable using a parameter. The constraint is
    built with a time series data vector and a multiplier

# Constraint

``` ts_data.multipliers[ix] * param[name, t] <= variable[name, t] ```

# LaTeX

`` r^{val} x^{param}_t \leq x^{var}_t, \forall t ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::DeviceTimeSeries : container of device time series data and scaling factors
* range_data::DeviceRange : container of device range constraint modification data
* cons_name::Symbol : name of the constraint
* param_reference::UpdateRef : UpdateRef to access the parameter
* var_name::Symbol : the name of the variable
"""
function device_timeseries_param_lb(psi_container::PSIContainer,
                                    ts_data::DeviceTimeSeries,
                                    range_data::DeviceRange,
                                    cons_name::Symbol,
                                    param_reference::UpdateRef,
                                    var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    lb_name = _middle_rename(cons_name, "_", "lb")
    names = ts_data.names
    constraint =add_cons_container!(psi_container, lb_name, names, time_steps)
    param =_add_param_container!(psi_container, param_reference, names, time_steps)

    for (ix, name) in enumerate(range_data.names)
        @assert name == names[ix]
        for t in time_steps
            expression_lb = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
            for val in range_data.additional_terms_lb[ix]
                JuMP.add_to_expression!(expression_lb, 
                                        get_variable(psi_container, val)[name, t], -1.0)
            end
            param[name, t] = PJ.add_parameter(psi_container.JuMPmodel,
                                              ts_data.ts_vectors[ix][t])
            constraint[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                                   expression_lb >= ts_data.multipliers[ix] * param[name, t])
        end
    end

    return

end

@doc raw"""
    device_timeseries_ub_bin(psi_container::PSIContainer,
                                    ts_data::DeviceTimeSeries,
                                    range_data::DeviceRange,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

Constructs upper bound for variable and time series or confines to 0 depending on binary variable.
    The upper bound is defined by a time series and a multiplier.

# Constraints

``` varcts[name, t] <= varbin[name, t]* ts_data.multipliers[ix] * ts_data.ts_vectors[ix][t] ```

where (ix, name) in enumerate(ts_data.names).

# LaTeX

`` x^{cts}_t \leq r^{val} r_t x^{bin}_t, \forall t ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::DeviceTimeSeries : container of device time series data and scaling factors
* range_data::DeviceRange : container of device range constraint modification data
* cons_name::Symbol : name of the constraint
* var_name::Symbol :  name of the variable
* binvar_name::Symbol : name of binary variable
"""
function device_timeseries_ub_bin(psi_container::PSIContainer,
                                    ts_data::DeviceTimeSeries,
                                    range_data::DeviceRange,
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

    time_steps = model_time_steps(psi_container)
    ub_name = _middle_rename(cons_name, "_", "ub")

    varcts = get_variable(psi_container, var_name)
    varbin = get_variable(psi_container, binvar_name)

    names = ts_data.names
    con_ub =add_cons_container!(psi_container, ub_name, names, time_steps)

    for (ix, name) in enumerate(range_data.names)
        @assert name = names[ix]
        for t in time_steps
            forecast = ts_data.ts_vectors[ix][t]
            multiplier = ts_data.multipliers[ix]
            expression_ub = JuMP.AffExpr(0.0, varcts[name, t] => 1.0)
            for val in range_data.additional_terms_ub[ix]
                JuMP.add_to_expression!(expression_ub, 
                                        get_variable(psi_container, val)[name, t])
            end
            con_ub[name, t] = JuMP.@constraint(psi_container.JuMPmodel, 
                                               expression_ub <= varbin[name, t]*multiplier*forecast)
        end
    end

    return

end

@doc raw"""
    device_timeseries_ub_bigM(psi_container::PSIContainer,
                                    ts_data::DeviceTimeSeries,
                                    range_data::DeviceRange,
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    param_reference::UpdateRef,
                                    binvar_name::Symbol,
                                    M_value::Float64 = 1e6)

Constructs upper bound for variable and time series and a multiplier or confines to 0 depending on binary variable.
    Uses BigM constraint type to allow for parameter since ParameterJuMP doesn't support var*parameter

# Constraints

``` varcts[name, t] - ts_data.multipliers[ix] * param[name, t] <= (1 - varbin[name, t])*M_value ```

``` varcts[name, t] <= varbin[name, t]*M_value ```

# LaTeX

`` x^{cts}_t - r^{val} x^{param}_t \leq M(1 - x^{bin}_t ), forall t ``

`` x^{cts}_t \leq M x^{bin}_t, \forall t ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::DeviceTimeSeries : container of device time series data and scaling factors
* range_data::DeviceRange : container of device range constraint modification data
* cons_name::Symbol : name of the constraint
* var_name::Symbol :  name of the variable
param_reference::UpdateRef : UpdateRef of access the parameters
* binvar_name::Symbol : name of binary variable
* M_value::Float64 : bigM
"""
function device_timeseries_ub_bigM(psi_container::PSIContainer,
                                    ts_data::DeviceTimeSeries,
                                    range_data::DeviceRange,
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    param_reference::UpdateRef,
                                    binvar_name::Symbol,
                                    M_value::Float64 = 1e6)
    time_steps = model_time_steps(psi_container)
    ub_name = _middle_rename(cons_name, "_", "ub")
    key_status = _middle_rename(cons_name, "_", "status")

    varcts = get_variable(psi_container, var_name)
    varbin = get_variable(psi_container, binvar_name)
    names = ts_data.names
    con_ub = add_cons_container!(psi_container, ub_name, names, time_steps)
    con_status =add_cons_container!(psi_container, key_status, names, time_steps)
    param =_add_param_container!(psi_container, param_reference, names, time_steps)

    for (ix, name) in enumerate(range_data.names)
        @assert name = names[ix]
        for t in time_steps
            expression_ub = JuMP.AffExpr(0.0, varcts[name, t] => 1.0)
            for val in range_data.additional_terms_ub[ix]
                JuMP.add_to_expression!(expression_ub, 
                                        get_variable(psi_container, val)[name, t])
            end
            param[name, t] = PJ.add_parameter(psi_container.JuMPmodel, ts_data.ts_vector[ix][t])
            con_ub[name, t] = JuMP.@constraint(psi_container.JuMPmodel, 
                expression_ub - param[name, t] * ts_data.multipliers[ix] <= (1 - varbin[name, t]) * M_value)
            con_status[name, t] =  JuMP.@constraint(psi_container.JuMPmodel, 
                expression_ub <= varbin[name, t]*M_value)
        end
    end

    return
end
