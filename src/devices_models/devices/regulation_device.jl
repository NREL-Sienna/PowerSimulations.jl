#! format: off

abstract type AbstractRegulationFormulation <: AbstractDeviceFormulation end
struct ReserveLimitedRegulation <: AbstractRegulationFormulation end
struct DeviceLimitedRegulation <: AbstractRegulationFormulation end

get_variable_multiplier(_, ::Type{PSY.RegulationDevice{PSY.ThermalStandard}}, ::DeviceLimitedRegulation) = NaN
############################ DeltaActivePowerUpVariable, RegulationDevice ###########################

get_variable_binary(::DeltaActivePowerUpVariable, ::Type{<:PSY.RegulationDevice}, ::AbstractRegulationFormulation) = false
get_variable_lower_bound(::DeltaActivePowerUpVariable, ::PSY.RegulationDevice, ::AbstractRegulationFormulation) = 0.0

############################ DeltaActivePowerDownVariable, RegulationDevice ###########################

get_variable_binary(::DeltaActivePowerDownVariable, ::Type{<:PSY.RegulationDevice}, ::AbstractRegulationFormulation) = false
get_variable_lower_bound(::DeltaActivePowerDownVariable, ::PSY.RegulationDevice, ::AbstractRegulationFormulation) = 0.0

############################ AdditionalDeltaActivePowerUpVariable, RegulationDevice ###########################

get_variable_binary(::AdditionalDeltaActivePowerUpVariable, ::Type{<:PSY.RegulationDevice}, ::AbstractRegulationFormulation) = false
get_variable_lower_bound(::AdditionalDeltaActivePowerUpVariable, ::PSY.RegulationDevice, ::AbstractRegulationFormulation) = 0.0

############################ AdditionalDeltaActivePowerDownVariable, RegulationDevice ###########################

get_variable_binary(::AdditionalDeltaActivePowerDownVariable, ::Type{<:PSY.RegulationDevice}, ::AbstractRegulationFormulation) = false
get_variable_lower_bound(::AdditionalDeltaActivePowerDownVariable, ::PSY.RegulationDevice, ::AbstractRegulationFormulation) = 0.0

#! format: on

function add_constraints!(
    container::OptimizationContainer,
    ::Type{DeltaActivePowerUpVariableLimitsConstraint},
    ::Type{DeltaActivePowerUpVariable},
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, DeviceLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    ::Nothing,
) where {T <: PSY.RegulationDevice{U}} where {U <: PSY.StaticInjection}
    parameters = built_for_simulation(container)
    var_up = get_variable(container, DeltaActivePowerUpVariable(), T)

    names = [PSY.get_name(g) for g in devices]
    time_steps = get_time_steps(container)

    # TODO DT: should "up" be specified in meta instead of the constraint type?
    container_up =
        add_cons_container!(container, RegulationLimitsUpConstraint(), U, names, time_steps)

    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(container, d, "max_active_power")
        constraint_info = DeviceTimeSeriesConstraintInfo(
            d,
            x -> PSY.get_max_active_power(x),
            ts_vector,
            x -> PSY.get_active_power_limits(x),
        )
        constraint_infos[ix] = constraint_info
    end

    if parameters
        base_points_param = get_parameter(container, VariableKey(ActivePowerVariable, U))
        multiplier = get_multiplier_array(base_points_param)
        base_points = get_parameter_array(base_points_param)
    end

    for d in constraint_infos
        name = get_component_name(d)
        limits = get_limits(d)
        for t in time_steps
            rating = parameters ? multiplier[name, t] : d.multiplier
            base_point = parameters ? base_points[name, t] : get_timeseries(d)[t]
            container_up[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                var_up[name, t] <= limits.max - base_point * rating
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{DeltaActivePowerDownVariableLimitsConstraint},
    ::Type{DeltaActivePowerDownVariable},
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, DeviceLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    ::Nothing,
) where {T <: PSY.RegulationDevice{U}} where {U <: PSY.StaticInjection}
    parameters = built_for_simulation(container)
    var_dn = get_variable(container, DeltaActivePowerDownVariable(), T)

    names = [PSY.get_name(g) for g in devices]
    time_steps = get_time_steps(container)

    container_dn = add_cons_container!(
        container,
        RegulationLimitsDownConstraint(),
        U,
        names,
        time_steps,
    )

    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(container, d, "max_active_power")
        constraint_info = DeviceTimeSeriesConstraintInfo(
            d,
            x -> PSY.get_max_active_power(x),
            ts_vector,
            x -> PSY.get_active_power_limits(x),
        )
        constraint_infos[ix] = constraint_info
    end

    if parameters
        base_points_param = get_parameter(container, VariableKey(ActivePowerVariable, T))
        multiplier = get_multiplier_array(base_points_param)
        base_points = get_parameter_array(base_points_param)
    end

    for d in constraint_infos
        name = get_component_name(d)
        limits = get_limits(d)
        for t in time_steps
            rating = parameters ? multiplier[name, t] : d.multiplier
            base_point = parameters ? base_points[name, t] : get_timeseries(d)[t]
            container_dn[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                var_dn[name, t] <= base_point * rating - limits.min
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{DeltaActivePowerUpVariableLimitsConstraint},
    ::Type{DeltaActivePowerUpVariable},
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, ReserveLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    ::Nothing,
) where {T <: PSY.RegulationDevice{U}} where {U <: PSY.StaticInjection}
    var_up = get_variable(container, DeltaActivePowerUpVariable(), T)

    names = [PSY.get_name(g) for g in devices]
    time_steps = get_time_steps(container)

    container_up =
        add_cons_container!(container, RegulationLimitsUpConstraint(), U, names, time_steps)

    for d in devices
        name = PSY.get_name(d)
        limit_up = PSY.get_reserve_limit_up(d)
        for t in time_steps
            container_up[name, t] =
                JuMP.@constraint(container.JuMPmodel, var_up[name, t] <= limit_up)
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{DeltaActivePowerDownVariableLimitsConstraint},
    ::Type{DeltaActivePowerDownVariable},
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, ReserveLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    ::Nothing,
) where {T <: PSY.RegulationDevice{U}} where {U <: PSY.StaticInjection}
    var_dn = get_variable(container, DeltaActivePowerDownVariable(), T)

    names = [PSY.get_name(g) for g in devices]
    time_steps = get_time_steps(container)

    container_dn = add_cons_container!(
        container,
        RegulationLimitsDownConstraint(),
        U,
        names,
        time_steps,
    )

    for d in devices
        name = PSY.get_name(d)
        limit_up = PSY.get_reserve_limit_dn(d)
        for t in time_steps
            container_dn[name, t] =
                JuMP.@constraint(container.JuMPmodel, var_dn[name, t] <= limit_up)
        end
    end
    return
