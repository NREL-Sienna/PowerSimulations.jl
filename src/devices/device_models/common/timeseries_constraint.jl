function device_timeseries_ub(ps_m::CanonicalModel,
                              ts_data::Array{Tuple{String,Array{Float64,1}},1},
                              time_range::UnitRange{Int64},
                              cons_name::Symbol,
                              var_name::Symbol)

    ps_m.constraints[cons_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, [r[1] for r in ts_data], time_range)

    for t in time_range, r in ts_data

        ps_m.constraints[cons_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, 0.0 <= ps_m.variables[var_name][r[1], t] <= r[2][t])

    end

    return

end

function device_timeseries_lb(ps_m::CanonicalModel,
                              ts_data::Array{Tuple{String,Array{Float64,1}},1},
                              time_range::UnitRange{Int64},
                              cons_name::Symbol,
                              var_name::Symbol)

    ps_m.constraints[cons_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, [r[1] for r in ts_data], time_range)

    for t in time_range, r in ts_data

        ps_m.constraints[cons_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, r[2][t] <= ps_m.variables[var_name][r[1], t])
                                              
    end

    return

end

function device_timeseries_param_ub(ps_m::CanonicalModel,
                                    ts_data::Array{Tuple{String,Array{Float64,1}},1},
                                    time_range::UnitRange{Int64},
                                    cons_name::Symbol,
                                    param_name::Symbol,
                                    var_name::Symbol)

    ps_m.parameters[param_name] = JuMP.Containers.DenseAxisArray{ParameterJuMP.Parameter}(undef, [r[1] for r in ts_data], time_range)
    ps_m.constraints[cons_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, [r[1] for r in ts_data], time_range)

    for t in time_range, r in ts_data

        ps_m.parameters[param_name][r[1], t] = ParameterJuMP.Parameter(ps_m.JuMPmodel, r[2][t]); 
                                               JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][r[1], t] >= 0.0)
        ps_m.constraints[cons_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][r[1], t] <= ps_m.parameters[param_name][r[1], t])

    end

    return

end

function device_timeseries_param_lb(ps_m::CanonicalModel,
                                    ts_data::Array{Tuple{String,Array{Float64,1}},1},
                                    time_range::UnitRange{Int64},
                                    cons_name::Symbol,
                                    param_name::Symbol,
                                    var_name::Symbol)

ps_m.parameters[param_name] = JuMP.Containers.DenseAxisArray{ParameterJuMP.Parameter}(undef, [r[1] for r in ts_data], time_range)
ps_m.constraints[cons_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, [r[1] for r in ts_data], time_range)

    for t in time_range, r in ts_data

        ps_m.parameters[param_name][r[1], t] = ParameterJuMP.Parameter(ps_m.JuMPmodel, r[2][t])
        ps_m.constraints[cons_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.parameters[param_name][r[1], t] <= ps_m.variables[var_name][r[1], t])

    end

    return

end
