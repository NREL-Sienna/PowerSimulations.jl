abstract type AbstractRegulationFormulation <: AbstractDeviceFormulation end
struct ReserveLimitedRegulation <: AbstractDeviceFormulation end
struct DeviceLimitedRegulation <: AbstractDeviceFormulation end

"""
This function add the variables for reserves to the model
"""
function regulation_service_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.RegulationDevice}
    up_var_name = variable_name("ΔP_UP")
    dn_var_name = variable_name("ΔP_DN")
    # Upwards regulation
    add_variable(psi_container, devices, up_var_name, false; lb_value = x -> 0.0)
    # Downwards regulation
    add_variable(psi_container, devices, dn_var_name, false; lb_value = x -> 0.0)

    up_var = get_variable(psi_container, up_var_name)
    dn_var = get_variable(psi_container, dn_var_name)
    time_steps = model_time_steps(psi_container)
    names = (PSY.get_name(d) for d in devices)
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

function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, DeviceLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    feedforward::Nothing,
) where {T <: PSY.RegulationDevice}
    constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limits = (min = 0.0, max = PSY.get_activepowerlimits(d).max)
        name = PSY.get_name(d)
        constraint_info = DeviceRangeConstraintInfo(name, limits)
        add_device_services!(constraint_info, d, model)
        constraint_infos[ix] = constraint_info
    end

    var_key = variable_name(ACTIVE_POWER, T)
    variable = get_variable(psi_container, var_key)

    device_range(
        psi_container,
        constraint_infos,
        constraint_name(ACTIVE_RANGE, T),
        variable_name(ACTIVE_POWER, T),
    )
    return
end

function ramp_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, DeviceLimitedRegulation},
    ::Type{AreaBalancePowerModel},
    feedforward::Nothing,
) where {T <: PSY.RegulationDevice}
    constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limits = (min = 0.0, max = PSY.get_activepowerlimits(d).max)
        name = PSY.get_name(d)
        constraint_info = DeviceRangeConstraintInfo(name, limits)
        add_device_services!(constraint_info, d, model)
        constraint_infos[ix] = constraint_info
    end

    var_key = variable_name(ACTIVE_POWER, T)
    variable = get_variable(psi_container, var_key)
    # If the variable was a lower bound != 0, not removing the LB can cause infeasibilities
    for v in variable
        if JuMP.has_lower_bound(v)
            JuMP.set_lower_bound(v, 0.0)
        end
    end

    device_range(
        psi_container,
        constraint_infos,
        constraint_name(ACTIVE_RANGE, T),
        variable_name(ACTIVE_POWER, T),
    )
    return
end

function participation_assignment!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, <:AbstractThermalDispatchFormulation},
    ::Type{AreaBalancePowerModel},
    feedforward::Nothing,
) where {T <: PSY.RegulationDevice}
    time_steps = model_time_steps(psi_container)
    regulation = get_expression(psi_container, :device_regulation_balance)
    area_unbalance = get_expression(psi_container, :area_unbalance)
    ΔP = get_variable(psi_container, variable_name("AGC_aux"))
    component_names = (PSY.get_name(d) for d in devices)
    participation_assignment = JuMPConstraintArray(undef, component_names, time_steps)
    assign_constraint!(psi_container, "participation_assignment", participation_assignment)
    for d in devices
        area_name = PSY.get_name(PSY.get_area(PSY.get_services(d)[1]))
        sum_p_factors = 0.0
        temp_values = Vector(undef, length(contributing_devices))
        for (ix, d) in enumerate(contributing_devices)
            name = PSY.get_name(d)
            p_factor = PSY.get_participation_factor(d)
            sum_p_factors += p_factor
            temp_values[ix] = (name, p_factor)
        end

        for (ix, d) in enumerate(temp_values)
            for t in time_steps
                participation_assignment[d[1], t] = JuMP.@constraint(
                    psi_container.JuMPmodel,
                    regulation[d[1], t] == (d[2] / sum_p_factors) * (ΔP[area_name, t])
                )
            end
        end
    end
    return
end
