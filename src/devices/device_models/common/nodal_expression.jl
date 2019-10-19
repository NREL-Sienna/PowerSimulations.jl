function nodal_expression(canonical_model::CanonicalModel,
                         devices,
                         system_formulation::Type{S}) where {S<:PM.AbstractPowerModel}

    if model_has_parameters(canonical_model)
        _nodal_expression_param(canonical_model, devices, system_formulation)
    else
        _nodal_expression_fixed(canonical_model, devices, system_formulation)
    end

    return

end

function _nodal_expression_param(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{G},
                                system_formulation::Type{S}) where {G<:PSY.Generator,
                                                                    S<:PM.AbstractPowerModel}

    forecast = model_uses_forecasts(canonical_model
    parameters = model_has_parameters(canonical_model)
    time_steps = model_time_steps(canonical_model)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))
    ts_data_reactive = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))

    for (ix, device) in enumerate(devices)
        bus_number = PSY.get_number(PSY.get_bus(device))
        tech = PSY.get_tech(device)
        pf = sin(acos(PSY.get_powerfactor(PSY.get_tech(device))))
        active_power = forecast ? PSY.get_rating(tech) : PSY.get_activepower(device)
        ts_vector = forecast ? TimeSeries.values(PSY.get_data(f)) : ones(time_steps[end])
        ts_data_active[ix] = (name, bus_number, active_power, ts_vector)
        ts_data_reactive[ix] = (name, bus_number, active_power * pf, ts_vector)
    end

    if parameters
        include_parameters(canonical_model,
                           ts_data_active,
                           UpdateRef{G}(Symbol("P_$(G)")),
                           :nodal_balance_active)
        include_parameters(canonical_model,
                           ts_data_reactive,
                           UpdateRef{G}(Symbol("Q_$(G)")),
                           :nodal_balance_reactive)
        return
    end

    for t in time_steps
        _add_to_expression!(canonical_model.expressions[:nodal_balance_active],
                            bus_number, t,
                            ts_data_active[t][3]*ts_data_active[t][4])
        _add_to_expression!(canonical_model.expressions[:nodal_balance_reactive],
                            bus_number, t,
                            ts_data_reactive[t][3]*ts_data_reactive[t][4])
    end

    return

end

function _nodal_expression_param(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{G},
                                system_formulation::Type{S}) where {G<:PSY.Generator,
                                                                    S<:PM.AbstractActivePowerModel}

    initial_time = model_initial_time(canonical_model)
    forecast = model_uses_forecasts(canonical_model
    parameters = model_has_parameters(canonical_model)
    time_steps = model_time_steps(canonical_model)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))
    ts_data_reactive = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))

    for (ix, device) in enumerate(devices)
        bus_number = PSY.get_number(PSY.get_bus(device))
        tech = PSY.get_tech(device)
        active_power = forecast ? PSY.get_rating(tech) : PSY.get_activepower(device)
        PSY.get_forecast(G, device, initial_time, label)
        ts_vector = forecast ? TimeSeries.values(PSY.get_data(f)) : ones(time_steps[end])
        ts_data_active[ix] = (name, bus_number, active_power, ts_vector)
    end

    if parameters
        include_parameters(canonical_model,
                           ts_data_active,
                           UpdateRef{G}(Symbol("P_$(G)")),
                           :nodal_balance_active)
        return
    end

    for t in time_steps
        _add_to_expression!(canonical_model.expressions[:nodal_balance_active],
                            bus_number,
                            t,
                            ts_data_active[t])
    end

    return


end

