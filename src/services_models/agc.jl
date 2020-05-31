abstract type AbstractAGCFormulation <: AbstractServiceFormulation end
struct GeneratorLimitedAGC <: AbstractAGCFormulation end

"""
Steady State deviation of the frequency
"""
function steady_state_frequency_variables!(psi_container::PSIContainer)
    time_steps = model_time_steps(psi_container)
    variable = add_var_container!(psi_container, variable_name("Δf", "AGC"), time_steps)

    for t in time_steps
        variable[t] = JuMP.@variable(psi_container.JuMPmodel, base_name = "ΔF_{$(t)}")
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
    # This value is the one updated later in simulation
    inv_frequency_reponse = 1 / frequency_response
    area_unbalance = get_expression(psi_container, :area_unbalance)
    frequency = get_variable(psi_container, variable_name("Δf", "AGC"))
    container = add_cons_container!(psi_container, :frequency_response, time_steps)
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
    end

    return
end

"""
This function add the variables for reserves to the model
"""
function regulation_service_variables!(
    psi_container::PSIContainer,
    service::PSY.AGC,
    contributing_devices::Vector{<:PSY.Device},
)
    up_var_name = variable_name(PSY.get_name(service), "ΔP_UP")
    dn_var_name = variable_name(PSY.get_name(service), "ΔP_DN")
    # Upwards regulation
    add_variable(
        psi_container,
        contributing_devices,
        up_var_name,
        false;
        lb_value = x -> 0.0,
    )
    # Downwards regulation
    add_variable(
        psi_container,
        contributing_devices,
        dn_var_name,
        false;
        lb_value = x -> 0.0,
    )

    up_var = get_variable(psi_container, up_var_name)
    dn_var = get_variable(psi_container, dn_var_name)
    time_steps = model_time_steps(psi_container)
    names = (PSY.get_name(d) for d in contributing_devices)
    container = add_expression_container!(
        psi_container,
        :device_regulation_balance,
        names,
        time_steps,
    )

    for t in time_steps, n in names
        container[n, t] = JuMP.AffExpr(0.0, up_var[n, t] => 1.0, dn_var[n, t] => -1.0)
    end

    return
end

function smooth_ace_pid!(psi_container::PSIContainer, service::PSY.AGC)
    kp = PSY.get_K_p(service)
    ki = PSY.get_K_i(service)
    kd = PSY.get_K_d(service)
    B = PSY.get_bias(service)
    Δt = convert(Dates.Second, psi_container.resolution).value
    area_name = PSY.get_name(PSY.get_area(service))

    time_steps = model_time_steps(psi_container)
    remove_undef!(psi_container.expressions[:nodal_balance_active])
    area_unbalance = get_expression(psi_container, :area_unbalance)
    RAW_ACE = add_expression_container!(psi_container, :RAW_ACE, time_steps)
    SACE = add_var_container!(psi_container, variable_name("SACE", area_name), time_steps)
    area_balance = add_var_container!(
        psi_container,
        variable_name("area_balance", area_name),
        time_steps,
    )
    SACE_pid = JuMPConstraintArray(undef, time_steps)
    assign_constraint!(psi_container, "SACE_pid", SACE_pid)
    Δf = get_variable(psi_container, variable_name("Δf", "AGC"))
    for t in time_steps
        SACE[t] =
            JuMP.@variable(psi_container.JuMPmodel, base_name = "SACE_{$(area_name),$(t)}")
        area_balance[t] = JuMP.@variable(
            psi_container.JuMPmodel,
            base_name = "balance_{$(area_name),$(t)}"
        )
        if t == 1
            RAW_ACE[t] = JuMP.AffExpr(0.0)
            continue
        end

        RAW_ACE[t] = area_balance[t] - 10 * B * Δf[t - 1] + area_unbalance[area_name, t - 1]

        SACE_pid[t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            SACE[t] ==
            SACE[t - 1] +
            kp * (
                (1 + 1 / (kp / ki) + (kd / kp) / Δt) * (RAW_ACE[t] - SACE[t]) +
                (-1 - 2 * (kd / kp) / Δt) * (RAW_ACE[t] - SACE[t]) -
                ((kd / kp) / Δt) * (RAW_ACE[t - 1] - SACE[t - 1])
            )
        )
    end
    return
end

function participation_assignment!(psi_container::PSIContainer)
    JuMP.@constraint(zone_imbalance_pid, [k = 1:5, i = 1:N], ΔPg[k, i] == γ[k] * ΔP[i])
    JuMP.@constraint(
        zone_imbalance_pid,
        [i = 1:N],
        SACE_pid[i] == ΔP[i] - ΔPω⁺[i] + ΔPω⁻[i]
    )
end
