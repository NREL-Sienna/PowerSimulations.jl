function device_commitment(ps_m::CanonicalModel, initial_conditions::Array{Tuple{String,Float64},1}, time_range::UnitRange{Int64}, cons_name::String, var_names::Tuple{String,String,String})

    ps_m.constraints["$(cons_name)"] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, [i[1] for i in initial_conditions], time_range)

    for i in initial_conditions

        ps_m.constraints["$(cons_name)"][i[1], 1] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables["$(var_names[3])"][i[1], 1] == i[2] + ps_m.variables["$(var_names[1])"][i[1], 1] - ps_m.variables["$(var_names[2])"][i[1], 1])

    end

    for t in time_range[2:end], i in initial_conditions

        ps_m.constraints["$(cons_name)"][i[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables["$(var_names[3])"][i[1], t] == ps_m.variables["$(var_names[3])"][i[1], t-1] + ps_m.variables["$(var_names[1])"][i[1], t] - ps_m.variables["$(var_names[2])"][i[1], t])

    end

end