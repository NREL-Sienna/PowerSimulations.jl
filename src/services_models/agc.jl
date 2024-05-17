#! format: off
get_variable_multiplier(_, ::Type{<:PSY.AGC}, ::AbstractAGCFormulation) = NaN
########################## ActivePowerVariable, AGC ###########################

########################## SteadyStateFrequencyDeviation ##################################
get_variable_binary(::SteadyStateFrequencyDeviation, ::Type{<:PSY.AGC}, ::AbstractAGCFormulation) = false

get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = false
########################## SmoothACE, AggregationTopology ###########################

get_variable_binary(::SmoothACE, ::Type{<:PSY.AggregationTopology}, ::AbstractAGCFormulation) = false
get_variable_binary(::SmoothACE, ::Type{<:PSY.AGC}, ::AbstractAGCFormulation) = false

########################## DeltaActivePowerUpVariable, AGC ###########################

get_variable_binary(::DeltaActivePowerUpVariable, ::Type{<:PSY.AGC}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::DeltaActivePowerUpVariable, ::PSY.AGC, ::AbstractAGCFormulation) = 0.0

########################## DeltaActivePowerDownVariable, AGC ###########################

get_variable_binary(::DeltaActivePowerDownVariable, ::Type{<:PSY.AGC}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::DeltaActivePowerDownVariable, ::PSY.AGC, ::AbstractAGCFormulation) = 0.0

########################## AdditionalDeltaPowerUpVariable, Area ###########################

get_variable_binary(::AdditionalDeltaActivePowerUpVariable, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::AdditionalDeltaActivePowerUpVariable, ::PSY.Area, ::AbstractAGCFormulation) = 0.0

########################## AdditionalDeltaPowerDownVariable, Area ###########################

get_variable_binary(::AdditionalDeltaActivePowerDownVariable, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::AdditionalDeltaActivePowerDownVariable, ::PSY.Area, ::AbstractAGCFormulation) = 0.0

########################## AreaMismatchVariable, AGC ###########################
get_variable_binary(::AreaMismatchVariable, ::Type{<:PSY.AGC}, ::AbstractAGCFormulation) = false

########################## LiftVariable, Area ###########################
get_variable_binary(::LiftVariable, ::Type{<:PSY.AGC}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::LiftVariable, ::PSY.AGC, ::AbstractAGCFormulation) = 0.0

initial_condition_default(::AreaControlError, d::PSY.AGC, ::AbstractAGCFormulation) = PSY.get_initial_ace(d)
initial_condition_variable(::AreaControlError, d::PSY.AGC, ::AbstractAGCFormulation) = AreaMismatchVariable()

get_variable_multiplier(::SteadyStateFrequencyDeviation, d::PSY.AGC, ::AbstractAGCFormulation) = -10 * PSY.get_bias(d)

#! format: on

function get_default_time_series_names(
    ::Type{PSY.AGC},
    ::Type{<:AbstractAGCFormulation},
)
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

function get_default_attributes(
    ::Type{PSY.AGC},
    ::Type{<:AbstractAGCFormulation},
)
    return Dict{String, Any}("aggregated_service_model" => false)
end

"""
Steady State deviation of the frequency
"""
function add_variables!(
    container::OptimizationContainer,
    ::Type{T},
) where {T <: SteadyStateFrequencyDeviation}
    time_steps = get_time_steps(container)
    variable = add_variable_container!(container, T(), PSY.AGC, time_steps)
    for t in time_steps
        variable[t] = JuMP.@variable(container.JuMPmodel, base_name = "ΔF_{$(t)}")
    end
end

########################## Initial Condition ###########################

