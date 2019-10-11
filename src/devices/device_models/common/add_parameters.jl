function include_parameters(canonical_model::CanonicalModel,
                            data::Matrix,
                            param_reference::UpdateRef,
                            axs...)

    _add_param_container!(canonical_model, param_reference, axs...)
    param = par(canonical_model, param_reference)

    Cidx = CartesianIndices(length.(axs))

    for idx in Cidx
        param.data[idx] = PJ.add_parameter(canonical_model.JuMPmodel, data[idx])
    end

    return

end

function include_parameters(canonical_model::CanonicalModel,
                            ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}},
                            param_reference::UpdateRef,
                            expression::Symbol,
                            multiplier::Float64 = 1.0)


    time_steps = model_time_steps(canonical_model)
    _add_param_container!(canonical_model, param_reference, (r[1] for r in ts_data), time_steps)
    param = par(canonical_model, param_reference)
    expr = exp(canonical_model, expression)

    for t in time_steps, r in ts_data
        param[r[1], t] = PJ.add_parameter(canonical_model.JuMPmodel, r[4][t]);
        _add_to_expression!(expr, r[2], t, param[r[1], t], r[3] * multiplier)
    end

    return

end

############################ injection expression with parameters ####################################

########################################### Devices ####################################################

function _nodal_expression_param(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{G},
                                system_formulation::Type{S}) where {G<:PSY.Generator,
                                                                    S<:PM.AbstractPowerModel}

    time_steps = model_time_steps(canonical_model)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))
    ts_data_reactive = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        bus_number = PSY.get_number(PSY.get_bus(d))
        tech = PSY.get_tech(d)
        name = PSY.get_name(d)
        pf = sin(acos(PSY.get_powerfactor(PSY.get_tech(d))))
        time_series_vector = ones(time_steps[end])
        ts_data_active[ix] = (name, bus_number, PSY.get_rating(tech), time_series_vector)
        ts_data_reactive[ix] = (name, bus_number, PSY.get_rating(tech) * pf, time_series_vector)
    end

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

function _nodal_expression_param(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{G},
                                system_formulation::Type{S}) where {G<:PSY.Generator,
                                                                    S<:PM.AbstractActivePowerModel}

    time_steps = model_time_steps(canonical_model)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        bus_number = PSY.get_number(PSY.get_bus(d))
        tech = PSY.get_tech(d)
        name = PSY.get_name(d)
        time_series_vector = ones(time_steps[end])
        ts_data_active[ix] = (name, bus_number, PSY.get_rating(tech), time_series_vector)
    end

    include_parameters(canonical_model,
                    ts_data_active,
                    UpdateRef{G}(Symbol("P_$(G)")),
                    :nodal_balance_active)

    return

end

############################################## Time Series ###################################
function _nodal_expression_param(canonical_model::CanonicalModel,
                                 forecasts::Vector{PSY.Deterministic{G}},
                                 system_formulation::Type{S}) where {G<:PSY.Generator,
                                                                     S<:PM.AbstractPowerModel}

    time_steps = model_time_steps(canonical_model)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(forecasts))
    ts_data_reactive = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(forecasts))

    for (ix, f) in enumerate(forecasts)
        device = PSY.get_component(f)
        bus_number = PSY.get_number(PSY.get_bus(device))
        tech = PSY.get_tech(device)
        name = PSY.get_name(device)
        pf = sin(acos(PSY.get_powerfactor(PSY.get_tech(device))))
        time_series_vector = values(PSY.get_timeseries(f))
        ts_data_active[ix] = (name, bus_number, PSY.get_rating(tech), time_series_vector)
        ts_data_reactive[ix] = (name, bus_number, PSY.get_rating(tech) * pf, time_series_vector)
    end

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

