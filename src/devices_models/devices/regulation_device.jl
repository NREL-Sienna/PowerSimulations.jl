abstract type AbstractRegulationFormulation <: AbstractDeviceFormulation end
struct ReserveLimitedRegulation <: AbstractRegulationFormulation end
struct DeviceLimitedRegulation <: AbstractRegulationFormulation end

"""
This function add the variables for reserves to the model
"""
function make_variable_inputs(
    ::Type{RegulationServiceVariable},
    ::Type{T},
    ::PSIContainer,
) where {T <: PSY.Device}
    return [
        AddVariableInputs(;
            variable_name = "ΔP_up",
            binary = false,
            lb_value_func = x -> 0.0,
        ),
        AddVariableInputs(;
            variable_name = "ΔP_dn",
            binary = false,
            lb_value_func = x -> 0.0,
        ),
    ]
end

function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.RegulationDevice{T}},
    ::DeviceModel{PSY.RegulationDevice{T}, DeviceLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    feedforward::Nothing,
) where {T <: PSY.StaticInjection}
    parameters = model_has_parameters(psi_container)
    var_name_up = variable_name("ΔP_up", T)
    var_name_dn = variable_name("ΔP_dn", T)
    var_up = get_variable(psi_container, var_name_up)
    var_dn = get_variable(psi_container, var_name_dn)

    names = (PSY.get_name(g) for g in devices)
    time_steps = model_time_steps(psi_container)

    up = Symbol("regulation_limits_up_$(T)")
    dn = Symbol("regulation_limits_dn_$(T)")
    container_up = add_cons_container!(psi_container, up, names, time_steps)
    container_dn = add_cons_container!(psi_container, dn, names, time_steps)

    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, "get_rating")
        constraint_info = DeviceTimeSeriesConstraintInfo(
            d,
            x -> PSY.get_rating(x),
            ts_vector,
            x -> PSY.get_activepowerlimits(x),
        )
        constraint_infos[ix] = constraint_info
    end

    if parameters
        base_points_param =
            get_parameter_container(psi_container, variable_name(ACTIVE_POWER, T))
        multiplier = get_multiplier_array(base_points_param)
        base_points = get_parameter_array(base_points_param)
    end

    for d in constraint_infos
        name = get_name(d)
        limits = get_limits(d)
        for t in time_steps
            rating = parameters ? multiplier[name, t] : d.multiplier
            base_point = parameters ? base_points[name, t] : get_timeseries(d)[t]
            container_up[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                var_up[name, t] <= limits.max - base_point * rating
            )
            container_dn[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                var_dn[name, t] <= base_point * rating - limits.min
            )
        end
    end
    return
end

function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.RegulationDevice{T}},
    ::DeviceModel{PSY.RegulationDevice{T}, ReserveLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    feedforward::Nothing,
) where {T <: PSY.StaticInjection}
    var_name_up = variable_name("ΔP_up", T)
    var_name_dn = variable_name("ΔP_dn", T)
    var_up = get_variable(psi_container, var_name_up)
    var_dn = get_variable(psi_container, var_name_dn)

    names = (PSY.get_name(g) for g in devices)
    time_steps = model_time_steps(psi_container)

    up = Symbol("regulation_limits_up_$(T)")
    dn = Symbol("regulation_limits_dn_$(T)")
    container_up = add_cons_container!(psi_container, up, names, time_steps)
    container_dn = add_cons_container!(psi_container, dn, names, time_steps)

    for d in devices
        name = PSY.get_name(d)
        limit_up = PSY.get_reserve_limit_up(d)
        limit_dn = PSY.get_reserve_limit_dn(d)
        for t in time_steps
            container_up[name, t] =
                JuMP.@constraint(psi_container.JuMPmodel, var_up[name, t] <= limit_up)
            container_dn[name, t] =
                JuMP.@constraint(psi_container.JuMPmodel, var_dn[name, t] <= limit_dn)
        end
    end
    return
end

#=
function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.RegulationDevice{T}},
    ::DeviceModel{PSY.RegulationDevice{T},ReserveLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    feedforward::UpperBoundFF,
) where {T<:PSY.StaticInjection}
    var_name = feedforward.affected_variables[1]
    var_up = get_variable(psi_container, var_name)

    names = (PSY.get_name(g) for g in devices)
    time_steps = model_time_steps(psi_container)

    var = Symbol("regulation_limits_$(var_name)")
    container = add_cons_container!(psi_container, var, names, time_steps)
    param_container = add_param_container!(psi_container, UpdateRef{JuMP.VariableRef}(feedforward.variable_source_stage), names, time_steps)
    param = get_parameter_array(param_container)

    for d in devices
        name = PSY.get_name(d)
        value = PSY.get_rating(d)
        for t in time_steps
            param[name,t] = PJ.add_parameter(psi_container.JuMPmodel, value)
            container[name, t] =
                JuMP.@constraint(psi_container.JuMPmodel, var_up[name, t] <= param[name, t])
        end
    end
    return
