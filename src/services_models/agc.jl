abstract type AbstractAGCFormulation <: AbstractServiceFormulation end
struct GeneratorLimitedAGC <: AbstractAGCFormulation end

"""
Steady State deviation of the frequency
"""
function steady_state_frequency_variables!(psi_container::PSIContainer)
    time_steps = model_time_steps(psi_container)
    variable = JuMPVariableArray(undef, time_steps)
    assign_variable!(psi_container, variable_name("Δf", "AGC"), variable)
    for t in time_steps
        variable[t] = JuMP.@variable(psi_container.JuMPmodel, base_name = "ΔF_{$(t)}")
    end
    return
end

function balancing_auxiliary_variables!(psi_container, sys)
    area_names = (PSY.get_name(a) for a in PSY.get_components(PSY.Area, sys))
    time_steps = model_time_steps(psi_container)
    variable = JuMPVariableArray(undef, area_names, time_steps)
    assign_variable!(psi_container, variable_name("AGC_aux"), variable)
    for t in time_steps, a in area_names
        variable[a, t] =
            JuMP.@variable(psi_container.JuMPmodel, base_name = "ΔP_{$(a),$(t)}")
    end
    return
end

"""
Expression for the power deviation given deviation in the frequency. This expression allows updating the response of the frequency depending on commitment decisions
"""
function frequency_response_constraint!(psi_container::PSIContainer, sys::PSY.System)
    time_steps = model_time_steps(psi_container)
    frequency_response = 0.0
    for area in PSY.get_components(PSY.Area, sys)
        frequency_response += PSY.get_load_response(area)
    end
    for g in PSY.get_components(PSY.RegulationDevice, sys)
        d = PSY.get_droop(g)
        response = 1 / d
        frequency_response += response
    end

    @assert frequency_response >= 0.0
    # This value is the one updated later in simulation based on the UC result
    inv_frequency_reponse = 1 / frequency_response
    area_unbalance = get_expression(psi_container, :area_unbalance)
    frequency = get_variable(psi_container, variable_name("Δf", "AGC"))
    container = JuMPConstraintArray(undef, time_steps)
    assign_constraint!(psi_container, "SACE_pid", container)
    for t in time_steps
        system_unbalance = JuMP.AffExpr(0.0)
        for exp in area_unbalance[:, t].data
            system_unbalance += exp
        end
        container[t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            frequency[t] == -inv_frequency_reponse * system_unbalance
        )
    end
    return
end

############################### Regulation Variables` ######################################
function area_unbalance_variables!(psi_container::PSIContainer, areas)
    up_var_name = variable_name("UP", "Unbalance")
    dn_var_name = variable_name("DN", "Unbalance")
    # Upwards regulation
    add_variable(psi_container, areas, up_var_name, false; lb_value = x -> 0.0)
    # Downwards regulation
    add_variable(psi_container, areas, dn_var_name, false; lb_value = x -> 0.0)

    up_var = get_variable(psi_container, up_var_name)
    dn_var = get_variable(psi_container, dn_var_name)
    time_steps = model_time_steps(psi_container)
    names = (PSY.get_name(d) for d in areas)
    container = add_expression_container!(psi_container, :area_unbalance, names, time_steps)

    for t in time_steps, n in names
        container[n, t] = JuMP.AffExpr(0.0, up_var[n, t] => 1.0, dn_var[n, t] => -1.0)
        JuMP.add_to_expression!(
            psi_container.cost_function,
            (up_var[n, t] + dn_var[n, t]) * SLACK_COST,
        )
    end

    return
end

function smooth_ace_pid!(
    psi_container::PSIContainer,
    services::IS.FlattenIteratorWrapper{PSY.AGC},
)
    time_steps = model_time_steps(psi_container)
    area_names = (PSY.get_name(PSY.get_area(s)) for s in services)
    remove_undef!(psi_container.expressions[:nodal_balance_active])
    area_unbalance = get_expression(psi_container, :area_unbalance)
    RAW_ACE = add_expression_container!(psi_container, :RAW_ACE, area_names, time_steps)
    SACE = JuMPVariableArray(undef, area_names, time_steps)
    assign_variable!(psi_container, variable_name("SACE"), SACE)
    area_balance = JuMPVariableArray(undef, area_names, time_steps)
    assign_variable!(psi_container, variable_name("area_dispatch_balance"), area_balance)
    SACE_pid = JuMPConstraintArray(undef, area_names, time_steps)
    assign_constraint!(psi_container, "SACE_pid", SACE_pid)

    Δf = get_variable(psi_container, variable_name("Δf", "AGC"))

    for (ix, service) in enumerate(services)
        kp = PSY.get_K_p(service)
        ki = PSY.get_K_i(service)
        kd = PSY.get_K_d(service)
        B = PSY.get_bias(service)
        Δt = convert(Dates.Second, psi_container.resolution).value
        a = PSY.get_name(PSY.get_area(service))
        for t in time_steps
            SACE[a, t] =
                JuMP.@variable(psi_container.JuMPmodel, base_name = "SACE_{$(a),$(t)}")

            area_balance[a, t] =
                JuMP.@variable(psi_container.JuMPmodel, base_name = "balance_{$(a),$(t)}")
            if t == 1
                SACE_ini =
                    get_initial_conditions(psi_container, ICKey(AreaControlError, PSY.AGC))[ix]
                RAW_ACE[a, t] = area_balance[a, t] + SACE_ini.value
                SACE_pid[a, t] = JuMP.@constraint(
                    psi_container.JuMPmodel,
                    SACE[a, t] ==
                    SACE_ini.value +
                    kp * (
                        (1 + 1 / (kp / ki) + (kd / kp) / Δt) *
                        (RAW_ACE[a, t] - SACE[a, t]) +
                        (-1 - 2 * (kd / kp) / Δt) * (RAW_ACE[a, t] - SACE[a, t])
                    )
                )
                continue
            end

            RAW_ACE[a, t] =
                area_balance[a, t] - 10 * B * Δf[t - 1] + area_unbalance[a, t - 1]

            SACE_pid[a, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                SACE[a, t] ==
                SACE[a, t - 1] +
                kp * (
                    (1 + 1 / (kp / ki) + (kd / kp) / Δt) * (RAW_ACE[a, t] - SACE[a, t]) +
                    (-1 - 2 * (kd / kp) / Δt) * (RAW_ACE[a, t] - SACE[a, t]) -
                    ((kd / kp) / Δt) * (RAW_ACE[a, t - 1] - SACE[a, t - 1])
                )
            )
        end
    end
    return
end

function aux_constraints!(psi_container::PSIContainer, sys::PSY.System)
    time_steps = model_time_steps(psi_container)
    area_names = (PSY.get_name(a) for a in PSY.get_components(PSY.Area, sys))
    aux_equation = JuMPConstraintArray(undef, area_names, time_steps)
    assign_constraint!(psi_container, "balance_aux", aux_equation)
    area_unbalance = get_expression(psi_container, :area_unbalance)
    SACE = get_variable(psi_container, variable_name("SACE"))
    ΔP = get_variable(psi_container, variable_name("AGC_aux"))

    for t in time_steps, a in area_names
        aux_equation[a, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            ΔP[a, t] == SACE[a, t] - area_unbalance[a, t]
        )
    end

end
