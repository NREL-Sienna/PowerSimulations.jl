#! format: off
get_variable_multiplier(_, ::Type{<:PSY.AGC}, ::AbstractAGCFormulation) = NaN
########################## ActivePowerVariable, AGC ###########################

########################## ActivePowerImbalance ##################################
get_variable_binary(::ActivePowerImbalance, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = false

########################## SteadyStateFrequencyDeviation ##################################
get_variable_binary(::SteadyStateFrequencyDeviation, ::Type{<:PSY.AGC}, ::AbstractAGCFormulation) = false

get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.Area}, ::AbstractAGCFormulation) = false
########################## SmoothACE, AggregationTopology ###########################

get_variable_binary(::SmoothACE, ::Type{<:PSY.AggregationTopology}, ::AbstractAGCFormulation) = false
get_variable_binary(::SmoothACE, ::Type{<:PSY.AGC}, ::AbstractAGCFormulation) = false

########################## DeltaActivePowerUpVariable, AGC ###########################
get_variable_binary(::DeltaActivePowerUpVariable, ::Type{<:PSY.ThermalGen}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::DeltaActivePowerUpVariable, ::PSY.ThermalGen, ::AbstractAGCFormulation) = 0.0
get_variable_multiplier(::DeltaActivePowerUpVariable, ::Type{<:PSY.ThermalGen}, ::AbstractAGCFormulation) = 1.0

########################## DeltaActivePowerDownVariable, AGC ###########################
get_variable_binary(::DeltaActivePowerDownVariable, ::Type{<:PSY.ThermalGen}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::DeltaActivePowerDownVariable, ::PSY.ThermalGen, ::AbstractAGCFormulation) = 0.0
get_variable_multiplier(::DeltaActivePowerDownVariable, ::Type{<:PSY.ThermalGen}, ::AbstractAGCFormulation) = -1.0

########################## AdditionalDeltaPowerUpVariable, Area ###########################
get_variable_binary(::AdditionalDeltaActivePowerUpVariable, ::Type{<:PSY.ThermalGen}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::AdditionalDeltaActivePowerUpVariable, ::PSY.ThermalGen, ::AbstractAGCFormulation) = 0.0
get_variable_multiplier(::AdditionalDeltaActivePowerUpVariable, ::Type{<:PSY.ThermalGen}, ::AbstractAGCFormulation) = 1.0

########################## AdditionalDeltaPowerDownVariable, Area ###########################
get_variable_binary(::AdditionalDeltaActivePowerDownVariable, ::Type{<:PSY.ThermalGen}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::AdditionalDeltaActivePowerDownVariable, ::PSY.ThermalGen, ::AbstractAGCFormulation) = 0.0
get_variable_multiplier(::AdditionalDeltaActivePowerDownVariable, ::Type{<:PSY.ThermalGen}, ::AbstractAGCFormulation) = -1.0

########################## AreaMismatchVariable, AGC ###########################
get_variable_binary(::AreaMismatchVariable, ::Type{<:PSY.AGC}, ::AbstractAGCFormulation) = false

########################## LiftVariable, Area ###########################
get_variable_binary(::LiftVariable, ::Type{<:PSY.AGC}, ::AbstractAGCFormulation) = false
get_variable_lower_bound(::LiftVariable, ::PSY.AGC, ::AbstractAGCFormulation) = 0.0

initial_condition_default(::AreaControlError, d::PSY.AGC, ::AbstractAGCFormulation) = PSY.get_initial_ace(d)
initial_condition_variable(::AreaControlError, d::PSY.AGC, ::AbstractAGCFormulation) = SmoothACE()

get_variable_multiplier(::SteadyStateFrequencyDeviation, d::PSY.AGC, ::AbstractAGCFormulation) = 10 * PSY.get_bias(d)

########################Objective Function##################################################
# TODO - set cost proportional to inverse of participation factor; this could impact the solutions and test results
proportional_cost(::PSY.OperationalCost, ::AdditionalDeltaActivePowerUpVariable, d::PSY.ThermalStandard, ::PIDSmoothACE) = SERVICES_SLACK_COST
proportional_cost(::PSY.OperationalCost, ::AdditionalDeltaActivePowerDownVariable, d::PSY.ThermalStandard, ::PIDSmoothACE) = SERVICES_SLACK_COST

objective_function_multiplier(::VariableType, ::PIDSmoothACE)=OBJECTIVE_FUNCTION_POSITIVE


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

"""
System wide active power imbalance
"""
function add_variables!(
    container::OptimizationContainer,
    ::Type{T},
) where {T <: ActivePowerImbalance}
    time_steps = get_time_steps(container)
    variable = add_variable_container!(container, T(), PSY.AGC, time_steps)
    for t in time_steps
        variable[t] = JuMP.@variable(container.JuMPmodel, base_name = "ΔP_{$(t)}")
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

