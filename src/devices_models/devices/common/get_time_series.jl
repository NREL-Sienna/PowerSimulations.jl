function get_time_series(
    psi_container::PSIContainer,
    device::PSY.Device,
    forecast_label::String,
)
    initial_time = model_initial_time(psi_container)
    @debug initial_time
    use_forecast_data = model_uses_forecasts(psi_container)
    time_steps = model_time_steps(psi_container)
    @debug "device $(PSY.get_name(device)) $(PSY.has_forecasts(device)) forecast"
    if use_forecast_data & PSY.has_forecasts(device)
        forecast = PSY.get_forecast(
            PSY.Deterministic,
            device,
            initial_time,
            forecast_label,
            length(time_steps),
        )
        return ts_vector = TS.values(PSY.get_data(forecast))
    else
        return ts_vector = ones(time_steps[end])
    end
end
#=
function get_time_series(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{<:PSY.ElectricLoad},
    model::DeviceModel,
    get_constraint_values::Function,
)
    initial_time = model_initial_time(psi_container)
    @debug initial_time
    use_forecast_data = model_uses_forecasts(psi_container)
    time_steps = model_time_steps(psi_container)
    device_total = length(devices)

    constraint_data = Vector{DeviceRange}()
    ts_data_active = Vector{DeviceTimeSeries}()
    ts_data_reactive = Vector{DeviceTimeSeries}()

    for device in devices
        bus_number = PSY.get_number(PSY.get_bus(device))
        name = PSY.get_name(device)

        if use_forecast_data
            active_power = PSY.get_maxactivepower(device)
            reactive_power = PSY.get_maxreactivepower(device)
            forecast = PSY.get_forecast(
                PSY.Deterministic,
                device,
                initial_time,
                "get_maxactivepower",
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
            ts_data_active,
            DeviceTimeSeries(name, bus_number, active_power, ts_vector, range_data),
        )
        push!(
            ts_data_reactive,
            DeviceTimeSeries(name, bus_number, reactive_power, ts_vector, range_data),
        )

    end

    return ts_data_active, ts_data_reactive, constraint_data

end

function get_time_series(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{<:PSY.HydroGen},
    model::DeviceModel,
    get_constraint_values::Function,
)
    initial_time = model_initial_time(psi_container)
    @debug initial_time
    use_forecast_data = model_uses_forecasts(psi_container)
    parameters = model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)

    constraint_data = Vector{DeviceRange}()
    active_timeseries = Vector{DeviceTimeSeries}()

    for device in devices
        bus_number = PSY.get_number(PSY.get_bus(device))
        name = PSY.get_name(device)
        if use_forecast_data
            active_power = PSY.get_rating(device)
            ts_vector = TS.values(PSY.get_data(PSY.get_forecast(
                PSY.Deterministic,
                device,
                initial_time,
                "get_rating",
                length(time_steps),
            )))
        else
            active_power = PSY.get_activepower(device)
            ts_vector = ones(time_steps[end])
        end
        range_data = DeviceRange(name, get_constraint_values(device))
        _device_services!(range_data, device, model)
        push!(constraint_data, range_data)
        push!(
            active_timeseries,
            DeviceTimeSeries(name, bus_number, active_power, ts_vector, range_data),
        )
    end
    return active_timeseries, constraint_data
end
=#
