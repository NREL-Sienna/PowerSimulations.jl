function norm_two_constraint(ps_m::CanonicalModel,
                            rating_data::Vector{NamedMinMax},
                            cons_name::Symbol,
                            var_names::Tuple{Symbol, Symbol})

    time_steps = model_time_steps(ps_m)
    ps_m.constraints[cons_name] = JuMPConstraintArray(undef, (r[1] for r in rating_data), time_steps)

    for r in rating_data
        for t in time_steps
            ps_m.constraints[cons_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_names[1]][r[1], t] + ps_m.variables[var_names[2]][r[1], t] <= r[2].max^2)
        end
    end

    return

end