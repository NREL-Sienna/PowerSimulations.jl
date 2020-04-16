abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end
abstract type AbstractRenewableDispatchFormulation <: AbstractRenewableFormulation end
struct RenewableFullDispatch <: AbstractRenewableDispatchFormulation end
struct RenewableConstantPowerFactor <: AbstractRenewableDispatchFormulation end

########################### renewable generation variables #################################
function activepower_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{R},
) where {R <: PSY.RenewableGen}
    add_variable(
        psi_container,
        devices,
        variable_name(ACTIVE_POWER, R),
        false,
        :nodal_balance_active;
        lb_value = x -> 0.0,
        ub_value = x -> PSY.get_rating(x),
    )
    return
end

function reactivepower_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{R},
) where {R <: PSY.RenewableGen}
    add_variable(
        psi_container,
        devices,
        variable_name(REACTIVE_POWER, R),
        false,
        :nodal_balance_reactive,
    )
    return
end

####################################### Reactive Power Constraints #########################
function reactivepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{R},
    model::DeviceModel{R, RenewableFullDispatch},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {R <: PSY.RenewableGen}
    constraint_data = Vector{DeviceRange}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        if isnothing(PSY.get_reactivepowerlimits(d))
            lims = (min = 0.0, max = 0.0)
            @warn("Reactive Power Limits of $(lims) are nothing. Q_$(lims) is set to 0.0")
        else
            lims = PSY.get_reactivepowerlimits(d)
        end
        constraint_data[ix] = DeviceRange(name, lims)
    end
    device_range(
        psi_container,
        constraint_data,
        constraint_name(REACTIVE_RANGE, R),
        variable_name(REACTIVE_POWER, R),
    )
    return
end

function reactivepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{R},
    model::DeviceModel{R, RenewableConstantPowerFactor},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {R <: PSY.RenewableGen}
    names = (PSY.get_name(d) for d in devices)
    time_steps = model_time_steps(psi_container)
    p_var = get_variable(psi_container, ACTIVE_POWER, R)
    q_var = get_variable(psi_container, REACTIVE_POWER, R)
    constraint_val = JuMPConstraintArray(undef, names, time_steps)
    assign_constraint!(psi_container, REACTIVE_RANGE, R, constraint_val)
    for t in time_steps, d in available_devices(devices)
        name = PSY.get_name(d)
        pf = sin(acos(PSY.get_powerfactor(d)))
        constraint_val[name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, q_var[name, t] == p_var[name, t] * pf)
    end
    return
end

function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{R},
    model::DeviceModel{R, <:AbstractRenewableDispatchFormulation},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {R <: PSY.RenewableGen}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    if !parameters && !use_forecast_data
        constraint_data = Vector{DeviceRange}(undef, length(devices))
        for (ix, d) in enumerate(devices)
            name = PSY.get_name(d)
            ub = PSY.get_activepower(d)
            limits = (min = 0.0, max = ub)
            range_data = DeviceRange(name, limits)
            add_device_services!(range_data, d, model)
            constraint_data[ix] = range_data
        end
        device_range(
            psi_container,
            constraint_data,
            constraint_name(ACTIVE_RANGE, R),
            variable_name(ACTIVE_POWER, R),
        )
        return
    end

    forecast_label = "get_rating"
    constraint_data = Vector{DeviceTimeSeries}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        timeseries_data = DeviceTimeSeries(d, x -> PSY.get_rating(x), ts_vector)
        add_device_services!(timeseries_data, d, model)
        constraint_data[ix] = timeseries_data
    end

    if parameters
        device_timeseries_param_ub(
            psi_container,
            constraint_data,
            constraint_name(ACTIVE, R),
            UpdateRef{R}(ACTIVE_POWER, forecast_label),
            variable_name(ACTIVE_POWER, R),
        )
    else
        device_timeseries_ub(
            psi_container,
            constraint_data,
            constraint_name(ACTIVE, R),
            variable_name(ACTIVE_POWER, R),
        )
    end
    return
end

########################## Addition of to the nodal balances ###############################
function nodal_expression!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{R},
    system_formulation::Type{<:PM.AbstractPowerModel},
) where {R <: PSY.RenewableGen}
    nodal_expression!(psi_container, devices, PM.AbstractActivePowerModel)
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    if use_forecast_data
        forecast_label = "get_rating"
        peak_value_function = x -> PSY.get_rating(x) * sin(acos(PSY.get_powerfactor(x)))
    else
        forecast_label = ""
        peak_value_function = x -> PSY.get_reactivepower(x)
    end
    constraint_data = Vector{DeviceTimeSeries}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        timeseries_data = DeviceTimeSeries(d, peak_value_function, ts_vector)
        constraint_data[ix] = timeseries_data
    end

    if parameters
        include_parameters(
            psi_container,
            constraint_data,
            UpdateRef{R}(REACTIVE_POWER, forecast_label),
            :nodal_balance_active,
        )
        return
    else
        for t in model_time_steps(psi_container)
            for device in constraint_data
                add_to_expression!(
                    psi_container.expressions[:nodal_balance_reactive],
                    device.bus_number,
                    t,
                    device.multiplier * device.timeseries[t],
                )
            end
        end
    end
    return
end

function nodal_expression!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{R},
    system_formulation::Type{<:PM.AbstractActivePowerModel},
) where {R <: PSY.RenewableGen}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    if use_forecast_data
        forecast_label = "get_rating"
        peak_value_function = x -> PSY.get_rating(x) * PSY.get_powerfactor(x)
    else
        forecast_label = ""
        peak_value_function = x -> PSY.get_activepower(x)
    end
    constraint_data = Vector{DeviceTimeSeries}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        timeseries_data = DeviceTimeSeries(d, peak_value_function, ts_vector)
        constraint_data[ix] = timeseries_data
    end

    if parameters
        include_parameters(
            psi_container,
            constraint_data,
            UpdateRef{R}(ACTIVE_POWER, forecast_label),
            :nodal_balance_active,
        )
        return
    else
        for t in model_time_steps(psi_container)
            for device in constraint_data
                add_to_expression!(
                    psi_container.expressions[:nodal_balance_active],
                    device.bus_number,
                    t,
                    device.multiplier * device.timeseries[t],
                )
            end
        end
    end
    return
end

##################################### renewable generation cost ############################
function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.RenewableDispatch},
    device_formulation::Type{D},
    system_formulation::Type{<:PM.AbstractPowerModel},
) where {D <: AbstractRenewableDispatchFormulation}
    add_to_cost(
        psi_container,
        devices,
        variable_name(ACTIVE_POWER, PSY.RenewableDispatch),
        :fixed,
        -1.0,
    )
    return
end
