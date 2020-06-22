function lazy_lb(
    psi_container::PSIContainer,
    ts_data::Vector{DeviceTimeSeries},
    cons_name::Symbol,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    names = (d.name for d in ts_data)
    variable = get_variable(psi_container, var_name)
    lb_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "lb")
    con_lb = add_cons_container!(psi_container, lb_name, names, time_steps)

    for data in ts_data
        if data.range.limits.min > -Inf && !isempty(data.range.additional_terms_lb)
            con_lb[data.name, :].data .= JuMP.AffExpr(0.0)
            continue
        end
        for t in time_steps
            expression_lb = JuMP.AffExpr(0.0, variable[data.name, t] => 1.0)
            for val in data.range.additional_terms_lb
                JuMP.add_to_expression!(
                    expression_lb,
                    get_variable(psi_container, val)[data.name, t],
                    -1.0,
                )
            end
            lb_val = max(0.0, data.range.limits.min)
            con_lb[data.name, t] =
                JuMP.@constraint(psi_container.JuMPmodel, expression_lb >= lb_val)
        end
    end
    return
end

@doc raw"""
    device_timeseries_ub(psi_container::PSIContainer,
                     ts_data::Vector{DeviceTimeSeries},
                     cons_name::Symbol,
                     var_name::Symbol)

Constructs upper bound for given variable and time series data and a multiplier.

# Constraint

```variable[name, t] <= ts_data[name].multiplier * ts_data[name].timeseries[t] ```

# LaTeX

`` x_t \leq r^{val} r_t, \forall t ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::Vector{DeviceTimeSeries} : container of device time series data and scaling factors
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the variable
"""
function device_timeseries_ub(
    psi_container::PSIContainer,
    ts_data::Vector{DeviceTimeSeries},
    cons_name::Symbol,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    names = (d.name for d in ts_data)
    variable = get_variable(psi_container, var_name)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    con_ub = add_cons_container!(psi_container, ub_name, names, time_steps)
    lazy_add_lb = false

    for data in ts_data
        for t in time_steps
            expression_ub = JuMP.AffExpr(0.0, variable[data.name, t] => 1.0)
            for val in data.range.additional_terms_ub
                JuMP.add_to_expression!(
                    expression_ub,
                    get_variable(psi_container, val)[data.name, t],
                )
            end
            con_ub[data.name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                expression_ub <= data.multiplier * data.timeseries[t]
            )
        end
        if data.range.limits.min > -Inf || !isempty(data.range.additional_terms_lb)
            lazy_add_lb = true
        end
    end
    @debug lazy_add_lb
    lazy_add_lb && lazy_lb(psi_container, ts_data, cons_name, var_name)
    return
end

@doc raw"""
    device_timeseries_lb(psi_container::PSIContainer,
                     ts_data::Vector{DeviceTimeSeries},
                     cons_name::Symbol,
                     var_name::Symbol)

Constructs lower bound for given variable subject to time series data and a multiplier.

# Constraint

``` ts_data[name].multiplier * ts_data[name].timeseries[t] <= variable[name, t] ```

# LaTeX

`` r^{val} r_t \leq x_t, \forall t ``

where (name, data) in range_data.

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::Vector{DeviceTimeSeries} : container of device time series data and scaling factors
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the variable
"""
function device_timeseries_lb(
    psi_container::PSIContainer,
    ts_data::Vector{DeviceTimeSeries},
    cons_name::Symbol,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    lb_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "lb")
    names = (d.name for d in ts_data)
    constraint = add_cons_container!(psi_container, lb_name, names, time_steps)

    for data in ts_data
        for t in time_steps
            expression_lb = JuMP.AffExpr(0.0, variable[data.name, t] => 1.0)
            for val in data.range.additional_terms_lb
                JuMP.add_to_expression!(
                    expression_lb,
                    get_variable(psi_container, val)[data.name, t],
                    -1.0,
                )
            end
            constraint[data.name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                expression_lb >= data.multiplier * data.timeseries[t]
            )
        end
    end
    return
end

@doc raw"""
    device_timeseries_param_ub(psi_container::PSIContainer,
                                    ts_data::Vector{DeviceTimeSeries},
                                    cons_name::Symbol,
                                    param_reference::UpdateRef,
                                    var_name::Symbol)

Constructs upper bound for given variable using a parameter. The constraint is
    built with a time series data vector and a multiplier

# Constraint

``` variable[name, t] <= ts_data[name].multiplier * param[name, t] ```

# LaTeX

`` x^{var}_t \leq r^{val} x^{param}_t, \forall t ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::Vector{DeviceTimeSeries} : container of device time series data and scaling factors
* cons_name::Symbol : name of the constraint
* param_reference::UpdateRef : UpdateRef to access the parameter
* var_name::Symbol : the name of the variable
"""
function device_timeseries_param_ub(
    psi_container::PSIContainer,
    ts_data::Vector{DeviceTimeSeries},
    cons_name::Symbol,
    param_reference::UpdateRef,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    names = (d.name for d in ts_data)
    variable = get_variable(psi_container, var_name)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    con_ub = add_cons_container!(psi_container, ub_name, names, time_steps)
    container = add_param_container!(psi_container, param_reference, names, time_steps)
    multiplier = get_multiplier_array(container)
    param = get_parameter_array(container)
    lazy_add_lb = false

    for data in ts_data
        for t in time_steps
            expression_ub = JuMP.AffExpr(0.0, variable[data.name, t] => 1.0)
            for val in data.range.additional_terms_ub
                JuMP.add_to_expression!(
                    expression_ub,
                    get_variable(psi_container, val)[data.name, t],
                )
            end
            param[data.name, t] =
                PJ.add_parameter(psi_container.JuMPmodel, data.timeseries[t])
            con_ub[data.name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                expression_ub <= data.multiplier * param[data.name, t]
            )
            multiplier[data.name, t] = data.multiplier
        end
        if data.range.limits.min > -Inf || !isempty(data.range.additional_terms_lb)
            lazy_add_lb = true
        end
    end
    @debug lazy_add_lb
    lazy_add_lb && lazy_lb(psi_container, ts_data, cons_name, var_name)
    return
end

@doc raw"""
    device_timeseries_param_lb(psi_container::PSIContainer,
                                    ts_data::Vector{DeviceTimeSeries},
                                    cons_name::Symbol,
                                    param_reference::UpdateRef,
                                    var_name::Symbol)

Constructs lower bound for given variable using a parameter. The constraint is
    built with a time series data vector and a multiplier

# Constraint

``` ts_data[name].multiplier * param[name, t] <= variable[name, t] ```

# LaTeX

`` r^{val} x^{param}_t \leq x^{var}_t, \forall t ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::Vector{DeviceTimeSeries} : container of device time series data and scaling factors
* cons_name::Symbol : name of the constraint
* param_reference::UpdateRef : UpdateRef to access the parameter
* var_name::Symbol : the name of the variable
"""
function device_timeseries_param_lb(
    psi_container::PSIContainer,
    ts_data::Vector{DeviceTimeSeries},
    cons_name::Symbol,
    param_reference::UpdateRef,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    lb_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "lb")
    names = (d.name for d in ts_data)
    constraint = add_cons_container!(psi_container, lb_name, names, time_steps)
    container = add_param_container!(psi_container, param_reference, names, time_steps)
    multiplier = get_multiplier_array(container)
    param = get_parameter_array(container)

    for data in ts_data
        for t in time_steps
            expression_lb = JuMP.AffExpr(0.0, variable[data.name, t] => 1.0)
            for val in data.range.additional_terms_lb
                JuMP.add_to_expression!(
                    expression_lb,
                    get_variable(psi_container, val)[data.name, t],
                    -1.0,
                )
            end
            param[data.name, t] =
                PJ.add_parameter(psi_container.JuMPmodel, data.timeseries[t])
            constraint[data.name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                expression_lb >= data.multiplier * param[data.name, t]
            )
            multiplier[data.name, t] = data.multiplier
        end
    end

    return

end

@doc raw"""
    device_timeseries_ub_bin(psi_container::PSIContainer,
                                    ts_data::Vector{DeviceTimeSeries},
                                    var_name::Symbol,
                                    binvar_name::Symbol)

Constructs upper bound for variable and time series or confines to 0 depending on binary variable.
    The upper bound is defined by a time series and a multiplier.

# Constraints

``` varcts[name, t] <= varbin[name, t]* ts_data[name].multiplier * ts_data[name].timeseries[t] ```

where (name, data) in range_data.

# LaTeX

`` x^{cts}_t \leq r^{val} r_t x^{bin}_t, \forall t ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::Vector{DeviceTimeSeries} : container of device time series data and scaling factors
* cons_name::Symbol : name of the constraint
* var_name::Symbol :  name of the variable
* binvar_name::Symbol : name of binary variable
"""
function device_timeseries_ub_bin(
    psi_container::PSIContainer,
    ts_data::Vector{DeviceTimeSeries},
    cons_name::Symbol,
    var_name::Symbol,
    binvar_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    varcts = get_variable(psi_container, var_name)
    varbin = get_variable(psi_container, binvar_name)
    names = (d.name for d in ts_data)
    con_ub = add_cons_container!(psi_container, ub_name, names, time_steps)
    for data in ts_data
        for t in time_steps
            forecast = data.timeseries[t]
            multiplier = data.multiplier
            expression_ub = JuMP.AffExpr(0.0, varcts[data.name, t] => 1.0)
            for val in data.range.additional_terms_ub
                JuMP.add_to_expression!(
                    expression_ub,
                    get_variable(psi_container, val)[data.name, t],
                )
            end
            con_ub[data.name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                expression_ub <= varbin[data.name, t] * multiplier * forecast
            )
        end
    end
    return
end

@doc raw"""
    device_timeseries_ub_bigM(psi_container::PSIContainer,
                                    ts_data::Vector{DeviceTimeSeries},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    param_reference::UpdateRef,
                                    binvar_name::Symbol,
                                    M_value::Float64 = 1e6)

Constructs upper bound for variable and time series and a multiplier or confines to 0 depending on binary variable.
    Uses BigM constraint type to allow for parameter since ParameterJuMP doesn't support var*parameter

# Constraints

``` varcts[name, t] - ts_data[name].multipliers * param[name, t] <= (1 - varbin[name, t]) * M_value ```

``` varcts[name, t] <= varbin[name, t]*M_value ```

# LaTeX

`` x^{cts}_t - r^{val} x^{param}_t \leq M(1 - x^{bin}_t ), forall t ``

`` x^{cts}_t \leq M x^{bin}_t, \forall t ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::Vector{DeviceTimeSeries} : container of device time series data and scaling factors
* cons_name::Symbol : name of the constraint
* var_name::Symbol :  name of the variable
param_reference::UpdateRef : UpdateRef of access the parameters
* binvar_name::Symbol : name of binary variable
* M_value::Float64 : bigM
"""
function device_timeseries_ub_bigM(
    psi_container::PSIContainer,
    ts_data::Vector{DeviceTimeSeries},
    cons_name::Symbol,
    var_name::Symbol,
    param_reference::UpdateRef,
    binvar_name::Symbol,
    M_value::Float64 = 1e6,
)
    time_steps = model_time_steps(psi_container)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    key_status = middle_rename(cons_name, PSI_NAME_DELIMITER, "status")

    varcts = get_variable(psi_container, var_name)
    varbin = get_variable(psi_container, binvar_name)
    names = (d.name for d in ts_data)
    con_ub = add_cons_container!(psi_container, ub_name, names, time_steps)
    con_status = add_cons_container!(psi_container, key_status, names, time_steps)
    container = add_param_container!(psi_container, param_reference, names, time_steps)
    multiplier = get_multiplier_array(container)
    param = get_parameter_array(container)

    for data in ts_data
        for t in time_steps
            expression_ub = JuMP.AffExpr(0.0, varcts[data.name, t] => 1.0)
            for val in data.range.additional_terms_ub
                JuMP.add_to_expression!(
                    expression_ub,
                    get_variable(psi_container, val)[data.name, t],
                )
            end
            param[data.name, t] =
                PJ.add_parameter(psi_container.JuMPmodel, data.timeseries[t])
            con_ub[data.name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                expression_ub - param[data.name, t] * data.multiplier <=
                (1 - varbin[data.name, t]) * M_value
            )
            con_status[data.name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                expression_ub <= varbin[data.name, t] * M_value
            )
            multiplier[data.name, t] = data.multiplier
        end
    end
    return
end
