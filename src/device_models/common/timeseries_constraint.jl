function device_timeseries_ub(ps_m::CanonicalModel,
                              ts_data::Array{Tuple{String,Array{Float64,1}},1},
                              time_range::UnitRange{Int64},
                              cons_name::String,
                              var_name::String)

    ps_m.constraints["$(cons_name)"] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, [r[1] for r in ts_data], time_range)

    for t in time_range, r in ts_data

        ps_m.constraints["$(cons_name)"][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, 0.0 <= ps_m.variables["$(var_name)"][r[1], t] <= r[2][t])

    end

    return nothing

end

function device_timeseries_lb(ps_m::CanonicalModel,
                              ts_data::Array{Tuple{String,Array{Float64,1}},1},
                              time_range::UnitRange{Int64},
                              cons_name::String,
                              var_name::String)

    ps_m.constraints["$(cons_name)"] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, [r[1] for r in ts_data], time_range)

    for t in time_range, r in ts_data

        ps_m.constraints["$(cons_name)"][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, r[2][t] <= ps_m.variables["$(var_name)"][r[1], t])

    end

    return nothing

end