abstract type AbstractLoadFormulation <: AbstractDeviceFormulation end

abstract type AbstractControllablePowerLoadFormulation <: AbstractLoadFormulation end

struct StaticPowerLoad <: AbstractLoadFormulation end

struct InterruptiblePowerLoad <: AbstractControllablePowerLoadFormulation end

struct DispatchablePowerLoad <: AbstractControllablePowerLoadFormulation end

########################### dispatchable load variables ####################################
function activepower_variables!(canonical_model::CanonicalModel,
                               devices::IS.FlattenIteratorWrapper{L}) where {L<:PSY.ElectricLoad}
    add_variable(canonical_model,
                 devices,
                 Symbol("P_$(L)"),
                 false,
                 :nodal_balance_active, -1.0;
                 ub_value = x -> PSY.get_maxactivepower(x),
                 lb_value = x -> 0.0)

    return

end


function reactivepower_variables!(canonical_model::CanonicalModel,
                                 devices::IS.FlattenIteratorWrapper{L}) where {L<:PSY.ElectricLoad}
    add_variable(canonical_model,
                 devices,
                 Symbol("Q_$(L)"),
                 false,
                 :nodal_balance_reactive, -1.0;
                 ub_value = x -> PSY.get_maxreactivepower(x),
                 lb_value = x -> 0.0)

    return

end

function commitment_variables!(canonical_model::CanonicalModel,
                              devices::IS.FlattenIteratorWrapper{L}) where {L<:PSY.ElectricLoad}

    add_variable(canonical_model,
                 devices,
                 Symbol("ON_$(L)"),
                 true)

    return

end

####################################### Reactive Power Constraints #########################
"""
Reactive Power Constraints on Loads Assume Constant PowerFactor
"""
function reactivepower_constraints!(canonical_model::CanonicalModel,
                                   devices::IS.FlattenIteratorWrapper{L},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                       D<:AbstractControllablePowerLoadFormulation,
                                                                       S<:PM.AbstractPowerModel}
    time_steps = model_time_steps(canonical_model)
    key = Symbol("reactive_$(L)")
    canonical_model.constraints[key] = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(atan((PSY.get_maxreactivepower(d)/PSY.get_maxactivepower(d))))
        canonical_model.constraints[key][PSY.get_name(d), t] = JuMP.@constraint(canonical_model.JuMPmodel,
                        canonical_model.variables[Symbol("Q_$(L)")][name, t] == canonical_model.variables[Symbol("P_$(L)")][name, t]*pf)
    end

    return

end