########################################## LOAD ############################################
function _nodal_expression_param(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{L},
                                system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                    S<:PM.AbstractPowerModel}

    time_steps = model_time_steps(canonical_model)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))
    ts_data_reactive = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        bus_number = PSY.get_number(PSY.get_bus(d))
        name = PSY.get_name(d)
        active_power = PSY.get_activepower(d)
        reactive_power = PSY.get_reactivepower(d)
        time_series_vector = ones(time_steps[end])
        ts_data_active[ix] = (name, bus_number, active_power, time_series_vector, -1.0)
        ts_data_reactive[ix] = (name, bus_number, reactive_power, time_series_vector, -1.0)
    end

    for (ix, f) in enumerate(forecasts)
        device = PSY.get_component(f)
        bus_number = PSY.get_number(PSY.get_bus(device))
        name = PSY.get_name(device)
        active_power = PSY.get_maxactivepower(device)
        reactive_power = PSY.get_maxreactivepower(device)
        time_series_vector = values(PSY.get_timeseries(f))
        ts_data_active[ix] = (name, bus_number, active_power, time_series_vector)
        ts_data_reactive[ix] = (name, bus_number, reactive_power, time_series_vector)
    end

    include_parameters(canonical_model,
                    ts_data_active,
                    UpdateRef{L}(Symbol("P_$(L)")),
                    :nodal_balance_active,
                    -1.0)
    include_parameters(canonical_model,
                    ts_data_reactive,
                    UpdateRef{L}(Symbol("Q_$(L)")),
                    :nodal_balance_reactive,
                    -1.0)

    time_steps = model_time_steps(canonical_model)

    for t in time_steps, d in devices
        bus_number = PSY.get_number(PSY.get_bus(d))
        active_power = PSY.get_activepower(d)
        reactive_power = PSY.get_reactivepower(d)
        _add_to_expression!(canonical_model.expressions[:nodal_balance_active],
                            bus_number,
                            t,
                            -1*active_power);
        _add_to_expression!(canonical_model.expressions[:nodal_balance_reactive],
                            bus_number,
                            t,
                            -1*reactive_power);
    end

    for f in forecasts
        device = PSY.get_component(f)
        bus_number = PSY.get_number(PSY.get_bus(device))
        active_power = PSY.get_maxactivepower(device)
        reactive_power = PSY.get_maxreactivepower(device)
        time_series_vector = values(PSY.get_timeseries(f))
        for t in time_steps
            bus_number = PSY.get_number(PSY.get_bus(device))
            _add_to_expression!(canonical_model.expressions[:nodal_balance_active],
                                bus_number,
                                t,
                                -1 * time_series_vector[t] * active_power)
            _add_to_expression!(canonical_model.expressions[:nodal_balance_reactive],
                                bus_number,
                                t,
                                -1 * time_series_vector[t] * reactive_power)
        end
    end

    return


end

function _nodal_expression_param(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{L},
                                system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                    S<:PM.AbstractActivePowerModel}

    time_steps = model_time_steps(canonical_model)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        bus_number = PSY.get_number(PSY.get_bus(d))
        name = PSY.get_name(d)
        active_power = PSY.get_activepower(d)
        time_series_vector = ones(time_steps[end])
        ts_data_active[ix] = (name, bus_number, active_power, time_series_vector, -1.0)
    end

    for (ix, f) in enumerate(forecasts)
        device = PSY.get_component(f)
        bus_number = PSY.get_number(PSY.get_bus(device))
        name = PSY.get_name(device)
        active_power = PSY.get_maxactivepower(device)
        time_series_vector = values(PSY.get_timeseries(f))
        ts_data_active[ix] = (name, bus_number, active_power, time_series_vector)
    end

    include_parameters(canonical_model,
                    ts_data_active,
                    UpdateRef{L}(Symbol("P_$(L)")),
                    :nodal_balance_active,
                    -1.0)

    time_steps = model_time_steps(canonical_model)

    for t in time_steps, d in devices
        bus_number = PSY.get_number(PSY.get_bus(d))
        active_power = PSY.get_activepower(d)
        _add_to_expression!(canonical_model.expressions[:nodal_balance_active],
                            bus_number,
                            t,
                            -1*active_power);
    end

    for f in forecasts
        device = PSY.get_component(f)
        bus_number = PSY.get_number(PSY.get_bus(device))
        active_power = PSY.get_maxactivepower(device)
        time_series_vector = values(PSY.get_timeseries(f))
        for t in time_steps
            bus_number = PSY.get_number(PSY.get_bus(device))
            _add_to_expression!(canonical_model.expressions[:nodal_balance_active],
                                bus_number,
                                t,
                                -1 * time_series_vector[t] * active_power)
        end
    end

    return

end
