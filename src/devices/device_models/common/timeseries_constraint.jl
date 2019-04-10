function device_timeseries_ub(ps_m::CanonicalModel,
                              ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                              time_range::UnitRange{Int64},
                              cons_name::Symbol,
                              var_name::Symbol)

    ps_m.constraints[cons_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, ts_data[1], time_range)

    for t in time_range, (ix, name) in enumerate(ts_data[1])

        ps_m.constraints[cons_name][name, t] = JuMP.@constraint(ps_m.JuMPmodel, 0.0 <= ps_m.variables[var_name][name, t] <= ts_data[2][ix][t])

    end

    return

end

function device_timeseries_lb(ps_m::CanonicalModel,
                              ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                              time_range::UnitRange{Int64},
                              cons_name::Symbol,
                              var_name::Symbol)

    ps_m.constraints[cons_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, ts_data[1], time_range)

    for t in time_range, (ix, name) in enumerate(ts_data[1])

        ps_m.constraints[cons_name][name, t] = JuMP.@constraint(ps_m.JuMPmodel, ts_data[2][ix][t] <= ps_m.variables[var_name][name, t])
                                              
    end

    return

end

function device_timeseries_param_ub(ps_m::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                                    time_range::UnitRange{Int64},
                                    cons_name::Symbol,
                                    param_name::Symbol,
                                    var_name::Symbol)

    ps_m.parameters[param_name] = JuMP.Containers.DenseAxisArray{PJ.Parameter}(undef, ts_data[1], time_range)
    ps_m.constraints[cons_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, ts_data[1], time_range)

    for t in time_range, (ix, name) in enumerate(ts_data[1])

        ps_m.parameters[param_name][name, t] = PJ.Parameter(ps_m.JuMPmodel, ts_data[2][ix][t]); 
                                               JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][name, t] >= 0.0)
        ps_m.constraints[cons_name][name, t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][name, t] <= ps_m.parameters[param_name][name, t])

    end

    return

end

function device_timeseries_param_lb(ps_m::CanonicalModel,
                                    ts_data::Tuple{Vector{String}, Vector{Vector{Float64}}},
                                    time_range::UnitRange{Int64},
                                    cons_name::Symbol,
                                    param_name::Symbol,
                                    var_name::Symbol)

ps_m.parameters[param_name] = JuMP.Containers.DenseAxisArray{PJ.Parameter}(undef, ts_data[1], time_range)
ps_m.constraints[cons_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, ts_data[1], time_range)

    for t in time_range, (ix, name) in enumerate(ts_data[1])

        ps_m.parameters[param_name][name, t] = PJ.Parameter(ps_m.JuMPmodel, ts_data[2][ix][t])
        ps_m.constraints[cons_name][name, t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.parameters[param_name][name, t] <= ps_m.variables[var_name][name, t])

    end

    return

end
