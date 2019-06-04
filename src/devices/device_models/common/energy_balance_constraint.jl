function energy_balance(ps_m::CanonicalModel,
                        initial_conditions::Vector{InitialCondition},
                        efficiency_data::Tuple{Vector{String},Vector{InOut}},
                        cons_name::Symbol,
                        var_names::Tuple{Symbol,Symbol,Symbol})

    time_steps = model_time_steps(ps_m)  
    resolution = model_resolution(ps_m)
    fraction_of_hour = Dates.value(Dates.Minute(resolution))/60
    name_index = efficiency_data[1]
    ps_m.constraints[cons_name] = JuMPConstraintArray(undef, name_index, time_steps)

    for (ix,name) in enumerate(name_index)
        eff_in = efficiency_data[2][ix].in
        eff_out = efficiency_data[2][ix].out

        ps_m.constraints[cons_name][name, 1] = JuMP.@constraint(ps_m.JuMPmodel,
                                                ps_m.variables[var_names[3]][name, 1] == initial_conditions[ix].value + ps_m.variables[var_names[1]][name, 1]*eff_in*fraction_of_hour - (ps_m.variables[var_names[2]][name, 1])*fraction_of_hour/eff_out)

    end

    for t in time_steps[2:end], (ix,name) in enumerate(name_index)
        eff_in = efficiency_data[2][ix].in
        eff_out = efficiency_data[2][ix].out

        ps_m.constraints[cons_name][name, t] = JuMP.@constraint(ps_m.JuMPmodel,
                                                ps_m.variables[var_names[3]][name, t] == ps_m.variables[var_names[3]][name, t-1] + ps_m.variables[var_names[1]][name, t]*eff_in - (ps_m.variables[var_names[2]][name, t])*fraction_of_hour/eff_out)

    end

    return

end
