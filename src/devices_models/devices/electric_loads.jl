abstract type AbstractLoadFormulation <: AbstractDeviceFormulation end
abstract type AbstractControllablePowerLoadFormulation <: AbstractLoadFormulation end
struct StaticPowerLoad <: AbstractLoadFormulation end
struct InterruptiblePowerLoad <: AbstractControllablePowerLoadFormulation end
struct DispatchablePowerLoad <: AbstractControllablePowerLoadFormulation end

########################### dispatchable load variables ####################################
function activepower_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
) where {L <: PSY.ElectricLoad}
    add_variable(
        psi_container,
        devices,
        variable_name(ACTIVE_POWER, L),
        false,
        :nodal_balance_active,
        -1.0;
        ub_value = x -> PSY.get_maxactivepower(x),
        lb_value = x -> 0.0,
    )
    return
end

function reactivepower_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
) where {L <: PSY.ElectricLoad}
    add_variable(
        psi_container,
        devices,
        variable_name(REACTIVE_POWER, L),
        false,
        :nodal_balance_reactive,
        -1.0;
        ub_value = x -> PSY.get_maxreactivepower(x),
        lb_value = x -> 0.0,
    )
    return
end

function commitment_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
) where {L <: PSY.ElectricLoad}
    add_variable(psi_container, devices, variable_name(ON, L), true)
    return
end

####################################### Reactive Power Constraints #########################
"""
Reactive Power Constraints on Controllable Loads Assume Constant PowerFactor
"""
function reactivepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
    model::DeviceModel{L, <:AbstractControllablePowerLoadFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {L <: PSY.ElectricLoad}
    time_steps = model_time_steps(psi_container)
    constraint = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)
    assign_constraint!(psi_container, REACTIVE, L, constraint)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(atan((PSY.get_maxreactivepower(d) / PSY.get_maxactivepower(d))))
        reactive = get_variable(psi_container, REACTIVE_POWER, L)[name, t]
        real = get_variable(psi_container, ACTIVE_POWER, L)[name, t] * pf
        constraint[name, t] = JuMP.@constraint(psi_container.JuMPmodel, reactive == real)
    end
    return
end

function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
    model::DeviceModel{L, DispatchablePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {L <: PSY.ElectricLoad}
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
            constraint_name(ACTIVE_RANGE, L),
            variable_name(ACTIVE_POWER, L),
        )
        return
    end

    forecast_label = "get_maxactivepower"
    constraint_data = Vector{DeviceTimeSeries}()
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        timeseries_data = DeviceTimeSeries(d, x -> PSY.get_maxactivepower(x), ts_vector)
        add_device_services!(timeseries_data, d, model)
        constraint_data[ix] = timeseries_data
    end

    if parameters
        device_timeseries_param_ub(
            psi_container,
            constraint_data,
            constraint_name(ACTIVE, L),
            UpdateRef{L}(ACTIVE_POWER, forecast_label),
            variable_name(ACTIVE_POWER, L),
        )
    else
        device_timeseries_ub(
            psi_container,
            constraint_data,
            constraint_name(ACTIVE, L),
            variable_name(ACTIVE_POWER, L),
        )
    end
    return
end

function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
    model::DeviceModel{L, InterruptiblePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {L <: PSY.ElectricLoad}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    if !parameters && !use_forecast_data
        constraint_data = Vector{DeviceRange}(undef, length(devices))
        for (ix, d) in enumerate(devices)
            name = PSY.get_name(d)
            ub = PSY.get_active(d)
            limits = (min = 0.0, max = ub)
            range_data = DeviceRange(name, limits)
            add_device_services!(range_data, d, model)
            constraint_data[ix] = range_data
        end
        device_semicontinuousrange(
            psi_container,
            constraint_data,
            constraint_name(ACTIVE_RANGE, L),
            variable_name(ACTIVE_POWER, L),
            variable_name(ON, L),
        )
        return
    end

    forecast_label = "get_maxactivepower"
    constraint_data = Vector{DeviceTimeSeries}()
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        timeseries_data = DeviceTimeSeries(d, x -> PSY.get_maxactivepower(x), ts_vector)
        add_device_services!(timeseries_data, d, model)
        constraint_data[ix] = timeseries_data
    end

    if parameters
        device_timeseries_ub_bigM(
            psi_container,
            constraint_data,
            constraint_name(ACTIVE, L),
            variable_name(ACTIVE_POWER, L),
            UpdateRef{L}(ON, forecast_label),
            constraint_name(ON, L),
        )
    else
        device_timeseries_ub_bin(
            psi_container,
            constraint_data,
            constraint_name(ACTIVE, L),
            variable_name(ACTIVE_POWER, L),
            variable_name(ON, L),
        )
    end
    return
end

########################## Addition of to the nodal balances ###############################
function nodal_expression!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
    ::Type{<:PM.AbstractPowerModel},
) where {L <: PSY.ElectricLoad}
    #Run the Active Power Loop
    nodal_expression!(psi_container, devices, PM.AbstractActivePowerModel)
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    if parameters
        forecast_label = "get_maxreactivepower"
        peak_value_function = x -> PSY.get_maxreactivepower(x)
    else
        forecast_label = "get_reactivepower"
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
            UpdateRef{L}(REACTIVE_POWER, forecast_label),
            :nodal_balance_reactive,
            -1.0,
        )
        return
    else
        for t in model_time_steps(psi_container)
            for device in constraint_data
                add_to_expression!(
                    psi_container.expressions[:nodal_balance_reactive],
                    device.bus_number,
                    t,
                    -device.multiplier * device.timeseries[t],
                )
            end
        end
    end
    return
end

function nodal_expression!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
    ::Type{<:PM.AbstractActivePowerModel},
) where {L <: PSY.ElectricLoad}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    if use_forecast_data
        forecast_label = "get_maxactivepower"
        peak_value_function = x -> PSY.get_maxactivepower(x)
    else
        forecast_label = "get_activepower"
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
            UpdateRef{L}(ACTIVE_POWER, forecast_label),
            :nodal_balance_active,
            -1.0,
        )
        return
    else
        for t in model_time_steps(psi_container)
            for device in constraint_data
                add_to_expression!(
                    psi_container.expressions[:nodal_balance_active],
                    device.bus_number,
                    t,
                    -device.multiplier * device.timeseries[t],
                )
            end
        end
    end
    return
end

############################## FormulationControllable Load Cost ###########################
function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
    ::Type{DispatchablePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
) where {L <: PSY.ControllableLoad}
    add_to_cost(psi_container, devices, variable_name(ACTIVE_POWER, L), :variable, -1.0)
    return
end

function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
    ::Type{InterruptiblePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
) where {L <: PSY.ControllableLoad}
    add_to_cost(psi_container, devices, variable_name(ON, L), :fixed, -1.0)
    return
end
