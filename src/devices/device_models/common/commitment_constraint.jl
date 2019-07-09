function device_commitment(ps_m::CanonicalModel,
                        initial_conditions::Vector{InitialCondition},
                        cons_name::Symbol,
                        var_names::Tuple{Symbol,Symbol,Symbol})

    time_steps = model_time_steps(ps_m)  
    ps_m.constraints[cons_name] = JuMPConstraintArray(undef, ps_m.variables[var_names[1]].axes[1], time_steps)

    for i in initial_conditions

        name = PSY.get_name(i.device)
        ps_m.constraints[cons_name][name, 1] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_names[3]][name, 1] == i.value + ps_m.variables[var_names[1]][name, 1] - ps_m.variables[var_names[2]][name, 1])

    end

    for t in time_steps[2:end], i in initial_conditions

        name = PSY.get_name(i.device)
        ps_m.constraints[cons_name][name, t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_names[3]][name, t] == ps_m.variables[var_names[3]][name, t-1] + ps_m.variables[var_names[1]][name, t] - ps_m.variables[var_names[2]][name, t])

    end

    return

end