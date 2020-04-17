function _get_time_series(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{<:PSY.RenewableGen},
    model::Union{Nothing, DeviceModel},
    get_constraint_values::Function,
)
    initial_time = model_initial_time(psi_container)
    @debug initial_time
    parameters = model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)

    constraint_data = Vector{DeviceRange}()
    active_timeseries = Vector{DeviceTimeSeries}()
    reactive_timeseries = Vector{DeviceTimeSeries}()

    for device in devices
        bus_number = PSY.get_number(PSY.get_bus(device))
        name = PSY.get_name(device)
        pf = sin(acos(PSY.get_powerfactor(device)))

        if use_forecast_data
            active_power = PSY.get_rating(device)
            reactive_power = PSY.get_rating(device) * pf
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
            DeviceTimeSeries(name, bus_number, reactive_power, ts_vector, range_data),
        )

    end
    return active_timeseries, reactive_timeseries, constraint_data
end
