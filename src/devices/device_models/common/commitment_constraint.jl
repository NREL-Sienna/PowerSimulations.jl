function device_commitment(ps_m::CanonicalModel,
                        initial_conditions::Vector{InitialCondition},
                        lookahead::UnitRange{Int64},
                        cons_name::Symbol,
                        var_names::Tuple{Symbol,Symbol,Symbol})

    ps_m.constraints[cons_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, ps_m.variables[var_names[1]].axes[1], lookahead)

    for i in initial_conditions

        ps_m.constraints[cons_name][i.device.name, 1] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_names[3]][i.device.name, 1] == i.value + ps_m.variables[var_names[1]][i.device.name, 1] - ps_m.variables[var_names[2]][i.device.name, 1])

    end

    for t in lookahead[2:end], i in initial_conditions

        ps_m.constraints[cons_name][i.device.name, t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_names[3]][i.device.name, t] == ps_m.variables[var_names[3]][i.device.name, t-1] + ps_m.variables[var_names[1]][i.device.name, t] - ps_m.variables[var_names[2]][i.device.name, t])

    end

    return

end