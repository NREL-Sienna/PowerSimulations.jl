@doc raw"""
    device_timeseries_ub(ps_m::CanonicalModel,
                     ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                     cons_name::Symbol,
                     var_name::Symbol)

Constructs upper bound (and 0 as lower bound) for given variable and time series data.

# Constraint

``` 0.0 <= variable[name, t] <= ts_data[2][ix][t] ```

# LaTeX

`` 0 \leq x_t \leq r^{max}_t, \forall t ``

# Arguments
* ps_m::CanonicalModel : the canonical model built in PowerSimulations
* ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}} : timeseries data name (1) and values (2)
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the variable
"""
function device_timeseries_ub(ps_m::CanonicalModel,
                              ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                              cons_name::Symbol,
                              var_name::Symbol)

    time_steps = model_time_steps(ps_m)
    variable = var(ps_m, var_name)
    _add_cons_container!(ps_m, cons_name, ts_data[1], time_steps)
    constraint = con(ps_m, cons_name)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])

        constraint[name, t] = JuMP.@constraint(ps_m.JuMPmodel, 0.0 <= variable[name, t] <= ts_data[2][ix][t])

    end

    return

end

@doc raw"""
    device_timeseries_lb(ps_m::CanonicalModel,
                     ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                     cons_name::Symbol,
                     var_name::Symbol)

Constructs lower bound for given variable and time series data.

# Constraint

``` ts_data[2][ix][t] <= variable[name, t] ```

# LaTeX

`` r^{min}_t \leq x_t, \forall t `` 

where (ix, name) in enumerate(ts_data[1]).

# Arguments
* ps_m::CanonicalModel : the canonical model built in PowerSimulations
* ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}} : timeseries data name (1) and values (2)
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the variable
"""
function device_timeseries_lb(ps_m::CanonicalModel,
                              ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                              cons_name::Symbol,
                              var_name::Symbol)

    time_steps = model_time_steps(ps_m)
    variable = var(ps_m, var_name)
    _add_cons_container!(ps_m, cons_name, ts_data[1], time_steps)
    constraint = con(ps_m, cons_name)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])

        constraint[name, t] = JuMP.@constraint(ps_m.JuMPmodel, ts_data[2][ix][t] <= variable[name, t])

    end

    return

end

#NOTE: there is a floating, unnamed lower bound constraint in this function. This may need to be changed.
@doc raw"""
    device_timeseries_param_ub(ps_m::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    param_name::Symbol,
                                    var_name::Symbol)

Constructs upper bound for given variable and time series data parameter as upper bound.

# Constraint

``` variable[name, t] <= param[name, t] ```

# LaTeX

`` x^{var}_t \leq x^{param}_t, \forall t ``

# Arguments
* ps_m::CanonicalModel : the canonical model built in PowerSimulations
* ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}} : timeseries data name (1) and values (2)
* cons_name::Symbol : name of the constraint
* param_name::Symbol : name of the parameter
* var_name::Symbol : the name of the variable
"""
function device_timeseries_param_ub(ps_m::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    param_name::Symbol,
                                    var_name::Symbol)

    time_steps = model_time_steps(ps_m)
    variable = var(ps_m, var_name)
    _add_cons_container!(ps_m, cons_name, ts_data[1], time_steps)
    constraint = con(ps_m, cons_name)
    _add_param_container!(ps_m, param_name, ts_data[1], time_steps)
    param = par(ps_m, param_name)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])

        param[name, t] = PJ.add_parameter(ps_m.JuMPmodel, ts_data[2][ix][t]);
                JuMP.@constraint(ps_m.JuMPmodel, variable[name, t] >= 0.0)
        constraint[name, t] = JuMP.@constraint(ps_m.JuMPmodel, variable[name, t] <= param[name, t])

    end

    return

end

@doc raw"""
    device_timeseries_param_lb(ps_m::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    param_name::Symbol,
                                    var_name::Symbol)

Constructs upper bound for given variable and time series data parameter as upper bound.

# Constraint

``` param[name, t] <= variable[name, t] ```

# LaTeX

`` x^{param}_t \leq x^{var}_t, \forall t ``

# Arguments
* ps_m::CanonicalModel : the canonical model built in PowerSimulations
* ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}} : timeseries data name (1) and values (2)
* cons_name::Symbol : name of the constraint
* param_name::Symbol : name of the parameter
* var_name::Symbol : the name of the variable
"""
function device_timeseries_param_lb(ps_m::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    param_name::Symbol,
                                    var_name::Symbol)

    time_steps = model_time_steps(ps_m)
    variable = var(ps_m, var_name)
    _add_cons_container!(ps_m, cons_name, ts_data[1], time_steps)
    constraint = con(ps_m, cons_name)
    _add_param_container!(ps_m, param_name, ts_data[1], time_steps)
    param = par(ps_m, param_name)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])

        param[name, t] = PJ.add_parameter(ps_m.JuMPmodel, ts_data[2][ix][t])
        constraint[name, t] = JuMP.@constraint(ps_m.JuMPmodel, param[name, t] <= variable[name, t])

    end

    return

