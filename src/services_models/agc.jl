abstract type AbstractAGCFormulation <: AbstractServiceFormulation end
struct PIDSmoothACE <: AbstractAGCFormulation end

"""
Steady State deviation of the frequency
"""
function steady_state_frequency_variables!(psi_container::PSIContainer)
    time_steps = model_time_steps(psi_container)
    variable = JuMPVariableArray(undef, time_steps)
    assign_variable!(psi_container, variable_name("Δf"), variable)
    for t in time_steps
        variable[t] = JuMP.@variable(psi_container.JuMPmodel, base_name = "ΔF_{$(t)}")
    end
    return
end

function balancing_auxiliary_variables!(psi_container, sys)
    area_names = (PSY.get_name(a) for a in PSY.get_components(PSY.Area, sys))
    time_steps = model_time_steps(psi_container)
    variable = JuMPVariableArray(undef, area_names, time_steps)
    assign_variable!(psi_container, variable_name("area_total_reserve"), variable)
    for t in time_steps, a in area_names
        variable[a, t] =
            JuMP.@variable(psi_container.JuMPmodel, base_name = "R_{$(a),$(t)}")
    end
    return
end

function area_mismatch_variables!(psi_container::PSIContainer, areas)
    var_name = variable_name("area_mismatch")
    add_variable(psi_container, areas, var_name, false)
    add_variable(psi_container, areas, variable_name("z"), false; lb_value = x -> 0.0)
    return
end

function absolute_value_lift(psi_container::PSIContainer, areas)
    time_steps = model_time_steps(psi_container)
    area_names = (PSY.get_name(a) for a in areas)
    container_lb = JuMPConstraintArray(undef, area_names, time_steps)
    assign_constraint!(psi_container, "absolute_value_lb", container_lb)
    container_ub = JuMPConstraintArray(undef, area_names, time_steps)
    assign_constraint!(psi_container, "absolute_value_ub", container_ub)
    mismatch = get_variable(psi_container, :area_mismatch)
    z = get_variable(psi_container, :z)

    for t in time_steps, a in area_names
        container_lb[a, t] =
            JuMP.@constraint(psi_container.JuMPmodel, mismatch[a, t] <= z[a, t])
        container_ub[a, t] =
            JuMP.@constraint(psi_container.JuMPmodel, -1 * mismatch[a, t] <= z[a, t])
    end

    JuMP.add_to_expression!(
        psi_container.cost_function,
        sum(z[a, t] for t in time_steps, a in area_names) * SLACK_COST,
    )
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
    area_mismatch = get_variable(psi_container, :area_mismatch)
    frequency = get_variable(psi_container, variable_name("Δf"))
    container = JuMPConstraintArray(undef, time_steps)
    assign_constraint!(psi_container, "SACE_pid", container)
    for t in time_steps
        system_mismatch = sum(area_mismatch.data)
        container[t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            frequency[t] == -inv_frequency_reponse * system_mismatch
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
    area_mismatch = get_variable(psi_container, :area_mismatch)
    RAW_ACE = add_expression_container!(psi_container, :RAW_ACE, area_names, time_steps)
    SACE = JuMPVariableArray(undef, area_names, time_steps)
    assign_variable!(psi_container, variable_name("SACE"), SACE)
    area_balance = JuMPVariableArray(undef, area_names, time_steps)
    assign_variable!(psi_container, variable_name("area_dispatch_balance"), area_balance)
    SACE_pid = JuMPConstraintArray(undef, area_names, time_steps)
    assign_constraint!(psi_container, "SACE_pid", SACE_pid)

    Δf = get_variable(psi_container, variable_name("Δf"))

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
                RAW_ACE[a, t] = area_balance[a, t] - 10 * B * Δf[t] + SACE_ini.value
                SACE_pid[a, t] = JuMP.@constraint(
                    psi_container.JuMPmodel,
                    SACE[a, t] ==
                    RAW_ACE[a, t] +
                    kp * (
                        (1 + 1 / (kp / ki) + (kd / kp) / Δt) *
                        (RAW_ACE[a, t] - SACE[a, t]) +
                        (-1 - 2 * (kd / kp) / Δt) * (RAW_ACE[a, t] - SACE[a, t])
                    )
                )
                continue
            end

            RAW_ACE[a, t] =
                area_balance[a, t] - 10 * B * Δf[t] + area_mismatch[a, t - 1]

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
    area_mismatch = get_variable(psi_container, :area_mismatch)
    SACE = get_variable(psi_container, variable_name("SACE"))
    R = get_variable(psi_container, variable_name("area_total_reserve"))

    for t in time_steps, a in area_names
        aux_equation[a, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            -1*SACE[a, t] == R[a, t] - area_mismatch[a, t]
        )
    end
    return
end