end

function ramp_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, DeviceLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    ::Nothing,
) where {T <: PSY.RegulationDevice{U}} where {U <: PSY.StaticInjection}
    R_up = get_variable(container, DeltaActivePowerUpVariable(), T)
    R_dn = get_variable(container, DeltaActivePowerDownVariable(), T)

    resolution = Dates.value(Dates.Second(get_resolution(container)))
    names = [PSY.get_name(g) for g in devices]
    time_steps = get_time_steps(container)

    # TODO DT: appropriate use of meta?
    # TODO DT: is component_type correct?
    container_up = add_cons_container!(
        container,
        RampLimitConstraint(),
        U,
        names,
        time_steps,
        meta = "up",
    )
    container_dn = add_cons_container!(
        container,
        RampLimitConstraint(),
        U,
        names,
        time_steps,
        meta = "dn",
    )

    for d in devices
        ramp_limits = PSY.get_ramp_limits(d)
        ramp_limits === nothing && continue
        scaling_factor = resolution * SECONDS_IN_MINUTE
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

function participation_assignment!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, <:AbstractRegulationFormulation},
    ::Type{AreaBalancePowerModel},
    ::Nothing,
) where {T <: PSY.RegulationDevice{U}} where {U <: PSY.StaticInjection}
    time_steps = get_time_steps(container)
    R_up = get_variable(container, DeltaActivePowerUpVariable(), T)
    R_dn = get_variable(container, DeltaActivePowerDownVariable(), T)
    R_up_emergency = get_variable(container, AdditionalDeltaActivePowerUpVariable(), T)
    R_dn_emergency = get_variable(container, AdditionalDeltaActivePowerUpVariable(), T)
    area_reserve_up = get_variable(container, DeltaActivePowerUpVariable(), PSY.Area)
    area_reserve_dn = get_variable(container, DeltaActivePowerDownVariable(), PSY.Area)

    component_names = [PSY.get_name(d) for d in devices]

    # TODO DT: appropriate use of meta?
    participation_assignment_up = add_cons_container!(
        container,
        ParticipationAssignmentConstraint(),
        T,
        component_names,
        time_steps,
        meta = "up",
    )
    participation_assignment_dn = add_cons_container!(
        container,
        ParticipationAssignmentConstraint(),
        T,
        component_names,
        time_steps,
        meta = "dn",
    )

    expr_up = get_expression(container, :emergency_up)
    expr_dn = get_expression(container, :emergency_dn)
    for d in devices
        name = PSY.get_name(d)
        services = PSY.get_services(d)
        if length(services) > 1
            device_agc = (a for a in PSY.get_services(d) if isa(a, PSY.AGC))
            area_name = PSY.get_name.(PSY.get_area.(device_agc))[1]
        else
            device_agc = first(services)
            area_name = PSY.get_name(PSY.get_area(device_agc))
        end
        p_factor = PSY.get_participation_factor(d)
        for t in time_steps
            participation_assignment_up[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                R_up[name, t] ==
                (p_factor.up * area_reserve_up[area_name, t]) + R_up_emergency[name, t]
            )
            participation_assignment_dn[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                R_dn[name, t] ==
                (p_factor.dn * area_reserve_dn[area_name, t]) + R_dn_emergency[name, t]
            )
            JuMP.add_to_expression!(expr_up[area_name, t], -1 * R_up_emergency[name, t])
            JuMP.add_to_expression!(expr_dn[area_name, t], -1 * R_dn_emergency[name, t])
        end
    end

    return
end

function regulation_cost!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, <:AbstractRegulationFormulation},
) where {T <: PSY.RegulationDevice{U}} where {U <: PSY.StaticInjection}
    time_steps = get_time_steps(container)
    R_up_emergency = get_variable(container, AdditionalDeltaActivePowerUpVariable(), T)
    R_dn_emergency = get_variable(container, AdditionalDeltaActivePowerUpVariable(), T)

    for d in devices
        p_factor = PSY.get_participation_factor(d)
        up_cost =
            isapprox(p_factor.up, 0.0; atol = 1e-2) ? SERVICES_SLACK_COST : 1 / p_factor.up
        dn_cost =
            isapprox(p_factor.dn, 0.0; atol = 1e-2) ? SERVICES_SLACK_COST : 1 / p_factor.dn
        for t in time_steps
            JuMP.add_to_expression!(
                container.cost_function,
                R_up_emergency[PSY.get_name(d), t],
                up_cost,
            )
            JuMP.add_to_expression!(
                container.cost_function,
                R_dn_emergency[PSY.get_name(d), t],
                dn_cost,
            )
        end
    end
    return
end
