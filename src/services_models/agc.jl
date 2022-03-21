#! format: off
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

get_variable_binary(::AdditionalDeltaActivePowerUpVariable, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::AdditionalDeltaActivePowerUpVariable, ::PSY.Area, ::AbstractAGCFormulation) = 0.0

########################## AdditionalDeltaPowerDownVariable, Area ###########################

get_variable_binary(::AdditionalDeltaActivePowerDownVariable, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::AdditionalDeltaActivePowerDownVariable, ::PSY.Area, ::AbstractAGCFormulation) = 0.0

########################## AreaMismatchVariable, Area ###########################
get_variable_binary(::AreaMismatchVariable, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = false

########################## LiftVariable, Area ###########################
get_variable_binary(::LiftVariable, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::LiftVariable, ::PSY.Area, ::AbstractAGCFormulation) = 0.0

initial_condition_default(::AreaControlError, d::PSY.AGC, ::AbstractAGCFormulation) = PSY.get_initial_ace(d)
initial_condition_variable(::AreaControlError, d::PSY.AGC, ::AbstractAGCFormulation) = AreaMismatchVariable()

get_variable_multiplier(::SteadyStateFrequencyDeviation, d::PSY.AGC, ::AbstractAGCFormulation) = -10 * PSY.get_bias(d)

#! format: on

"""
Steady State deviation of the frequency
"""
function add_variables!(
    container::OptimizationContainer,
    ::Type{T},
) where {T <: SteadyStateFrequencyDeviation}
    time_steps = get_time_steps(container)
    variable = add_variable_container!(container, T(), PSY.Area, time_steps)
    for t in time_steps
        variable[t] = JuMP.@variable(container.JuMPmodel, base_name = "ΔF_{$(t)}")
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

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{LiftVariable},
    areas::IS.FlattenIteratorWrapper{U},
    ::ServiceModel{PSY.AGC, V},
) where {T <: AbsoluteValueConstraint, U <: PSY.Area, V <: PIDSmoothACE}
    time_steps = get_time_steps(container)
    area_names = PSY.get_name.(areas)
    container_lb =
        add_constraints_container!(container, T(), U, area_names, time_steps, meta="lb")
    container_ub =
        add_constraints_container!(container, T(), U, area_names, time_steps, meta="ub")
    mismatch = get_variable(container, AreaMismatchVariable(), U)
    z = get_variable(container, LiftVariable(), U)
    jump_model = get_jump_model(container)

    for t in time_steps, a in area_names
        container_lb[a, t] = JuMP.@constraint(jump_model, mismatch[a, t] <= z[a, t])
        container_ub[a, t] = JuMP.@constraint(jump_model, -1 * mismatch[a, t] <= z[a, t])
    end
    return
end

