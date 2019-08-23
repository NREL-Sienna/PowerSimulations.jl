@doc raw"""
    device_timeseries_ub(canonical_model::CanonicalModel,
                     ts_data::Tuple{Vector{String}, Vector{Float64}, Vector{Vector{Float64}}},
                     cons_name::Symbol,
                     var_name::Symbol)

Constructs upper bound for given variable and time series data and a multiplier.

# Constraint

```variable[name, t] <= ts_data[2][ix]*ts_data[3][ix][t] ```

# LaTeX

`` x_t \leq r^{val} r_t, \forall t ``

# Arguments
* canonical_model::CanonicalModel : the canonical model built in PowerSimulations
* ts_data::Tuple{Vector{String}, Vector{Float64}, Vector{Vector{Float64}}} : timeseries data name (1), multiplier (2) and values (3)
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the variable
"""
function device_timeseries_ub(canonical_model::CanonicalModel,
                              ts_data::Tuple{Vector{String}, Vector{Float64}, Vector{Vector{Float64}}},
                              cons_name::Symbol,
                              var_name::Symbol)

    time_steps = model_time_steps(canonical_model)
    variable = var(canonical_model, var_name)
    _add_cons_container!(canonical_model, cons_name, ts_data[1], time_steps)
    constraint = con(canonical_model, cons_name)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])

        constraint[name, t] = JuMP.@constraint(canonical_model.JuMPmodel,
                                    variable[name, t] <= ts_data[2][ix]*ts_data[3][ix][t])

    end

    return

end

@doc raw"""
    device_timeseries_lb(canonical_model::CanonicalModel,
                     ts_data::Tuple{Vector{String}, Vector{Float64}, Vector{Vector{Float64}}},
                     cons_name::Symbol,
                     var_name::Symbol)

Constructs lower bound for given variable subject to time series data and a multiplier.

# Constraint

``` ts_data[2][ix]*ts_data[3][ix][t] <= variable[name, t] ```

# LaTeX

`` r^{val} r_t \leq x_t, \forall t ``

where (ix, name) in enumerate(ts_data[1]).

# Arguments
* canonical_model::CanonicalModel : the canonical model built in PowerSimulations
* ts_data::Tuple{Vector{String}, Vector{Float64}, Vector{Vector{Float64}}} : timeseries data name (1), multiplier (2) and values (3)
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the variable
"""
function device_timeseries_lb(canonical_model::CanonicalModel,
                              ts_data::Tuple{Vector{String}, Vector{Float64}, Vector{Vector{Float64}}},
                              cons_name::Symbol,
                              var_name::Symbol)

    time_steps = model_time_steps(canonical_model)
    variable = var(canonical_model, var_name)
    _add_cons_container!(canonical_model, cons_name, ts_data[1], time_steps)
    constraint = con(canonical_model, cons_name)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])

        constraint[name, t] = JuMP.@constraint(canonical_model.JuMPmodel, ts_data[2][ix]*ts_data[3][ix][t] <= variable[name, t])

    end

    return

end

#NOTE: there is a floating, unnamed lower bound constraint in this function. This may need to be changed.
@doc raw"""
    device_timeseries_param_ub(canonical_model::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Float64}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    param_reference::RefParam,
                                    var_name::Symbol)

Constructs upper bound for given variable using a parameter. The constraint is
    built with a time series data vector and a multiplier

# Constraint

``` variable[name, t] <= ts_data[2][ix]*param[name, t] ```

# LaTeX

`` x^{var}_t \leq r^{val} x^{param}_t, \forall t ``

# Arguments
* canonical_model::CanonicalModel : the canonical model built in PowerSimulations
* ts_data::Tuple{Vector{String}, Vector{Float64}, Vector{Vector{Float64}}} : timeseries data name (1), multiplier (2) and values (3)
* cons_name::Symbol : name of the constraint
* param_reference::RefParam : RefParam to access the parameter
* var_name::Symbol : the name of the variable
"""
function device_timeseries_param_ub(canonical_model::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Float64}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    param_reference::RefParam,
                                    var_name::Symbol)

    time_steps = model_time_steps(canonical_model)
    ub_name = _middle_rename(cons_name, "_", "ub")
    variable = var(canonical_model, var_name)
    _add_cons_container!(canonical_model, ub_name, ts_data[1], time_steps)
    constraint = con(canonical_model, ub_name)
    _add_param_container!(canonical_model, param_reference, ts_data[1], time_steps)
    param = par(canonical_model, param_reference)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])
        param[name, t] = PJ.add_parameter(canonical_model.JuMPmodel, ts_data[3][ix][t])
        constraint[name, t] = JuMP.@constraint(canonical_model.JuMPmodel,
                                        variable[name, t] <= ts_data[2][ix]*param[name, t])
    end

    return

