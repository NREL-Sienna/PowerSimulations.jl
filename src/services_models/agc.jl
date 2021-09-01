#! format: off

abstract type AbstractAGCFormulation <: AbstractServiceFormulation end
struct PIDSmoothACE <: AbstractAGCFormulation end

get_variable_multiplier(_, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = NaN
########################## ActivePowerVariable, Area ###########################

########################## SteadyStateFrequencyDeviation ##################################
get_variable_binary(::SteadyStateFrequencyDeviation, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = false

get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = false

########################## SmoothACE, AggregationTopology ###########################

get_variable_binary(::SmoothACE, ::Type{<:PSY.AggregationTopology}, ::AbstractAGCFormulation) = false

########################## DeltaActivePowerUpVariable, Area ###########################

get_variable_binary(::DeltaActivePowerUpVariable, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::DeltaActivePowerUpVariable, ::PSY.Area, ::AbstractAGCFormulation) = 0.0

########################## DeltaActivePowerDownVariable, Area ###########################

get_variable_binary(::DeltaActivePowerDownVariable, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::DeltaActivePowerDownVariable, ::PSY.Area, ::AbstractAGCFormulation) = 0.0

########################## AdditionalDeltaPowerUpVariable, Area ###########################

# Commented out since not in use. These functions will substitute balancing_auxiliary_variables!
# """
# This function add the upwards scheduled regulation variables for power generation output to the model
# """
# function AddVariableSpec(
#     ::Type{AdditionalDeltaActivePowerUpVariable},
#     ::Type{U},
#     container::OptimizationContainer,
# ) where {U <: PSY.Area}
#     return AddVariableSpec(;
#          variable_key = VariableKey(AdditionalDeltaActivePowerUpVariable, U),
#         binary = false,
#         lb_value_func = x -> 0.0,
#         expression_name = :emergency_up,
#     )
# end
#
# """
# This function add the variables for power generation output to the model
# """
# function AddVariableSpec(
#     ::Type{AdditionalDeltaActivePowerDownVariable},
#     ::Type{U},
#     container::OptimizationContainer,
# ) where {U <: PSY.Area}
#     return AddVariableSpec(;
#          variable_key = VariableKey(AdditionalDeltaActivePowerDownVariable, U),
#         binary = false,
#         lb_value_func = x -> 0.0,
#         expression_name = :emergency_dn,
#     )
# end

########################## AreaMismatchVariable, Area ###########################
get_variable_binary(::AreaMismatchVariable, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = false

########################## LiftVariable, Area ###########################
get_variable_binary(::LiftVariable, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::LiftVariable, ::PSY.Area, ::AbstractAGCFormulation) = 0.0

#! format: off

"""
Steady State deviation of the frequency
"""
function add_variables!(container::OptimizationContainer, ::Type{T}) where {T <: SteadyStateFrequencyDeviation}
    time_steps = get_time_steps(container)
    variable = add_var_container!(container, T(), PSY.Area, time_steps)
    for t in time_steps
        variable[t] = JuMP.@variable(container.JuMPmodel,
        base_name ="ΔF_{$(t)}"
        )
    end
end

########################## Initial Condition ###########################

function _get_variable_initial_value(
    d::PSY.Component,
    key::ICKey,
    ::AbstractAGCFormulation,
    ::Nothing,
)
    return _get_ace_error(d, key)
end

########################## , ###########################


function balancing_auxiliary_variables!(container, sys)
    area_names = [PSY.get_name(a) for a in PSY.get_components(PSY.Area, sys)]
    time_steps = get_time_steps(container)
    R_up_emergency = add_var_container!(container, AdditionalDeltaActivePowerUpVariable(),  PSY.Area, area_names, time_steps)
    R_dn_emergency = add_var_container!(container, AdditionalDeltaActivePowerDownVariable(),  PSY.Area, area_names, time_steps)

    emergency_up =
        add_expression_container!(container, EmergencyUp(), PSY.Area, area_names, time_steps)
    emergency_dn =
        add_expression_container!(container, EmergencyDown(), PSY.Area, area_names, time_steps)
    for t in time_steps, a in area_names
        R_up_emergency[a, t] = JuMP.@variable(
            container.JuMPmodel,
            base_name ="Re_up_{$(a),$(t)}",
            lower_bound = 0.0
        )
        emergency_up[a, t] = R_up_emergency[a, t] + 0.0
        R_dn_emergency[a, t] = JuMP.@variable(
            container.JuMPmodel,
            base_name ="Re_dn_{$(a),$(t)}",
            lower_bound = 0.0
        )
        emergency_dn[a, t] = R_dn_emergency[a, t] + 0.0
    end

    return
end

function absolute_value_lift(container::OptimizationContainer, areas)
    time_steps = get_time_steps(container)
    area_names = [PSY.get_name(a) for a in areas]
    # TODO DT: correct component type and meta?
    container_lb = add_cons_container!(container, AbsoluteValueConstraint(), PSY.Area, area_names, time_steps, meta = "lb")
    container_ub = add_cons_container!(container, AbsoluteValueConstraint(), PSY.Area, area_names, time_steps, meta = "ub")
    mismatch = get_variable(container, AreaMismatchVariable(), PSY.Area)
    z = get_variable(container, LiftVariable(), PSY.Area)
    jump_model = get_jump_model(container)

    for t in time_steps, a in area_names
        container_lb[a, t] = JuMP.@constraint(jump_model, mismatch[a, t] <= z[a, t])
        container_ub[a, t] = JuMP.@constraint(jump_model, -1 * mismatch[a, t] <= z[a, t])
    end

    JuMP.add_to_expression!(
        container.cost_function,
        sum(z[a, t] for t in time_steps, a in area_names) * SERVICES_SLACK_COST,
    )
    return
end

"""
Expression for the power deviation given deviation in the frequency. This expression allows updating the response of the frequency depending on commitment decisions
"""
function frequency_response_constraint!(container::OptimizationContainer, sys::PSY.System)
    time_steps = get_time_steps(container)
    services = PSY.get_components(PSY.AGC, sys)
    area_names = [PSY.get_name(PSY.get_area(s)) for s in services]
    frequency_response = 0.0
    for area in PSY.get_components(PSY.Area, sys)
        frequency_response += PSY.get_load_response(area)
    end
    for g in PSY.get_components(PSY.RegulationDevice, sys, x -> PSY.get_available(x))
        d = PSY.get_droop(g)
        response = 1 / d
        frequency_response += response
    end

    @assert frequency_response >= 0.0
    # This value is the one updated later in simulation based on the UC result
    inv_frequency_reponse = 1 / frequency_response
    area_balance = get_variable(container, ActivePowerVariable(), PSY.Area)
    frequency = get_variable(container, SteadyStateFrequencyDeviation(), PSY.Area)
    R_up = get_variable(container, DeltaActivePowerUpVariable(), PSY.Area)
    R_dn = get_variable(container, DeltaActivePowerDownVariable(), PSY.Area)
    R_up_emergency =
        get_variable(container, AdditionalDeltaActivePowerUpVariable(), PSY.Area)
    R_dn_emergency =
        get_variable(container, AdditionalDeltaActivePowerUpVariable(), PSY.Area)

    const_container = add_cons_container!(container, FrequencyResponseConstraint(), PSY.System, time_steps)

    for s in services, t in time_steps
        system_balance = sum(area_balance.data[:, t])
        total_reg = JuMP.AffExpr(0.0)
        for a in area_names
            JuMP.add_to_expression!(total_reg, R_up[a, t])
            JuMP.add_to_expression!(total_reg, -1 * R_dn[a, t])
            JuMP.add_to_expression!(total_reg, R_up_emergency[a, t])
            JuMP.add_to_expression!(total_reg, -1 * R_dn_emergency[a, t])
        end
        const_container[t] = JuMP.@constraint(
            container.JuMPmodel,
            frequency[t] == -inv_frequency_reponse * (system_balance + total_reg)
        )
    end
    return
end

function smooth_ace_pid!(container::OptimizationContainer, services::Vector{PSY.AGC})
    time_steps = get_time_steps(container)
    area_names = [PSY.get_name(PSY.get_area(s)) for s in services]
    RAW_ACE = add_expression_container!(container, RawACE(), PSY.Area, area_names, time_steps)
    SACE = get_variable(container, SmoothACE(), PSY.Area)
    SACE_pid = add_cons_container!(container, SACEPidAreaConstraint(), PSY.Area, area_names, time_steps)

    Δf = get_variable(container, SteadyStateFrequencyDeviation(), PSY.Area)

    for (ix, service) in enumerate(services)
        kp = PSY.get_K_p(service)
        ki = PSY.get_K_i(service)
        kd = PSY.get_K_d(service)
        B = PSY.get_bias(service)
        Δt = convert(Dates.Second, container.resolution).value
        a = PSY.get_name(PSY.get_area(service))
        for t in time_steps
            # Todo: Add initial Frequency Deviation
            RAW_ACE[a, t] = -10 * B * Δf[t] + 0.0
            SACE[a, t] =
                JuMP.@variable(container.JuMPmodel,
                base_name ="SACE_{$(a),$(t)}"
                )
            if t == 1
                SACE_ini =
                    get_initial_conditions(container, AreaControlError(), PSY.AGC)[ix]
                sace_exp = SACE_ini.value + kp * ((1 + Δt / (kp / ki)) * (RAW_ACE[a, t]))
                SACE_pid[a, t] =
                    JuMP.@constraint(container.JuMPmodel, SACE[a, t] == sace_exp)
                continue
            end
            SACE_pid[a, t] = JuMP.@constraint(
                container.JuMPmodel,
                SACE[a, t] ==
                SACE[a, t - 1] +
                kp * (
                    (1 + Δt / (kp / ki) + (kd / kp) / Δt) * (RAW_ACE[a, t]) +
                    (-1 - 2 * (kd / kp) / Δt) * (RAW_ACE[a, t - 1])
                )
            )
        end
    end
    return
end

function aux_constraints!(container::OptimizationContainer, sys::PSY.System)
    time_steps = get_time_steps(container)
    area_names = [PSY.get_name(a) for a in PSY.get_components(PSY.Area, sys)]
    aux_equation = add_cons_container!(container, BalanceAuxConstraint(), PSY.System, area_names, time_steps)
    area_mismatch = get_variable(container,  AreaMismatchVariable(), PSY.Area)
    SACE = get_variable(container, SmoothACE(), PSY.Area)
    R_up = get_variable(container, DeltaActivePowerUpVariable(), PSY.Area)
    R_dn = get_variable(container, DeltaActivePowerDownVariable(), PSY.Area)
    R_up_emergency =
        get_variable(container, AdditionalDeltaActivePowerUpVariable(), PSY.Area)
    R_dn_emergency =
        get_variable(container, AdditionalDeltaActivePowerUpVariable(), PSY.Area)

    for t in time_steps, a in area_names
        aux_equation[a, t] = JuMP.@constraint(
            container.JuMPmodel,
            -1 * SACE[a, t] ==
            (R_up[a, t] - R_dn[a, t]) +
            (R_up_emergency[a, t] - R_dn_emergency[a, t]) +
            area_mismatch[a, t]
        )
    end
    return
end
