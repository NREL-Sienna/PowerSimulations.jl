function device_commitment(ps_m::CanonicalModel,
                        initial_conditions::Vector{InitialCondition},
                        cons_name::Symbol,
                        var_names::Tuple{Symbol, Symbol, Symbol})

    time_steps = model_time_steps(ps_m)
    var1 = var(ps_m, var_names[1])
    var2 = var(ps_m, var_names[2])
    var3 = var(ps_m, var_names[3])
    var1_names = axes(var1, 1)
    _add_cons_container!(ps_m, cons_name, var1_names, time_steps)
    constraint = con(ps_m, cons_name)

    for ic in initial_conditions
        name = PSY.get_name(ic.device)
        constraint[name, 1] = JuMP.@constraint(ps_m.JuMPmodel,
                               var3[name, 1] == ic.value + var1[name, 1] - var2[name, 1])
    end

    for t in time_steps[2:end], i in initial_conditions
        name = PSY.get_name(i.device)
        constraint[name, t] = JuMP.@constraint(ps_m.JuMPmodel,
                        var3[name, t] == var3[name, t-1] + var1[name, t] - var2[name, t])
    end

    return

end