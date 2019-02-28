function norm_two_constraint(ps_m::CanonicalModel,
    range_data::Array{Tuple{String,Float64},1},
    time_range::UnitRange{Int64}, cons_name::String, var_name::(String,String))

    ps_m.constraints["$(cons_name)"] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, [r[1] for r in range_data], time_range)

    for t in time_range, r in range_data

            ps_m.constraints["$(cons_name)"][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, r[2]^2 == ps_m.variables["$(var_name[1])"][r[1], t] + ps_m.variables["$(var_name[2])"][r[1], t] )

    end

end