function device_timeseries_ub(ps_m::CanonicalModel,
                              ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                              cons_name::Symbol,
                              var_name::Symbol)

    time_steps = model_time_steps(ps_m)
    ps_m.constraints[cons_name] = JuMPConstraintArray(undef, ts_data[1], time_steps)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])

        ps_m.constraints[cons_name][name, t] = JuMP.@constraint(ps_m.JuMPmodel, 0.0 <= ps_m.variables[var_name][name, t] <= ts_data[2][ix][t])

    end

    return

end

function device_timeseries_lb(ps_m::CanonicalModel,
                              ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                              cons_name::Symbol,
                              var_name::Symbol)

    time_steps = model_time_steps(ps_m)
    ps_m.constraints[cons_name] = JuMPConstraintArray(undef, ts_data[1], time_steps)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])

        ps_m.constraints[cons_name][name, t] = JuMP.@constraint(ps_m.JuMPmodel, ts_data[2][ix][t] <= ps_m.variables[var_name][name, t])

    end

    return

end

function device_timeseries_param_ub(ps_m::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    param_name::Symbol,
                                    var_name::Symbol)

    time_steps = model_time_steps(ps_m)
    ps_m.parameters[param_name] = JuMPParamArray(undef, ts_data[1], time_steps)
    ps_m.constraints[cons_name] = JuMPConstraintArray(undef, ts_data[1], time_steps)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])

        ps_m.parameters[param_name][name, t] = PJ.add_parameter(ps_m.JuMPmodel, ts_data[2][ix][t]);
                                               JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][name, t] >= 0.0)
        ps_m.constraints[cons_name][name, t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][name, t] <= ps_m.parameters[param_name][name, t])

    end

    return

end

function device_timeseries_param_lb(ps_m::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                                    cons_name::Symbol,
                                    param_name::Symbol,
                                    var_name::Symbol)

    time_steps = model_time_steps(ps_m)
    ps_m.parameters[param_name] = JuMPParamArray(undef, ts_data[1], time_steps)
    ps_m.constraints[cons_name] = JuMPConstraintArray(undef, ts_data[1], time_steps)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])

        ps_m.parameters[param_name][name, t] = PJ.add_parameter(ps_m.JuMPmodel, ts_data[2][ix][t])
        ps_m.constraints[cons_name][name, t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.parameters[param_name][name, t] <= ps_m.variables[var_name][name, t])

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

    ps_m.constraints[key_ub] = JuMPConstraintArray(undef, ts_data[1], time_steps)
    ps_m.constraints[key_lb] = JuMPConstraintArray(undef, ts_data[1], time_steps)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])
        ps_m.constraints[key_ub][name, t] =  JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][name, t] <= (ps_m.variables[binvar_name][name, t])*ts_data[2][ix][t])
        ps_m.constraints[key_lb][name, t] =  JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][name, t] >= 0.0)
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

    ps_m.parameters[param_name] = JuMPParamArray(undef, ts_data[1], time_steps)
    ps_m.constraints[key_ub] = JuMPConstraintArray(undef, ts_data[1], time_steps)
    ps_m.constraints[key_status] = JuMPConstraintArray(undef, ts_data[1], time_steps)
    ps_m.constraints[key_lb] = JuMPConstraintArray(undef, ts_data[1], time_steps)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])
        ps_m.parameters[param_name][name, t] = PJ.add_parameter(ps_m.JuMPmodel, ts_data[2][ix][t]);
        ps_m.constraints[key_ub][name, t] = JuMP.@constraint(ps_m.JuMPmodel,
                                                             ps_m.variables[var_name][name, t] - ps_m.parameters[var_name][name, t] <= (1 - ps_m.variables[binvar_name][name, t])*M_value)
        ps_m.constraints[key_status][name, t] =  JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][name, t] <= (ps_m.variables[binvar_name][name, t])*M_value)
        ps_m.constraints[key_lb][name, t] =  JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][name, t] >= 0.0)
    end

    return

end