function add_variables!(
    container::OptimizationContainer,
    ::Type{ScheduledFlowActivePowerVariable},
    devices::IS.FlattenIteratorWrapper{PSY.AreaInterchange},
) 
    time_steps = get_time_steps(container)
    variable = add_variable_container!(
        container,
        ScheduledFlowActivePowerVariable(),
        PSY.AreaInterchange,
        PSY.get_name.(devices),
        time_steps,
    )

    for device in devices, t in time_steps
        device_name = get_name(device)
        variable[device_name, t] = JuMP.@variable(
            get_jump_model(container),
            base_name = "ScheduledFlowActivePowerVariable_AreaInterchange_{$(device_name), $(t)}",
        )
    end
    return
end


function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    agcs::IS.FlattenIteratorWrapper{U},
    model,
    sys,
) where {U <: PSY.AGC, T <: CopperPlateImbalanceConstraint}
    time_steps = get_time_steps(container)
    expression = get_expression(container, ActivePowerBalance(), PSY.Area)
    system_imbalance = get_variable(container, ActivePowerImbalance(), U)
    const_container = add_constraints_container!(container, T(), PSY.System, time_steps)
    for t in time_steps
        const_container[t] = JuMP.@constraint(
            container.JuMPmodel,
            system_imbalance[t] == sum(expression[:,t])
        )
    end
    return

end

"""
Expression for the power deviation given deviation in the frequency. This expression allows
updating the response of the frequency depending on commitment decisions
"""
# Equation (4,5)
function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{SteadyStateFrequencyDeviation},
    agcs::IS.FlattenIteratorWrapper{U},
    service_model::ServiceModel{PSY.AGC, V},
    sys::PSY.System,
) where {T <: FrequencyResponseConstraint, U <: PSY.AGC, V <: PIDSmoothACE}
    time_steps = get_time_steps(container)
    agc_names = PSY.get_name.(agcs)
    contributing_devices = get_contributing_devices(service_model)
    frequency_response = 0.0
    for agc in agcs
        area = PSY.get_area(agc)
        frequency_response += PSY.get_load_response(area)
    end
    # TODO - this should be all devices that have a droop response. 
    # For now, only considers response from contributing_devices
    for g in contributing_devices
        d = PSY.get_frequency_droop(g)
        response = 1 / d
        frequency_response += response
    end
    IS.@assert_op frequency_response >= 0.0
    # This value is the one updated later in simulation based on the UC result
    inv_frequency_response = 1 / frequency_response

    system_imbalance = get_variable(container, ActivePowerImbalance(), U)
    frequency = get_variable(container, SteadyStateFrequencyDeviation(), U)
    const_container = add_constraints_container!(container, T(), PSY.System, time_steps)
    for t in time_steps
        const_container[t] = JuMP.@constraint(
            container.JuMPmodel,
            frequency[t] == inv_frequency_response * system_imbalance[t] 
        )
    end
    return
end

# Equation (6,7)
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

