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
    ps_m.parameters[param_name] = JuMP.Containers.DenseAxisArray{PJ.ParameterRef}(undef, ts_data[1], time_steps)
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
    ps_m.parameters[param_name] = JuMP.Containers.DenseAxisArray{PJ.ParameterRef}(undef, ts_data[1], time_steps)
    ps_m.constraints[cons_name] = JuMPConstraintArray(undef, ts_data[1], time_steps)

    for t in time_steps, (ix, name) in enumerate(ts_data[1])

        ps_m.parameters[param_name][name, t] = PJ.add_parameter(ps_m.JuMPmodel, ts_data[2][ix][t])
        ps_m.constraints[cons_name][name, t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.parameters[param_name][name, t] <= ps_m.variables[var_name][name, t])

    end

    return

end
