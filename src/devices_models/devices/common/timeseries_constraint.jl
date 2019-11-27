@doc raw"""
    device_timeseries_ub(psi_container::PSIContainer,
                     ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}}
                     cons_name::Symbol,
                     var_name::Symbol)

Constructs upper bound for given variable and time series data and a multiplier.

# Constraint

```variable[name, t] <= ts_data[2][ix]*ts_data[3][ix][t] ```

# LaTeX

`` x_t \leq r^{val} r_t, \forall t ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}}: timeseries data name (1), multiplier (2) and values (3)
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the variable
"""
function device_timeseries_ub(psi_container::PSIContainer,
                              ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}},
                              cons_name::Symbol,
                              var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    names = (v[1] for v in ts_data)
    constraint = add_cons_container!(psi_container, cons_name, names, time_steps)
    variable = get_variable(psi_container, var_name)

    for t in time_steps, data in ts_data
        name = data[1]
        forecast = data[4][t]
        multiplier = data[3]
        constraint[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                    variable[name, t] <= multiplier*forecast)

    end

    return
end

@doc raw"""
    device_timeseries_lb(psi_container::PSIContainer,
                     ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}}
                     cons_name::Symbol,
                     var_name::Symbol)

Constructs lower bound for given variable subject to time series data and a multiplier.

# Constraint

``` ts_data[2][ix]*ts_data[3][ix][t] <= variable[name, t] ```

# LaTeX

`` r^{val} r_t \leq x_t, \forall t ``

where (ix, name) in enumerate(ts_data[1]).

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}}: timeseries data name (1), multiplier (2) and values (3)
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the variable
"""
function device_timeseries_lb(psi_container::PSIContainer,
                              ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}},
                              cons_name::Symbol,
                              var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    names = (v[1] for v in ts_data)
    constraint =add_cons_container!(psi_container, cons_name, names, time_steps)
    variable = get_variable(psi_container, var_name)

    for t in time_steps, data in ts_data
        name = data[1]
        forecast = data[4][t]
        multiplier = data[3]
        constraint[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                        multiplier*forecast <= variable[name, t])

    end

    return
end

#NOTE: there is a floating, unnamed lower bound constraint in this function. This may need to be changed.
@doc raw"""
    device_timeseries_param_ub(psi_container::PSIContainer,
                                    ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}}
                                    cons_name::Symbol,
                                    param_reference::UpdateRef,
                                    var_name::Symbol)

Constructs upper bound for given variable using a parameter. The constraint is
    built with a time series data vector and a multiplier

# Constraint

``` variable[name, t] <= ts_data[2][ix]*param[name, t] ```

# LaTeX

`` x^{var}_t \leq r^{val} x^{param}_t, \forall t ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}}: timeseries data name (1), multiplier (2) and values (3)
* cons_name::Symbol : name of the constraint
* param_reference::UpdateRef : UpdateRef to access the parameter
* var_name::Symbol : the name of the variable
"""
function device_timeseries_param_ub(psi_container::PSIContainer,
                                    ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}},
                                    cons_name::Symbol,
                                    param_reference::UpdateRef,
                                    var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    ub_name = _middle_rename(cons_name, "_", "ub")
    variable = get_variable(psi_container, var_name)
    names = (v[1] for v in ts_data)
    constraint = add_cons_container!(psi_container, ub_name, names, time_steps)
    param = _add_param_container!(psi_container, param_reference, names, time_steps)

    for t in time_steps, data in ts_data
        name = data[1]
        forecast = data[4][t]
        multiplier = data[3]
        param[name, t] = PJ.add_parameter(psi_container.JuMPmodel, forecast)
        constraint[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                        variable[name, t] <= multiplier*param[name, t])
    end

    return
end

