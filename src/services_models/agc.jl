abstract type AbstractAGCFormulation <: AbstractServiceFormulation end
struct ReserveLimitedAGC <: AbstractAGCFormulation end

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

############################### Regulation Variables` #########################################
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
    dn_var = get_variable(psi_container, up_var_name)
    time_steps = model_time_steps(psi_container)
    names = (PSY.get_name(d) for d in contributing_devices)
    container =
        add_expression_container!(psi_container, :AGC_regulation_balance, names, time_steps)

    for t in time_steps, n in names
        container[n, t] = up_var[n, t] - dn_var[n, t]
    end

    return
end

function smooth_ace_pid!(psi_container::PSIContainer, service::PSY.AGC)
    kp = PSY.get_K_p(service)
    ki = PSY.get_K_i(service)
    kd = PSY.get_K_d(service)
    B = PSY.get_bias(service)
    Δt = convert(Dates.Second, psi_container.resolution).value

    time_steps = model_time_steps(psi_container)
    RAW_ACE = add_expression_container!(psi_container, :SACE, time_steps)
    SACE = add_var_container!(psi_container, variable_name("SACE", "AGC"), time_steps)
    remove_undef!(psi_container.expressions[:nodal_balance_active])
    for t in time_steps
        sys_bal = sum(psi_container.expressions[:nodal_balance_active].data[:, t])
        t == 1 && (RAW_ACE[t] = JuMP.AffExpr(0.0))
        RAW_ACE[t] = sys_bal # + (ΔPω⁺[i-1] - ΔPω⁻[i-1])
        SACE[t] = JuMP.@variable(psi_container.JuMPmodel, base_name = "SACE_{$(t)}")
    end

    SACE_pid = add_cons_container!(psi_container, :SACE_pid, time_steps)

    for t in time_steps[2:end]
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
