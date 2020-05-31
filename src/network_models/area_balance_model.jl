function area_balance(
    psi_container::PSIContainer,
    expression::Symbol,
    area_mapping::Dict{String, Array{PSY.Bus, 1}},
    branches,
)
    time_steps = model_time_steps(psi_container)
    remove_undef!(psi_container.expressions[expression])
    nodal_net_balance = psi_container.expressions[expression]

    for (k, buses_in_area) in area_mapping
        constraint_val = JuMPConstraintArray(undef, time_steps)
        assign_constraint!(psi_container, "Balance_area_$(k)", constraint_val)
        area_balance = get_variable(psi_container, variable_name("area_balance", "$(k)"))
        for t in time_steps
            area_net = JuMP.AffExpr(0.0)
            for b in buses_in_area
                JuMP.add_to_expression!(area_net, nodal_net_balance[PSY.get_number(b), t])
                constraint_val[t] =
                    JuMP.@constraint(psi_container.JuMPmodel, area_balance[t] == area_net)
            end
        end
    end
    return
end