end

@doc raw"""
    device_timeseries_param_lb(canonical_model::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Float64}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    param_reference::RefParam,
                                    var_name::Symbol)

Constructs lower bound for given variable using a parameter. The constraint is
    built with a time series data vector and a multiplier

# Constraint

``` ts_data[2][ix] * param[name, t] <= variable[name, t] ```

# LaTeX

`` r^{val} x^{param}_t \leq x^{var}_t, \forall t ``

# Arguments
* canonical_model::CanonicalModel : the canonical model built in PowerSimulations
* ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}} : timeseries data name (1) and values (2)
* cons_name::Symbol : name of the constraint
* param_reference::RefParam : RefParam to access the parameter
* var_name::Symbol : the name of the variable
"""
function device_timeseries_param_lb(canonical_model::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Float64}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    param_reference::RefParam,
                                    var_name::Symbol)

    time_steps = model_time_steps(canonical_model)
    variable = var(canonical_model, var_name)
    lb_name = _middle_rename(cons_name, "_", "lb")
    _add_cons_container!(canonical_model, lb_name, ts_data[1], time_steps)
    constraint = con(canonical_model, lb_name)
    _add_param_container!(canonical_model, param_reference, ts_data[1], time_steps)
    param = par(canonical_model, param_reference)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])
        param[name, t] = PJ.add_parameter(canonical_model.JuMPmodel, ts_data[3][ix][t])
        constraint[name, t] = JuMP.@constraint(canonical_model.JuMPmodel, ts_data[2][ix]*param[name, t] <= variable[name, t])
    end

    return

end

@doc raw"""
    device_timeseries_ub_bin(canonical_model::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Float64}, Vector{Vector{Float64}}},
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
* canonical_model::CanonicalModel : the canonical model built in PowerSimulations
* ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}} : timeseries data name (1) and values (2)
* cons_name::Symbol : name of the constraint
* var_name::Symbol :  name of the variable
* binvar_name::Symbol : name of binary variable
"""
function device_timeseries_ub_bin(canonical_model::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Float64}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

    time_steps = model_time_steps(canonical_model)
    ub_name = _middle_rename(cons_name, "_", "ub")

    varcts = var(canonical_model, var_name)
    varbin = var(canonical_model, binvar_name)

    _add_cons_container!(canonical_model, ub_name, ts_data[1], time_steps)
    con_ub = con(canonical_model, ub_name)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])
        con_ub[name, t] = JuMP.@constraint(canonical_model.JuMPmodel, varcts[name, t] <= varbin[name, t]*ts_data[2][ix]*ts_data[3][ix][t])
    end

    return

end

@doc raw"""
    device_timeseries_ub_bigM(canonical_model::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Float64}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    param_reference::RefParam,
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
* canonical_model::CanonicalModel : the canonical model built in PowerSimulations
* ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}} : timeseries data name (1) and values (2)
* cons_name::Symbol : name of the constraint
* var_name::Symbol :  name of the variable
param_reference::RefParam : RefParam of access the parameters
* binvar_name::Symbol : name of binary variable
* M_value::Float64 : bigM
"""
function device_timeseries_ub_bigM(canonical_model::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Float64},Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    param_reference::RefParam,
                                    binvar_name::Symbol,
                                    M_value::Float64 = 1e6)

    time_steps = model_time_steps(canonical_model)
    ub_name = _middle_rename(cons_name, "_", "ub")
    key_status = _middle_rename(cons_name, "_", "status")

    varcts = var(canonical_model, var_name)
    varbin = var(canonical_model, binvar_name)

    _add_cons_container!(canonical_model, ub_name, ts_data[1], time_steps)
    _add_cons_container!(canonical_model, key_status, ts_data[1], time_steps)
    con_ub = con(canonical_model, ub_name)
    con_status = con(canonical_model, key_status)

    _add_param_container!(canonical_model, param_reference, ts_data[1], time_steps)
    param = par(canonical_model, param_reference)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])
        param[name, t] = PJ.add_parameter(canonical_model.JuMPmodel, ts_data[3][ix][t])
        con_ub[name, t] = JuMP.@constraint(canonical_model.JuMPmodel, varcts[name, t] - param[name, t]*ts_data[2][ix] <= (1 - varbin[name, t])*M_value)
        con_status[name, t] =  JuMP.@constraint(canonical_model.JuMPmodel, varcts[name, t] <= varbin[name, t]*M_value)
    end

    return

end
