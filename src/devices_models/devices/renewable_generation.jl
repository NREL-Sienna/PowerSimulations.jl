abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end
abstract type AbstractRenewableDispatchFormulation <: AbstractRenewableFormulation end
struct RenewableFixed <: AbstractRenewableFormulation end
struct RenewableFullDispatch <: AbstractRenewableDispatchFormulation end
struct RenewableConstantPowerFactor <: AbstractRenewableDispatchFormulation end

########################### renewable generation variables #################################
function activepower_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{R},
) where {R<:PSY.RenewableGen}
    add_variable(
        psi_container,
        devices,
        variable_name(ACTIVE_POWER, R),
        false,
        :nodal_balance_active;
        lb_value = x -> 0.0,
        ub_value = x -> PSY.get_rating(PSY.get_tech(x)),
    )
    return
end

function reactivepower_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{R},
) where {R<:PSY.RenewableGen}
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
    model::DeviceModel{R,RenewableFullDispatch},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feed_forward::Union{Nothing,AbstractAffectFeedForward},
) where {R<:PSY.RenewableGen}
    constraint_data = Vector{DeviceRange}()
    for (ix, d) in enumerate(devices)
        tech = PSY.get_tech(d)
        name = PSY.get_name(d)
        if isnothing(PSY.get_reactivepowerlimits(tech))
            lims = (min = 0.0, max = 0.0)
            @warn("Reactive Power Limits of $(lims) are nothing. Q_$(lims) is set to 0.0")
        else
            lims = PSY.get_reactivepowerlimits(tech)
        end
        push!(constraint_data, DeviceRange(name, lims))
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
    model::DeviceModel{R,RenewableConstantPowerFactor},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feed_forward::Union{Nothing,AbstractAffectFeedForward},
) where {R<:PSY.RenewableGen}
    names = (PSY.get_name(d) for d in devices)
    time_steps = model_time_steps(psi_container)
    p_var = get_variable(psi_container, ACTIVE_POWER, R)
    q_var = get_variable(psi_container, REACTIVE_POWER, R)
    constraint_val = JuMPConstraintArray(undef, names, time_steps)
    assign_constraint!(psi_container, REACTIVE_RANGE, R, constraint_val)
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(acos(PSY.get_powerfactor(PSY.get_tech(d))))
        constraint_val[name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, q_var[name, t] == p_var[name, t] * pf)
    end
    return
end

######################## output constraints without Time Series ############################
function _get_time_series(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{<:PSY.RenewableGen},
    model::Union{Nothing,DeviceModel},
    get_constraint_values::Function,
)
    initial_time = model_initial_time(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    parameters = model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)

    constraint_data = Vector{DeviceRange}()
    active_timeseries = Vector{DeviceTimeSeries}()
    reactive_timeseries = Vector{DeviceTimeSeries}()

    for device in devices
        bus_number = PSY.get_number(PSY.get_bus(device))
        name = PSY.get_name(device)
        tech = PSY.get_tech(device)
        pf = sin(acos(PSY.get_powerfactor(PSY.get_tech(device))))
        if use_forecast_data
            active_power = PSY.get_rating(tech)
            reactive_power = PSY.get_rating(tech) * pf
            forecast = PSY.get_forecast(
                PSY.Deterministic,
                device,
                initial_time,
                "get_rating",
                length(time_steps),
            )
            ts_vector = TS.values(PSY.get_data(forecast))
        else
            active_power = PSY.get_activepower(device)
            reactive_power = PSY.get_reactivepower(device)
            ts_vector = ones(time_steps[end])
        end

        range_data = DeviceRange(name, get_constraint_values(device))
        _device_services!(range_data, device, model)
        push!(constraint_data, range_data)
        push!(
            active_timeseries,
            DeviceTimeSeries(name, bus_number, active_power, ts_vector, range_data),
        )
        push!(
            reactive_timeseries,
            DeviceTimeSeries(name, bus_number, reactive_power * pf, ts_vector, range_data),
        )

    end
    return active_timeseries, reactive_timeseries, constraint_data
end

function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{R},
    model::DeviceModel{R,<:AbstractRenewableDispatchFormulation},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feed_forward::Union{Nothing,AbstractAffectFeedForward},
) where {R<:PSY.RenewableGen}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    ts_data_active, _, constraint_data = _get_time_series(
        psi_container,
        devices,
        model,
        x -> (min = 0.0, max = PSY.get_activepower(x)),
    )

    if !parameters && !use_forecast_data
        device_range(
            psi_container,
            constraint_data,
            constraint_name(ACTIVE_RANGE, R),
            variable_name(ACTIVE_POWER, R),
        )
        return
    end
    if parameters
        device_timeseries_param_ub(
            psi_container,
            ts_data_active,
            constraint_name(ACTIVE_RANGE, R),
            UpdateRef{R}(ACTIVE_POWER, "get_rating"),
            variable_name(ACTIVE_POWER, R),
        )
    else
        device_timeseries_ub(
            psi_container,
            ts_data_active,
            constraint_name(ACTIVE_RANGE, R),
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
) where {R<:PSY.RenewableGen}
    parameters = model_has_parameters(psi_container)
    ts_data_active, ts_data_reactive, _ = _get_time_series(
        psi_container,
        devices,
        DeviceModel(R, RenewableFullDispatch),
        x -> (min = 0.0, max = 0.0),
    )

    if parameters
        include_parameters(
            psi_container,
            ts_data_active,
            UpdateRef{R}(ACTIVE_POWER, "get_activepower"),
            :nodal_balance_active,
        )
        include_parameters(
            psi_container,
            ts_data_reactive,
            UpdateRef{R}(REACTIVE_POWER, "get_reactivepower"),
            :nodal_balance_reactive,
        )
        return
    end
    for t in model_time_steps(psi_container)
        for device in ts_data_active
            _add_to_expression!(
                psi_container.expressions[:nodal_balance_active],
                device.bus_number,
                t,
                device.multiplier * device.timeseries[t],
            )
        end
        for device in ts_data_reactive
            _add_to_expression!(
                psi_container.expressions[:nodal_balance_reactive],
                device.bus_number,
                t,
                device.multiplier * device.timeseries[t],
            )
        end
    end
    return
end

function nodal_expression!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{R},
    system_formulation::Type{<:PM.AbstractActivePowerModel},
) where {R<:PSY.RenewableGen}
    parameters = model_has_parameters(psi_container)
    ts_data_active, ts_data_reactive, _ = _get_time_series(
        psi_container,
        devices,
        DeviceModel(R, RenewableFullDispatch),
        x -> (min = 0.0, max = 0.0),
    )

    if parameters
        include_parameters(
            psi_container,
            ts_data_active,
            UpdateRef{R}(ACTIVE_POWER, "get_rating"),
            :nodal_balance_active,
        )
        return
    end
    for t in model_time_steps(psi_container)
        for device in ts_data_active
            _add_to_expression!(
                psi_container.expressions[:nodal_balance_active],
                device.bus_number,
                t,
                device.multiplier * device.timeseries[t],
            )
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
) where {D<:AbstractRenewableDispatchFormulation}
    add_to_cost(psi_container, devices, Symbol("P_RenewableDispatch"), :fixed, -1.0)
    return
end