function _get_variable_initial_value(
    d::PSY.Component,
    key::InitialConditionKey,
    ::AbstractAGCFormulation,
    ::Nothing,
)
    return _get_ace_error(d, key)
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{LiftVariable},
    agcs::IS.FlattenIteratorWrapper{U},
    ::ServiceModel{PSY.AGC, V},
) where {T <: AbsoluteValueConstraint, U <: PSY.AGC, V <: PIDSmoothACE}
    time_steps = get_time_steps(container)
    agc_names = PSY.get_name.(agcs)
    container_lb =
        add_constraints_container!(container, T(), U, agc_names, time_steps; meta = "lb")
    container_ub =
        add_constraints_container!(container, T(), U, agc_names, time_steps; meta = "ub")
    mismatch = get_variable(container, AreaMismatchVariable(), U)
    z = get_variable(container, LiftVariable(), U)
    jump_model = get_jump_model(container)

    for t in time_steps, a in agc_names
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
    agcs::IS.FlattenIteratorWrapper{U},
    ::ServiceModel{PSY.AGC, V},
    sys::PSY.System,
) where {T <: FrequencyResponseConstraint, U <: PSY.AGC, V <: PIDSmoothACE}
    time_steps = get_time_steps(container)
    agc_names = PSY.get_name.(agcs)

    frequency_response = 0.0
    for agc in agcs
        area = PSY.get_area(agc)
        frequency_response += PSY.get_load_response(area)
    end

    for g in PSY.get_components(PSY.get_available, PSY.RegulationDevice, sys)
        d = PSY.get_droop(g)
        response = 1 / d
        frequency_response += response
    end

    IS.@assert_op frequency_response >= 0.0

    # This value is the one updated later in simulation based on the UC result
    inv_frequency_response = 1 / frequency_response

    area_balance = get_variable(container, ActivePowerVariable(), PSY.Area)
    frequency = get_variable(container, SteadyStateFrequencyDeviation(), U)
    R_up = get_variable(container, DeltaActivePowerUpVariable(), U)
    R_dn = get_variable(container, DeltaActivePowerDownVariable(), U)
    R_up_emergency =
        get_variable(container, AdditionalDeltaActivePowerUpVariable(), PSY.Area)
    R_dn_emergency =
        get_variable(container, AdditionalDeltaActivePowerUpVariable(), PSY.Area)

    const_container = add_constraints_container!(container, T(), PSY.System, time_steps)

    for t in time_steps
        system_balance = sum(area_balance.data[:, t])
        for agc in agcs
            a = PSY.get_name(agc)
            area_name = PSY.get_name(PSY.get_area(agc))
            JuMP.add_to_expression!(system_balance, R_up[a, t])
            JuMP.add_to_expression!(system_balance, -1 * R_dn[a, t])
            JuMP.add_to_expression!(system_balance, R_up_emergency[area_name, t])
            JuMP.add_to_expression!(system_balance, -1 * R_dn_emergency[area_name, t])
        end
        const_container[t] = JuMP.@constraint(
            container.JuMPmodel,
            frequency[t] == -inv_frequency_response * system_balance
        )
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{SteadyStateFrequencyDeviation},
    agcs::IS.FlattenIteratorWrapper{U},
    model::ServiceModel{PSY.AGC, V},
    sys::PSY.System,
) where {T <: SACEPIDAreaConstraint, U <: PSY.AGC, V <: PIDSmoothACE}
    services = get_available_components(model, sys)
    time_steps = get_time_steps(container)
    agc_names = PSY.get_name.(services)
    area_names = [PSY.get_name(PSY.get_area(s)) for s in services]
    RAW_ACE = get_expression(container, RawACE(), U)
    SACE = get_variable(container, SmoothACE(), U)
    SACE_pid = add_constraints_container!(
        container,
        SACEPIDAreaConstraint(),
        U,
        agc_names,
        time_steps,
    )

    jump_model = get_jump_model(container)
    for (ix, service) in enumerate(services)
        kp = PSY.get_K_p(service)
        ki = PSY.get_K_i(service)
        kd = PSY.get_K_d(service)
        Δt = convert(Dates.Second, get_resolution(container)).value
        a = PSY.get_name(service)
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
    agcs::IS.FlattenIteratorWrapper{U},
    ::ServiceModel{PSY.AGC, V},
    sys::PSY.System,
) where {T <: BalanceAuxConstraint, U <: PSY.AGC, V <: PIDSmoothACE}
    time_steps = get_time_steps(container)
    agc_names = PSY.get_name.(agcs)
    aux_equation = add_constraints_container!(
        container,
        BalanceAuxConstraint(),
        PSY.System,
        agc_names,
        time_steps,
    )
    area_mismatch = get_variable(container, AreaMismatchVariable(), PSY.AGC)
    SACE = get_variable(container, SmoothACE(), PSY.AGC)
    R_up = get_variable(container, DeltaActivePowerUpVariable(), PSY.AGC)
    R_dn = get_variable(container, DeltaActivePowerDownVariable(), PSY.AGC)
    R_up_emergency =
        get_variable(container, AdditionalDeltaActivePowerUpVariable(), PSY.Area)
    R_dn_emergency =
        get_variable(container, AdditionalDeltaActivePowerUpVariable(), PSY.Area)

    for t in time_steps
        for agc in agcs
            a = PSY.get_name(agc)
            area_name = PSY.get_name(PSY.get_area(agc))
            aux_equation[a, t] = JuMP.@constraint(
                container.JuMPmodel,
                -1 * SACE[a, t] ==
                (R_up[a, t] - R_dn[a, t]) +
                (R_up_emergency[area_name, t] - R_dn_emergency[area_name, t]) +
                area_mismatch[a, t]
            )
        end
    end
    return
end

function objective_function!(
    container::OptimizationContainer,
    agcs::IS.FlattenIteratorWrapper{T},
    ::ServiceModel{<:PSY.AGC, U},
) where {T <: PSY.AGC, U <: PIDSmoothACE}
    add_proportional_cost!(container, LiftVariable(), agcs, U())
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

function add_proportional_cost!(
    container::OptimizationContainer,
    ::U,
    agcs::IS.FlattenIteratorWrapper{T},
    ::PIDSmoothACE,
) where {T <: PSY.AGC, U <: LiftVariable}
    lift_variable = get_variable(container, U(), T)
    for index in Iterators.product(axes(lift_variable)...)
        add_to_objective_invariant_expression!(
            container,
            SERVICES_SLACK_COST * lift_variable[index...],
        )
    end
    return
end