end
=#

ramp_constraints!(
    ::PSIContainer,
    ::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, <:AbstractRegulationFormulation},
    ::Type{AreaBalancePowerModel},
    ::Nothing,
) where {T <: PSY.RegulationDevice} = nothing

function ramp_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.RegulationDevice{T}},
    ::DeviceModel{PSY.RegulationDevice{T}, DeviceLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    feedforward::Nothing,
) where {T <: PSY.ThermalStandard}
    regulation_up = get_variable(psi_container, variable_name("ΔP_up", T))
    regulation_dn = get_variable(psi_container, variable_name("ΔP_dn", T))

    resolution = Dates.value(Dates.Second(model_resolution(psi_container)))
    names = (PSY.get_name(g) for g in devices)
    time_steps = model_time_steps(psi_container)

    container_up = add_cons_container!(psi_container, :ramp_limits_up, names, time_steps)
    container_dn = add_cons_container!(psi_container, :ramp_limits_dn, names, time_steps)

    for d in devices
        ramplimits(d) = PSY.get_ramplimits(d)
        scaling_factor = PSY.get_basepower(d) * resolution * SECONDS_IN_MINUTE
        name = PSY.get_name(d)
        for t in time_steps
            container_up[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                regulation_up[name, t] <= ramplimits(d).up * scaling_factor
            )
            container_dn[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                regulation_dn[name, t] <= ramplimits(d).down * scaling_factor
            )
        end
    end
    return
end

function participation_assignment!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.RegulationDevice{T}},
    ::DeviceModel{PSY.RegulationDevice{T}, <:AbstractRegulationFormulation},
    ::Type{AreaBalancePowerModel},
    feedforward::Nothing,
) where {T <: PSY.StaticInjection}
    time_steps = model_time_steps(psi_container)
    regulation_up = get_variable(psi_container, variable_name("ΔP_up", T))
    regulation_dn = get_variable(psi_container, variable_name("ΔP_dn", T))

    R_up = get_variable(psi_container, variable_name("area_total_reserve_up"))
    R_dn = get_variable(psi_container, variable_name("area_total_reserve_dn"))
    component_names = (PSY.get_name(d) for d in devices)
    participation_assignment_up = JuMPConstraintArray(undef, component_names, time_steps)
    participation_assignment_dn = JuMPConstraintArray(undef, component_names, time_steps)
    assign_constraint!(
        psi_container,
        "participation_assignment_up",
        participation_assignment_up,
    )
    assign_constraint!(
        psi_container,
        "participation_assignment_dn",
        participation_assignment_dn,
    )

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
                psi_container.JuMPmodel,
                regulation_up[name, t] == p_factor.up * (R_up[area_name, t])
            )
            participation_assignment_dn[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                regulation_dn[name, t] == p_factor.dn * (R_dn[area_name, t])
            )
        end
    end
    return
end

function regulation_cost!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.RegulationDevice{T}},
    ::DeviceModel{PSY.RegulationDevice{T}, <:AbstractRegulationFormulation},
) where {T <: PSY.StaticInjection}
    time_steps = model_time_steps(psi_container)
    regulation_up = get_variable(psi_container, variable_name("ΔP_up", T))
    regulation_dn = get_variable(psi_container, variable_name("ΔP_dn", T))

    for d in devices
        cost = PSY.get_cost(d)
        for t in time_steps
            JuMP.add_to_expression!(
                psi_container.cost_function,
                regulation_up[PSY.get_name(d), t],
                cost,
            )
            JuMP.add_to_expression!(
                psi_container.cost_function,
                regulation_dn[PSY.get_name(d), t],
                cost,
            )
        end
    end
    return
end

function make_nodal_expression_inputs(
    ::Type{<:PSY.RegulationDevice{T}},
    ::Type{AreaBalancePowerModel},
    use_forecasts::Bool,
) where {T <: PSY.StaticInjection}
    return NodalExpressionInputs(
        "get_rating",
        variable_name(ACTIVE_POWER, T),
        use_forecasts ? x -> PSY.get_rating(x) : x -> PSY.get_activepower(x),
        1.0,
        JuMP.VariableRef,
    )
end