"""
Expression for the power deviation given deviation in the frequency. This expression allows
updating the response of the frequency depending on commitment decisions
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{SteadyStateFrequencyDeviation},
    areas::IS.FlattenIteratorWrapper{U},
    ::ServiceModel{PSY.AGC, V},
    sys::PSY.System,
) where {T <: FrequencyResponseConstraint, U <: PSY.Area, V <: PIDSmoothACE}
    time_steps = get_time_steps(container)
    area_names = PSY.get_name.(areas)

    frequency_response = 0.0
    for area in PSY.get_components(PSY.Area, sys)
        frequency_response += PSY.get_load_response(area)
    end

    for g in PSY.get_components(PSY.RegulationDevice, sys, x -> PSY.get_available(x))
        d = PSY.get_droop(g)
        response = 1 / d
        frequency_response += response
    end

    IS.@assert_op frequency_response >= 0.0

    # This value is the one updated later in simulation based on the UC result
    inv_frequency_reponse = 1 / frequency_response

    area_balance = get_variable(container, ActivePowerVariable(), U)
    frequency = get_variable(container, SteadyStateFrequencyDeviation(), U)
    R_up = get_variable(container, DeltaActivePowerUpVariable(), U)
    R_dn = get_variable(container, DeltaActivePowerDownVariable(), U)
    R_up_emergency = get_variable(container, AdditionalDeltaActivePowerUpVariable(), U)
    R_dn_emergency = get_variable(container, AdditionalDeltaActivePowerUpVariable(), U)

    const_container = add_constraints_container!(container, T(), PSY.System, time_steps)

    for t in time_steps
        system_balance = sum(area_balance.data[:, t])
        for a in area_names
            JuMP.add_to_expression!(system_balance, R_up[a, t])
            JuMP.add_to_expression!(system_balance, -1 * R_dn[a, t])
            JuMP.add_to_expression!(system_balance, R_up_emergency[a, t])
            JuMP.add_to_expression!(system_balance, -1 * R_dn_emergency[a, t])
        end
        const_container[t] = JuMP.@constraint(
            container.JuMPmodel,
            frequency[t] == -inv_frequency_reponse * system_balance
        )
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{SteadyStateFrequencyDeviation},
    areas::IS.FlattenIteratorWrapper{U},
    ::ServiceModel{PSY.AGC, V},
    sys::PSY.System,
) where {T <: SACEPIDAreaConstraint, U <: PSY.Area, V <: PIDSmoothACE}
    services = PSY.get_components(PSY.AGC, sys)
    time_steps = get_time_steps(container)
    area_names = [PSY.get_name(PSY.get_area(s)) for s in services]
    RAW_ACE = get_expression(container, RawACE(), U)
    SACE = get_variable(container, SmoothACE(), U)
    SACE_pid = add_constraints_container!(
        container,
        SACEPIDAreaConstraint(),
        U,
        area_names,
        time_steps,
    )

    jump_model = get_jump_model(container)
    for (ix, service) in enumerate(services)
        kp = PSY.get_K_p(service)
        ki = PSY.get_K_i(service)
        kd = PSY.get_K_d(service)
        Δt = convert(Dates.Second, container.resolution).value
        a = PSY.get_name(PSY.get_area(service))
        for t in time_steps
            if t == 1
                ACE_ini = get_initial_condition(container, AreaControlError(), PSY.AGC)[ix]
                ace_exp = get_value(ACE_ini) + kp * ((1 + Δt / (kp / ki)) * (RAW_ACE[a, t]))
                SACE_pid[a, t] = JuMP.@constraint(jump_model, SACE[a, t] == ace_exp)
                continue
            end
            SACE_pid[a, t] = JuMP.@constraint(
                jump_model,
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

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{SmoothACE},
    areas::IS.FlattenIteratorWrapper{U},
    ::ServiceModel{PSY.AGC, V},
    sys::PSY.System,
) where {T <: BalanceAuxConstraint, U <: PSY.Area, V <: PIDSmoothACE}
    time_steps = get_time_steps(container)
    area_names = PSY.get_name.(areas)
    aux_equation = add_constraints_container!(
        container,
        BalanceAuxConstraint(),
        PSY.System,
        area_names,
        time_steps,
    )
    area_mismatch = get_variable(container, AreaMismatchVariable(), PSY.Area)
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

function objective_function!(
    container::OptimizationContainer,
    areas::IS.FlattenIteratorWrapper{T},
    ::ServiceModel{<:PSY.AGC, U},
) where {T <: PSY.Area, U <: PIDSmoothACE}
    add_proportional_cost!(container, LiftVariable(), areas, U())
    return
end

# Defined here so we can dispatch on PIDSmoothACE
function add_feedforward_arguments!(
    container::OptimizationContainer,
    model::ServiceModel{PSY.AGC, PIDSmoothACE},
    areas::IS.FlattenIteratorWrapper{PSY.AGC},
)
    for ff in get_feedforwards(model)
        @debug "arguments" ff V _group = LOG_GROUP_FEEDFORWARDS_CONSTRUCTION
        add_feedforward_arguments!(container, model, areas, ff)
    end
    return
end

function add_feedforward_constraints!(
    container::OptimizationContainer,
    model::ServiceModel{PSY.AGC, PIDSmoothACE},
    areas::IS.FlattenIteratorWrapper{PSY.AGC},
)
    for ff in get_feedforwards(model)
        @debug "arguments" ff V _group = LOG_GROUP_FEEDFORWARDS_CONSTRUCTION
        add_feedforward_constraints!(container, model, areas, ff)
    end
    return
end