######################## output constraints without Time Series ############################
function _get_time_series(devices::IS.FlattenIteratorWrapper{T},
                          time_steps::UnitRange{Int64}) where {T<:PSY.ElectricLoad}

    names = Vector{String}(undef, length(devices))
    series = Vector{Vector{Float64}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        names[ix] = PSY.get_name(d)
        series[ix] = fill(PSY.get_maxactivepower(d), (time_steps[end]))
    end

    return names, series

    names = Vector{String}(undef, length(forecasts))
    ratings = Vector{Float64}(undef, length(forecasts))
    series = Vector{Vector{Float64}}(undef, length(forecasts))

    for (ix, f) in enumerate(forecasts)
        component = PSY.get_component(f)
        names[ix] = PSY.get_name(component)
        series[ix] = values(PSY.get_timeseries(f))
        ratings[ix] = PSY.get_maxactivepower(component)
    end

    return names, ratings, series

end

function activepower_constraints!(canonical_model::CanonicalModel,
                                 devices::IS.FlattenIteratorWrapper{L},
                                 device_formulation::Type{DispatchablePowerLoad},
                                 system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                     S<:PM.AbstractPowerModel}

    time_steps = model_time_steps(canonical_model)

    if model_has_parameters(canonical_model)
        device_timeseries_param_ub(canonical_model,
                                   _get_time_series(devices, time_steps),
                                   Symbol("active_$(L)"),
                                   UpdateRef{L}(Symbol("P_$(L)")),
                                   Symbol("P_$(L)"))
    else
        range_data = [(PSY.get_name(d), (min = 0.0, max = PSY.get_maxactivepower(d))) for d in devices]
        device_range(canonical_model,
                    range_data,
                    Symbol("activerange_$(L)"),
                    Symbol("P_$(L)")
                    )
    end


    if model_has_parameters(canonical_model)
        device_timeseries_param_ub(canonical_model,
                                   _get_time_series(devices),
                                   Symbol("active_$(L)"),
                                   UpdateRef{L}(Symbol("P_$(L)")),
                                   Symbol("P_$(L)"))
    else
        device_timeseries_ub(canonical_model,
                            _get_time_series(devices),
                            Symbol("active_$(L)"),
                            Symbol("P_$(L)"))
    end

    return

end

"""
This function works only if the the Param_L <= PSY.get_maxactivepower(g)
"""
function activepower_constraints!(canonical_model::CanonicalModel,
                                 devices::IS.FlattenIteratorWrapper{L},
                                 device_formulation::Type{InterruptiblePowerLoad},
                                 system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                          S<:PM.AbstractPowerModel}
    time_steps = model_time_steps(canonical_model)

    if model_has_parameters(canonical_model)
        device_timeseries_ub_bigM(canonical_model,
                                 _get_time_series(devices, time_steps),
                                 Symbol("active_$(L)"),
                                 Symbol("P_$(L)"),
                                 UpdateRef{L}(Symbol("P_$(L)")),
                                 Symbol("ON_$(L)"))
    else
        device_timeseries_ub_bin(canonical_model,
                                _get_time_series(devices, time_steps),
                                Symbol("active_$(L)"),
                                Symbol("P_$(L)"),
                                Symbol("ON_$(L)"))
    end



    if model_has_parameters(canonical_model)
        device_timeseries_ub_bigM(canonical_model,
                                 _get_time_series(devices),
                                 Symbol("active_$(L)"),
                                 Symbol("P_$(L)"),
                                 UpdateRef{L}(Symbol("P_$(L)")),
                                 Symbol("ON_$(L)"))
    else
        device_timeseries_ub_bin(canonical_model,
                                _get_time_series(devices),
                                Symbol("active_$(L)"),
                                Symbol("P_$(L)"),
                                Symbol("ON_$(L)"))
    end


    return

end

########################## Addition of to the nodal balances ###############################
function nodal_expression!(canonical_model::CanonicalModel,
                           devices::IS.FlattenIteratorWrapper{L},
                           system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                               S<:PM.AbstractPowerModel}

    initial_time = model_initial_time(canonical_model)
    forecast = model_uses_forecasts(canonical_model)
    parameters = model_has_parameters(canonical_model)
    time_steps = model_time_steps(canonical_model)
    device_total = length(devices)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, device_total)
    ts_data_reactive = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, device_total)

    for (ix, device) in enumerate(devices)
        bus_number = PSY.get_number(PSY.get_bus(device))
        tech = PSY.get_tech(device)
        pf = sin(acos(PSY.get_powerfactor(PSY.get_tech(device))))
        active_power = forecast ? PSY.get_rating(tech) : PSY.get_activepower(device)
        if forecast
            ts_vector = TS.values(PSY.get_forecast(L,
                                                   device,
                                                   initial_time,
                                                   "maxactivepower"))
        else
            ts_vector = ones(time_steps[end])
        end
        ts_data_active[ix] = (name, bus_number, active_power, ts_vector)
        ts_data_reactive[ix] = (name, bus_number, active_power * pf, ts_vector)
    end

    if parameters
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

function nodal_expression!(canonical_model::CanonicalModel,
                           devices::IS.FlattenIteratorWrapper{L},
                           system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                               S<:PM.AbstractActivePowerModel}

    initial_time = model_initial_time(canonical_model)
    forecast = model_uses_forecasts(canonical_model)
    parameters = model_has_parameters(canonical_model)
    time_steps = model_time_steps(canonical_model)
    device_total = length(devices)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, device_total)

    for (ix, device) in enumerate(devices)
        bus_number = PSY.get_number(PSY.get_bus(device))
        tech = PSY.get_tech(device)
        active_power = forecast ? PSY.get_rating(tech) : PSY.get_activepower(device)
        if forecast
            ts_vector = TS.values(PSY.get_forecast(L,
                                                   device,
                                                   initial_time,
                                                   "maxactivepower"))
        else
            ts_vector = ones(time_steps[end])
        end
        ts_data_active[ix] = (name, bus_number, active_power, ts_vector)
    end

    if parameters
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
    end

    for t in time_steps
        _add_to_expression!(canonical_model.expressions[:nodal_balance_active],
                            bus_number, t,
                            ts_data_active[t][3]*ts_data_active[t][4])
    end

    return
end

############################## FormulationControllable Load Cost ###########################
function cost_function(canonical_model::CanonicalModel,
                       devices::IS.FlattenIteratorWrapper{L},
                       device_formulation::Type{DispatchablePowerLoad},
                       system_formulation::Type{S}) where {L<:PSY.ControllableLoad,
                                                           S<:PM.AbstractPowerModel}

    add_to_cost(canonical_model,
                devices,
                Symbol("P_$(L)"),
                :variable,
                -1.0)

    return

end

function cost_function(canonical_model::CanonicalModel,
                       devices::IS.FlattenIteratorWrapper{L},
                       device_formulation::Type{InterruptiblePowerLoad},
                       system_formulation::Type{S}) where {L<:PSY.ControllableLoad,
                                                           S<:PM.AbstractPowerModel}

    add_to_cost(canonical_model,
                devices,
                Symbol("ON_$(L)"),
                :fixed,
                -1.0)

    return

end
