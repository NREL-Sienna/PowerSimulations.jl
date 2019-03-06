function energy_balance(ps_m::CanonicalModel, time_range::UnitRange{Int64}, initial_conditions::Array{Tuple{String,Float64},1},p_eff_data::Array{Tuple{String,Float64},1}, cons_name::String, var_names::Tuple{String,String,String})
    
    ps_m.constraints["$(cons_name)"] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, [i[1] for i in initial_conditions], time_range)
    # println(initial_conditions)
    for (ix,i) in enumerate(initial_conditions)

        ps_m.constraints["$(cons_name)"][i[1], 1] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables["$(var_names[3])"][i[1], 1] == i[2] + (ps_m.variables["$(var_names[1])"][i[1], 1])/p_eff_data[ix][2] - (ps_m.variables["$(var_names[2])"][i[1], 1])*p_eff_data[ix][2]) 

    end

    for t in time_range[2:end], (ix,i) in enumerate(initial_conditions)

        ps_m.constraints["$(cons_name)"][i[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables["$(var_names[3])"][i[1], t] == ps_m.variables["$(var_names[3])"][i[1], t-1] + (ps_m.variables["$(var_names[1])"][i[1], t])/p_eff_data[ix][2]  - (ps_m.variables["$(var_names[2])"][i[1], t])*p_eff_data[ix][2]) 

    end

    return nothing

end