@doc raw"""
    device_timeseries_param_lb(psi_container::PSIContainer,
                                    ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}}
                                    cons_name::Symbol,
                                    param_reference::UpdateRef,
                                    var_name::Symbol)

Constructs lower bound for given variable using a parameter. The constraint is
    built with a time series data vector and a multiplier

# Constraint

``` ts_data[2][ix] * param[name, t] <= variable[name, t] ```

# LaTeX

`` r^{val} x^{param}_t \leq x^{var}_t, \forall t ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}} : timeseries data name (1) and values (2)
* cons_name::Symbol : name of the constraint
* param_reference::UpdateRef : UpdateRef to access the parameter
* var_name::Symbol : the name of the variable
"""
function device_timeseries_param_lb(psi_container::PSIContainer,
                                    ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}},
                                    cons_name::Symbol,
                                    param_reference::UpdateRef,
                                    var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    lb_name = _middle_rename(cons_name, "_", "lb")
    names = (v[1] for v in ts_data)
    constraint =add_cons_container!(psi_container, lb_name, names, time_steps)
    param =_add_param_container!(psi_container, param_reference, names, time_steps)

    for t in time_steps, data in ts_data
        name = data[1]
        forecast = data[4][t]
        multiplier = data[3]
        param[name, t] = PJ.add_parameter(psi_container.JuMPmodel, forecast)
        constraint[name, t] = JuMP.@constraint(psi_container.JuMPmodel, multiplier*param[name, t] <= variable[name, t])
    end

    return

end

@doc raw"""
    device_timeseries_ub_bin(psi_container::PSIContainer,
                                    ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}}
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

Constructs upper bound for variable and time series or confines to 0 depending on binary variable.
    The upper bound is defined by a time series and a multiplier.

# Constraints

``` varcts[name, t] <= varbin[name, t]* ts_data[2][ix] * ts_data[3][ix][t] ```

where (ix, name) in enumerate(ts_data[1]).

# LaTeX

`` x^{cts}_t \leq r^{val} r_t x^{bin}_t, \forall t ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}} : timeseries data name (1) and values (2)
* cons_name::Symbol : name of the constraint
* var_name::Symbol :  name of the variable
* binvar_name::Symbol : name of binary variable
"""
function device_timeseries_ub_bin(psi_container::PSIContainer,
                                    ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

    time_steps = model_time_steps(psi_container)
    ub_name = _middle_rename(cons_name, "_", "ub")

    varcts = get_variable(psi_container, var_name)
    varbin = get_variable(psi_container, binvar_name)

    names = (v[1] for v in ts_data)
    con_ub =add_cons_container!(psi_container, ub_name, names, time_steps)

    for t in time_steps, data in ts_data
        name = data[1]
        forecast = data[4][t]
        multiplier = data[3]
        con_ub[name, t] = JuMP.@constraint(psi_container.JuMPmodel, varcts[name, t] <= varbin[name, t]*multiplier*forecast)
    end

    return

end

@doc raw"""
    device_timeseries_ub_bigM(psi_container::PSIContainer,
                                    ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}}
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    param_reference::UpdateRef,
                                    binvar_name::Symbol,
                                    M_value::Float64 = 1e6)

Constructs upper bound for variable and time series and a multiplier or confines to 0 depending on binary variable.
    Uses BigM constraint type to allow for parameter since ParameterJuMP doesn't support var*parameter

# Constraints

``` varcts[name, t] - ts_data[2][ix] * param[name, t] <= (1 - varbin[name, t])*M_value ```

``` varcts[name, t] <= varbin[name, t]*M_value ```

# LaTeX

`` x^{cts}_t - r^{val} x^{param}_t \leq M(1 - x^{bin}_t ), forall t ``

`` x^{cts}_t \leq M x^{bin}_t, \forall t ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}} : timeseries data name (1) and values (2)
* cons_name::Symbol : name of the constraint
* var_name::Symbol :  name of the variable
param_reference::UpdateRef : UpdateRef of access the parameters
* binvar_name::Symbol : name of binary variable
* M_value::Float64 : bigM
"""
function device_timeseries_ub_bigM(psi_container::PSIContainer,
                                    ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}},
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
    names = (v[1] for v in ts_data)
    con_ub = add_cons_container!(psi_container, ub_name, names, time_steps)
    con_status =add_cons_container!(psi_container, key_status, names, time_steps)
    param =_add_param_container!(psi_container, param_reference, names, time_steps)

    for t in time_steps, data in ts_data
        name = data[1]
        forecast = data[4][t]
        multiplier = data[3]
        param[name, t] = PJ.add_parameter(psi_container.JuMPmodel, forecast)
        con_ub[name, t] = JuMP.@constraint(psi_container.JuMPmodel, varcts[name, t] - param[name, t]*multiplier <= (1 - varbin[name, t])*M_value)
        con_status[name, t] =  JuMP.@constraint(psi_container.JuMPmodel, varcts[name, t] <= varbin[name, t]*M_value)
    end

    return
end