# Equation (13)
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
    R_up = get_expression(container, DeltaActivePowerUpExpression(), PSY.Area)
    R_dn = get_expression(container, DeltaActivePowerDownExpression(), PSY.Area)
    R_up_emergency =
        get_expression(container, AdditionalDeltaActivePowerUpExpression(), PSY.Area)
    R_dn_emergency =
        get_expression(container, AdditionalDeltaActivePowerUpExpression(), PSY.Area)

    for t in time_steps
        for agc in agcs
            a = PSY.get_name(agc)
            area_name = PSY.get_name(PSY.get_area(agc))
            aux_equation[a, t] = JuMP.@constraint(
                container.JuMPmodel,
                -1 * SACE[a, t] ==
                (R_up[area_name, t] - R_dn[area_name, t]) +
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

function objective_function!(
    container::OptimizationContainer,
    devs::Union{Vector{T}, IS.FlattenIteratorWrapper{T}},
    ::ServiceModel{<:PSY.AGC, U},
) where {
    T <: PSY.ThermalStandard,
    U <: PIDSmoothACE,
}
    add_proportional_cost!(container, AdditionalDeltaActivePowerUpVariable(), devs, U())
    add_proportional_cost!(container, AdditionalDeltaActivePowerDownVariable(), devs, U())
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

function add_constraints!(
    container::OptimizationContainer,
    ::Type{S},
    ::Type{DeltaActivePowerUpVariable},
    devices::Union{Vector{T}, IS.FlattenIteratorWrapper{T}},
    ::ServiceModel{PSY.AGC, PIDSmoothACE},
    ::NetworkModel{AreaPTDFPowerModel},
) where {
    S <: RegulationLimitsConstraint,
    T <: PSY.ThermalStandard,
}
    var_up = get_variable(container, DeltaActivePowerUpVariable(), T)
    var_dn = get_variable(container, DeltaActivePowerDownVariable(), T)
    var_up_emergency = get_variable(container, AdditionalDeltaActivePowerUpVariable(), T)
    var_dn_emergency  = get_variable(container, AdditionalDeltaActivePowerDownVariable(), T)
    base_points_param = get_parameter(container, ActivePowerTimeSeriesParameter(), T)
    multiplier = get_multiplier_array(base_points_param)
    names = [PSY.get_name(g) for g in devices]
    time_steps = get_time_steps(container)

    container_up =
        add_constraints_container!(container, S(), T, names, time_steps; meta = "up")
    container_dn =
        add_constraints_container!(container, S(), T, names, time_steps; meta = "dn")

    for d in devices
        name = PSY.get_name(d)
        limits = PSY.get_active_power_limits(d)
        param = get_parameter_column_refs(base_points_param, name)
        for t in time_steps
            container_up[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                (var_up[name, t] + var_up_emergency[name,t]) <= limits.max - param[t] * multiplier[name, t]
            )
            container_dn[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                (var_dn[name, t] + var_dn_emergency[name,t]) <= param[t] * multiplier[name, t] - limits.min
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{S},
    devices::Union{Vector{T}, IS.FlattenIteratorWrapper{T}},
    ::ServiceModel{PSY.AGC, PIDSmoothACE},
    ::NetworkModel{AreaPTDFPowerModel},
) where {
    S <: RampLimitConstraint,
    T <: PSY.ThermalStandard,
}
    R_up = get_variable(container, DeltaActivePowerUpVariable(), T)
    R_dn = get_variable(container, DeltaActivePowerDownVariable(), T)
    resolution = Dates.value(Dates.Second(get_resolution(container)))
    names = [PSY.get_name(g) for g in devices]
    time_steps = get_time_steps(container)

    container_up =
        add_constraints_container!(container, S(), T, names, time_steps; meta = "up")
    container_dn =
        add_constraints_container!(container, S(), T, names, time_steps; meta = "dn")

    for d in devices
        ramp_limits = PSY.get_ramp_limits(d)
        ramp_limits === nothing && continue
        scaling_factor = resolution #* SECONDS_IN_MINUTE
        name = PSY.get_name(d)
        for t in time_steps
            container_up[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                R_up[name, t] <= ramp_limits.up * scaling_factor
            )
            container_dn[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                R_dn[name, t] <= ramp_limits.down * scaling_factor
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{S},
    devices::Union{Vector{T}, IS.FlattenIteratorWrapper{T}},
    service_model::ServiceModel{PSY.AGC, PIDSmoothACE},
    ::NetworkModel{AreaPTDFPowerModel},
    area_device_map,
) where {
    S <: ParticipationAssignmentConstraint,
    T <: PSY.ThermalStandard,
}
    time_steps = get_time_steps(container)
    R_up = get_variable(container, DeltaActivePowerUpVariable(), T)
    R_dn = get_variable(container, DeltaActivePowerDownVariable(), T)
    area_reserve_up = get_expression(container, DeltaActivePowerUpExpression(), PSY.Area)
    area_reserve_dn = get_expression(container, DeltaActivePowerDownExpression(), PSY.Area)

    component_names = PSY.get_name.(devices)
    participation_assignment_up = add_constraints_container!(
        container,
        S(),
        T,
        component_names,
        time_steps;
        meta = "up",
    )
    participation_assignment_dn = add_constraints_container!(
        container,
        S(),
        T,
        component_names,
        time_steps;
        meta = "dn",
    )
    for (area_name, contributing_devices) in area_device_map
        for device in contributing_devices
            device_name = PSY.get_name(device)
            p_factor_up = 0.2      # TODO - JDL make a left hand side parameter (or based on base power)
            p_factor_down = 0.2    # TODO - JDL make a left hand side parameter 
            for t in time_steps
                participation_assignment_up[device_name, t] = JuMP.@constraint(
                    container.JuMPmodel,
                    R_up[device_name, t] ==
                    (p_factor_up * area_reserve_up[area_name, t]) 
                )
                participation_assignment_dn[device_name, t] = JuMP.@constraint(
                    container.JuMPmodel,
                    R_dn[device_name, t] ==
                    (p_factor_down * area_reserve_dn[area_name, t]) 
                )
            end
        end
    end
    return
end
