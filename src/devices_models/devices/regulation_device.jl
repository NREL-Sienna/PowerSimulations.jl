#! format: off

abstract type AbstractRegulationFormulation <: AbstractDeviceFormulation end
struct ReserveLimitedRegulation <: AbstractRegulationFormulation end
struct DeviceLimitedRegulation <: AbstractRegulationFormulation end

get_variable_sign(_, ::Type{PSY.RegulationDevice{PSY.ThermalStandard}}, ::DeviceLimitedRegulation) = NaN
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
    optimization_container::OptimizationContainer,
    ::Type{RangeConstraint},
    ::Type{DeltaActivePowerUpVariable},
    devices::IS.FlattenIteratorWrapper{PSY.RegulationDevice{T}},
    ::DeviceModel{PSY.RegulationDevice{T}, DeviceLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    ::Nothing,
) where {T <: PSY.StaticInjection}
    parameters = model_has_parameters(optimization_container)
    var_name_up = make_variable_name(DeltaActivePowerUpVariable, T)
    var_up = get_variable(optimization_container, var_name_up)

    names = [PSY.get_name(g) for g in devices]
    time_steps = model_time_steps(optimization_container)

    up = Symbol("regulation_limits_up_$(T)")
    container_up = add_cons_container!(optimization_container, up, names, time_steps)

    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(optimization_container, d, "max_active_power")
        constraint_info = DeviceTimeSeriesConstraintInfo(
            d,
            x -> PSY.get_max_active_power(x),
            ts_vector,
            x -> PSY.get_active_power_limits(x),
        )
        constraint_infos[ix] = constraint_info
    end

    if parameters
        base_points_param = get_parameter_container(
            optimization_container,
            make_variable_name(ACTIVE_POWER, T),
        )
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
                optimization_container.JuMPmodel,
                var_up[name, t] <= limits.max - base_point * rating
            )
        end
    end
    return
end

function add_constraints!(
    optimization_container::OptimizationContainer,
    ::Type{RangeConstraint},
    ::Type{DeltaActivePowerDownVariable},
    devices::IS.FlattenIteratorWrapper{PSY.RegulationDevice{T}},
    ::DeviceModel{PSY.RegulationDevice{T}, DeviceLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    ::Nothing,
) where {T <: PSY.StaticInjection}
    parameters = model_has_parameters(optimization_container)
    var_name_dn = make_variable_name(DeltaActivePowerDownVariable, T)
    var_dn = get_variable(optimization_container, var_name_dn)

    names = [PSY.get_name(g) for g in devices]
    time_steps = model_time_steps(optimization_container)

    dn = Symbol("regulation_limits_dn_$(T)")
    container_dn = add_cons_container!(optimization_container, dn, names, time_steps)

    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(optimization_container, d, "max_active_power")
        constraint_info = DeviceTimeSeriesConstraintInfo(
            d,
            x -> PSY.get_max_active_power(x),
            ts_vector,
            x -> PSY.get_active_power_limits(x),
        )
        constraint_infos[ix] = constraint_info
    end

    if parameters
        base_points_param = get_parameter_container(
            optimization_container,
            make_variable_name(ACTIVE_POWER, T),
        )
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
                optimization_container.JuMPmodel,
                var_dn[name, t] <= base_point * rating - limits.min
            )
        end
    end
    return
end

