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
    _add_param_container!(ps_m, param_name, ts_data[1], time_steps)
    param = par(ps_m, param_name)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])

        param[name, t] = PJ.add_parameter(ps_m.JuMPmodel, ts_data[2][ix][t]);
                                               JuMP.@constraint(ps_m.JuMPmodel, variable[name, t] >= 0.0)
        constraint[name, t] = JuMP.@constraint(ps_m.JuMPmodel, variable[name, t] <= param[name, t])

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
    _add_param_container!(ps_m, param_name, ts_data[1], time_steps)
    param = par(ps_m, param_name)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])

        param[name, t] = PJ.add_parameter(ps_m.JuMPmodel, ts_data[2][ix][t])
        constraint[name, t] = JuMP.@constraint(ps_m.JuMPmodel, param[name, t] <= variable[name, t])

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
    
    varcts = var(ps_m, var_name)
    varbin = var(ps_m, binvar_name)
   
    _add_cons_container!(ps_m, key_ub, ts_data[1], time_steps)
    _add_cons_container!(ps_m, key_lb, ts_data[1], time_steps)
    con_ub = con(ps_m, key_ub)
    con_lb = con(ps_m, key_lb)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])
        con_ub[name, t] =  JuMP.@constraint(ps_m.JuMPmodel, varcts[name, t] <= (varbin[name, t])*ts_data[2][ix][t])
        con_lb[name, t] =  JuMP.@constraint(ps_m.JuMPmodel, varcts[name, t] >= 0.0)
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
    
    #ps_m.parameters[param_name] = JuMPParamArray(undef, ts_data[1], time_steps)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])
        param[name, t] = PJ.add_parameter(ps_m.JuMPmodel, ts_data[2][ix][t]);
        con_ub[name, t] = JuMP.@constraint(ps_m.JuMPmodel, varcts[name, t] - param[name, t] <= (1 - varbin[name, t])*M_value)
        con_status[name, t] =  JuMP.@constraint(ps_m.JuMPmodel, varcts[name, t] <= (varbin[name, t])*M_value)
        con_lb[name, t] =  JuMP.@constraint(ps_m.JuMPmodel, varcts[name, t] >= 0.0)
    end

    return

end