function _nodal_expression_param(canonical_model::CanonicalModel,
                                forecasts::Vector{PSY.Deterministic{G}},
                                system_formulation::Type{S}) where {G<:PSY.Generator,
                                                                    S<:PM.AbstractActivePowerModel}

    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(forecasts))

    for (ix, f) in enumerate(forecasts)
        device = PSY.get_component(f)
        bus_number = PSY.get_number(PSY.get_bus(device))
        tech = PSY.get_tech(device)
        name = PSY.get_name(device)
        time_series_vector = values(PSY.get_timeseries(f))
        ts_data_active[ix] = (name, bus_number, PSY.get_rating(tech), time_series_vector)
    end

    include_parameters(canonical_model,
                    ts_data_active,
                    UpdateRef{G}(Symbol("P_$(G)")),
                    :nodal_balance_active)

    return

end

############################ injection expression with fixed values ####################################
########################################### Devices ####################################################
function _nodal_expression_fixed(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{G},
                                system_formulation::Type{S}) where {G<:PSY.Generator,
                                                                     S<:PM.AbstractPowerModel}

    time_steps = model_time_steps(canonical_model)

    for t in time_steps, d in devices
        bus_number = PSY.get_number(PSY.get_bus(d))
        active_power = PSY.get_rating(PSY.get_tech(d))
        reactive_power = active_power * sin(acos(PSY.get_powerfactor(PSY.get_tech(d))))
        _add_to_expression!(canonical_model.expressions[:nodal_balance_active],
                            bus_number,
                            t,
                            active_power)
        _add_to_expression!(canonical_model.expressions[:nodal_balance_reactive],
                            bus_number,
                            t,
                            reactive_power)
    end

    return

end

function _nodal_expression_fixed(canonical_model::CanonicalModel,
                                    devices::IS.FlattenIteratorWrapper{G},
                                    system_formulation::Type{S}) where {G<:PSY.Generator,
                                                                         S<:PM.AbstractActivePowerModel}

    time_steps = model_time_steps(canonical_model)

    for t in time_steps, d in devices
        bus_number = PSY.get_number(PSY.get_bus(d))
        active_power = PSY.get_rating(PSY.get_tech(d))
        _add_to_expression!(canonical_model.expressions[:nodal_balance_active],
                            bus_number,
                            t,
                            active_power)
    end

    return

end

############################################## Time Series ###################################
function _nodal_expression_fixed(canonical_model::CanonicalModel,
                                forecasts::Vector{PSY.Deterministic{G}},
                                system_formulation::Type{S}) where {G<:PSY.Generator,
                                                                    S<:PM.AbstractPowerModel}

    time_steps = model_time_steps(canonical_model)

    for f in forecasts
        device = PSY.get_component(f)
        bus_number = PSY.get_number(PSY.get_bus(device))
        active_power = PSY.get_rating(PSY.get_tech(device))
        reactive_power = active_power * sin(acos(PSY.get_powerfactor(PSY.get_tech(device))))
        time_series_vector = values(PSY.get_timeseries(f))
        for t in time_steps
            _add_to_expression!(canonical_model.expressions[:nodal_balance_active],
                                bus_number,
                                t,
                                time_series_vector[t] * active_power)
            _add_to_expression!(canonical_model.expressions[:nodal_balance_reactive],
                                bus_number,
                                t,
                                time_series_vector[t] * reactive_power)
        end
    end

    return

end

function _nodal_expression_fixed(canonical_model::CanonicalModel,
                                forecasts::Vector{PSY.Deterministic{G}},
                                system_formulation::Type{S}) where {G<:PSY.Generator,
                                                                    S<:PM.AbstractActivePowerModel}

    time_steps = model_time_steps(canonical_model)

    for f in forecasts
        device = PSY.get_component(f)
        bus_number = PSY.get_number(PSY.get_bus(device))
        active_power = PSY.get_rating(PSY.get_tech(device))
        time_series_vector = values(PSY.get_timeseries(f))
        for t in time_steps
            _add_to_expression!(canonical_model.expressions[:nodal_balance_active],
                                bus_number,
                                t,
                                time_series_vector[t] * active_power)
        end
    end

    return

end