function add_constraints!(
    optimization_container::OptimizationContainer,
    ::Type{RangeConstraint},
    ::Type{DeltaActivePowerUpVariable},
    devices::IS.FlattenIteratorWrapper{PSY.RegulationDevice{T}},
    ::DeviceModel{PSY.RegulationDevice{T}, ReserveLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    ::Nothing,
) where {T <: PSY.StaticInjection}
    var_name_up = make_variable_name(DeltaActivePowerUpVariable, T)
    var_up = get_variable(optimization_container, var_name_up)

    names = [PSY.get_name(g) for g in devices]
    time_steps = model_time_steps(optimization_container)

    up = Symbol("regulation_limits_up_$(T)")
    container_up = add_cons_container!(optimization_container, up, names, time_steps)

    for d in devices
        name = PSY.get_name(d)
        limit_up = PSY.get_reserve_limit_up(d)
        for t in time_steps
            container_up[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                var_up[name, t] <= limit_up
            )
        end
    end
    return
end

function add_constraints!(
    optimization_container::OptimizationContainer,
    ::Type{RangeConstraint},
    ::Type{DeltaActivePowerDownVariable},
    devices::IS.FlattenIteratorWrapper{PSY.RegulationDevice{T}},
    ::DeviceModel{PSY.RegulationDevice{T}, ReserveLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    ::Nothing,
) where {T <: PSY.StaticInjection}
    var_name_dn = make_variable_name(DeltaActivePowerDownVariable, T)
    var_dn = get_variable(optimization_container, var_name_dn)

    names = [PSY.get_name(g) for g in devices]
    time_steps = model_time_steps(optimization_container)

    dn = Symbol("regulation_limits_dn_$(T)")
    container_dn = add_cons_container!(optimization_container, dn, names, time_steps)

    for d in devices
        name = PSY.get_name(d)
        limit_up = PSY.get_reserve_limit_dn(d)
        for t in time_steps
            container_dn[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                var_dn[name, t] <= limit_up
            )
        end
    end
    return
end

function ramp_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{PSY.RegulationDevice{T}},
    ::DeviceModel{PSY.RegulationDevice{T}, DeviceLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    ::Nothing,
) where {T <: PSY.ThermalStandard}
    R_up = get_variable(optimization_container, DeltaActivePowerUpVariable, T)
    R_dn = get_variable(optimization_container, DeltaActivePowerDownVariable, T)

    resolution = Dates.value(Dates.Second(model_resolution(optimization_container)))
    names = [PSY.get_name(g) for g in devices]
    time_steps = model_time_steps(optimization_container)

    container_up =
        add_cons_container!(optimization_container, :ramp_limits_up, names, time_steps)
    container_dn =
        add_cons_container!(optimization_container, :ramp_limits_dn, names, time_steps)

    for d in devices
        ramp_limits = PSY.get_ramp_limits(d)
        ramp_limits === nothing && continue
        scaling_factor = resolution * SECONDS_IN_MINUTE
        name = PSY.get_name(d)
        for t in time_steps
            container_up[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                R_up[name, t] <= ramp_limits.up * scaling_factor
            )
            container_dn[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                R_dn[name, t] <= ramp_limits.down * scaling_factor
            )
        end
    end
    return
end

function participation_assignment!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{PSY.RegulationDevice{T}},
    ::DeviceModel{PSY.RegulationDevice{T}, <:AbstractRegulationFormulation},
    ::Type{AreaBalancePowerModel},
    ::Nothing,
) where {T <: PSY.StaticInjection}
    time_steps = model_time_steps(optimization_container)
    R_up = get_variable(optimization_container, DeltaActivePowerUpVariable, T)
    R_dn = get_variable(optimization_container, DeltaActivePowerDownVariable, T)
    R_up_emergency =
        get_variable(optimization_container, AdditionalDeltaActivePowerUpVariable, T)
    R_dn_emergency =
        get_variable(optimization_container, AdditionalDeltaActivePowerUpVariable, T)
    area_reserve_up =
        get_variable(optimization_container, DeltaActivePowerUpVariable, PSY.Area)
    area_reserve_dn =
        get_variable(optimization_container, DeltaActivePowerDownVariable, PSY.Area)

    component_names = [PSY.get_name(d) for d in devices]
    participation_assignment_up = JuMPConstraintArray(undef, component_names, time_steps)
    participation_assignment_dn = JuMPConstraintArray(undef, component_names, time_steps)
    assign_constraint!(
        optimization_container,
        "participation_assignment_up",
        participation_assignment_up,
    )
    assign_constraint!(
        optimization_container,
        "participation_assignment_dn",
        participation_assignment_dn,
    )

    expr_up = get_expression(optimization_container, :emergency_up)
    expr_dn = get_expression(optimization_container, :emergency_dn)
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
                optimization_container.JuMPmodel,
                R_up[name, t] ==
                (p_factor.up * area_reserve_up[area_name, t]) + R_up_emergency[name, t]
            )
            participation_assignment_dn[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
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
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{PSY.RegulationDevice{T}},
    ::DeviceModel{PSY.RegulationDevice{T}, <:AbstractRegulationFormulation},
) where {T <: PSY.StaticInjection}
    time_steps = model_time_steps(optimization_container)
    R_up_emergency =
        get_variable(optimization_container, AdditionalDeltaActivePowerUpVariable, T)
    R_dn_emergency =
        get_variable(optimization_container, AdditionalDeltaActivePowerUpVariable, T)

    for d in devices
        p_factor = PSY.get_participation_factor(d)
        up_cost =
            isapprox(p_factor.up, 0.0; atol = 1e-2) ? SERVICES_SLACK_COST : 1 / p_factor.up
        dn_cost =
            isapprox(p_factor.dn, 0.0; atol = 1e-2) ? SERVICES_SLACK_COST : 1 / p_factor.dn
        for t in time_steps
            JuMP.add_to_expression!(
                optimization_container.cost_function,
                R_up_emergency[PSY.get_name(d), t],
                up_cost,
            )
            JuMP.add_to_expression!(
                optimization_container.cost_function,
                R_dn_emergency[PSY.get_name(d), t],
                dn_cost,
            )
        end
    end
    return
end

function NodalExpressionSpec(
    ::Type{<:PSY.RegulationDevice{T}},
    ::Type{AreaBalancePowerModel},
    use_forecasts::Bool,
) where {T <: PSY.StaticInjection}
    return NodalExpressionSpec(
        "max_active_power",
        make_variable_name(ActivePowerVariable, T),
        use_forecasts ? x -> PSY.get_max_active_power(x) : x -> PSY.get_active_power(x),
        1.0,
        JuMP.VariableRef,
    )
end
