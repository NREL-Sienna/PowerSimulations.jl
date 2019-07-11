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

function device_timeseries_param_ub(ps_m::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    param_name::Symbol,
                                    var_name::Symbol)

    time_steps = model_time_steps(ps_m)
    variable = var(ps_m, var_name)
    _add_cons_container!(ps_m, cons_name, ts_data[1], time_steps)
    constraint = con(ps_m, cons_name)
    ps_m.parameters[param_name] = JuMPParamArray(undef, ts_data[1], time_steps)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])

        ps_m.parameters[param_name][name, t] = PJ.add_parameter(ps_m.JuMPmodel, ts_data[2][ix][t]);
                                               JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][name, t] >= 0.0)
        constraint[name, t] = JuMP.@constraint(ps_m.JuMPmodel, variable[name, t] <= ps_m.parameters[param_name][name, t])

    end

    return

end

function device_timeseries_param_lb(ps_m::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    param_name::Symbol,
                                    var_name::Symbol)

    time_steps = model_time_steps(ps_m)
    variable = var(ps_m, var_name)
    _add_cons_container!(ps_m, cons_name, ts_data[1], time_steps)
    constraint = con(ps_m, cons_name)
    ps_m.parameters[param_name] = JuMPParamArray(undef, ts_data[1], time_steps)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])

        ps_m.parameters[param_name][name, t] = PJ.add_parameter(ps_m.JuMPmodel, ts_data[2][ix][t])
        constraint[name, t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.parameters[param_name][name, t] <= variable[name, t])

    end

    return

end

function device_timeseries_ub_bin(ps_m::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

    time_steps = model_time_steps(ps_m)
    key_ub = Symbol("$(cons_name)_ub")
    key_lb = Symbol("$(cons_name)_lb")
    
    var1 = var(ps_m, var_name)
    varb = var(ps_m, binvar_name)
   
    _add_cons_container!(ps_m, key_ub, ts_data[1], time_steps)
    _add_cons_container!(ps_m, key_lb, ts_data[1], time_steps)
    con_key_ub = con(ps_m, key_ub)
    con_key_lb = con(ps_m, key_lb)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])
        con_key_ub[name, t] =  JuMP.@constraint(ps_m.JuMPmodel, var1[name, t] <= (varb[name, t])*ts_data[2][ix][t])
        con_key_lb[name, t] =  JuMP.@constraint(ps_m.JuMPmodel, var1[name, t] >= 0.0)
    end

    return

end

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
    
    var1 = var(ps_m, var_name)
    varb = var(ps_m, binvar_name)
    
    _add_cons_container!(ps_m, key_ub, ts_data[1], time_steps)
    _add_cons_container!(ps_m, key_status, ts_data[1], time_steps)
    _add_cons_container!(ps_m, key_lb, ts_data[1], time_steps)
    
    con_key_ub = con(ps_m, key_ub)
    con_key_status = con(ps_m, key_status)
    con_key_lb = con(ps_m, key_lb)

    ps_m.parameters[param_name] = JuMPParamArray(undef, ts_data[1], time_steps)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])
        ps_m.parameters[param_name][name, t] = PJ.add_parameter(ps_m.JuMPmodel, ts_data[2][ix][t]);
        con_key_ub[name, t] = JuMP.@constraint(ps_m.JuMPmodel, var1[name, t] - ps_m.parameters[param_name][name, t] 
                                                      <= (1 - varb[name, t])*M_value)
        con_key_status[name, t] =  JuMP.@constraint(ps_m.JuMPmodel, var1[name, t] <= (varb[name, t])*M_value)
        con_key_lb[name, t] =  JuMP.@constraint(ps_m.JuMPmodel, var1[name, t] >= 0.0)
    end

    return

end