end

@doc raw"""
    device_timeseries_ub_bin(ps_m::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

Constructs upper bound (with lower bound 0) for variable and time series or confines to 0 depending on binary variable.

# Constraints

``` varcts[name, t] <= varbin[name, t]*ts_data[2][ix][t] ```

``` varcts[name, t] >= 0.0 ```

where (ix, name) in enumerate(ts_data[1]).

# LaTeX

`` 0 \leq x^{cts}_t \leq r^{max}_t x^{bin}_t, \forall t ``

# Arguments
* ps_m::CanonicalModel : the canonical model built in PowerSimulations
* ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}} : timeseries data name (1) and values (2)
* cons_name::Symbol : name of the constraint
* var_name::Symbol :  name of the variable
* binvar_name::Symbol : name of binary variable
"""
function device_timeseries_ub_bin(ps_m::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

    time_steps = model_time_steps(ps_m)
    key_ub = Symbol("$(cons_name)_ub")
    key_lb = Symbol("$(cons_name)_lb")
    
    varcts = var(ps_m, var_name)
    varbin = var(ps_m, binvar_name)
   
    _add_cons_container!(ps_m, key_ub, ts_data[1], time_steps)
    _add_cons_container!(ps_m, key_lb, ts_data[1], time_steps)
    con_ub = con(ps_m, key_ub)
    con_lb = con(ps_m, key_lb)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])
        con_ub[name, t] =  JuMP.@constraint(ps_m.JuMPmodel, varcts[name, t] <= varbin[name, t]*ts_data[2][ix][t])
        con_lb[name, t] =  JuMP.@constraint(ps_m.JuMPmodel, varcts[name, t] >= 0.0)
    end

    return

end

@doc raw"""
    device_timeseries_ub_bigM(ps_m::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    param_name::Symbol,
                                    binvar_name::Symbol,
                                    M_value::Float64 = 1e6)

Constructs upper bound (with lower bound 0) for variable and time series or confines to 0 depending on binary variable.
Uses BigM constraint type to allow for parameter.

# Constraints

``` varcts[name, t] - param[name, t] <= (1 - varbin[name, t])*M_value ```

``` varcts[name, t] <= varbin[name, t]*M_value ```

``` varcts[name, t] >= 0.0 ```

# LaTeX

`` x^{cts}_t - x^{param}_t \leq M(1 - x^{bin}_t ), forall t ``

`` 0 \leq x^{cts}_t \leq M x^{bin}_t, \forall t ``

# Arguments
* ps_m::CanonicalModel : the canonical model built in PowerSimulations
* ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}} : timeseries data name (1) and values (2)
* cons_name::Symbol : name of the constraint
* var_name::Symbol :  name of the variable
* binvar_name::Symbol : name of binary variable
* M_value::Float64 : bigM
"""
function device_timeseries_ub_bigM(ps_m::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    param_name::Symbol,
                                    binvar_name::Symbol,
                                    M_value::Float64 = 1e6)

    time_steps = model_time_steps(ps_m)
    key_ub = Symbol("$(cons_name)_ub")
    key_lb = Symbol("$(cons_name)_lb")
    key_status = Symbol("$(cons_name)_status")
    
    varcts = var(ps_m, var_name)
    varbin = var(ps_m, binvar_name)
    
    _add_cons_container!(ps_m, key_ub, ts_data[1], time_steps)
    _add_cons_container!(ps_m, key_status, ts_data[1], time_steps)
    _add_cons_container!(ps_m, key_lb, ts_data[1], time_steps)
    con_ub = con(ps_m, key_ub)
    con_status = con(ps_m, key_status)
    con_lb = con(ps_m, key_lb)
    
    _add_param_container!(ps_m, param_name, ts_data[1], time_steps)
    param = par(ps_m, param_name)
    
    for t in time_steps, (ix, name) in enumerate(ts_data[1])
        param[name, t] = PJ.add_parameter(ps_m.JuMPmodel, ts_data[2][ix][t]);
        con_ub[name, t] = JuMP.@constraint(ps_m.JuMPmodel, varcts[name, t] - param[name, t] <= (1 - varbin[name, t])*M_value)
        con_status[name, t] =  JuMP.@constraint(ps_m.JuMPmodel, varcts[name, t] <= varbin[name, t]*M_value)
        con_lb[name, t] =  JuMP.@constraint(ps_m.JuMPmodel, varcts[name, t] >= 0.0)
    end

    return

end