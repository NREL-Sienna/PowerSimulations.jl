abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end

abstract type AbstractRenewableDispatchFormulation <: AbstractRenewableFormulation end

struct RenewableFixed <: AbstractRenewableFormulation end

struct RenewableFullDispatch <: AbstractRenewableDispatchFormulation end

struct RenewableConstantPowerFactor <: AbstractRenewableDispatchFormulation end

########################### renewable generation variables #################################

function activepower_variables!(canonical::CanonicalModel,
                               devices::IS.FlattenIteratorWrapper{R}) where {R<:PSY.RenewableGen}

    add_variable(canonical,
                 devices,
                 Symbol("P_$(R)"),
                 false,
                 :nodal_balance_active;
                 lb_value = x -> 0.0,
                 ub_value = x -> PSY.get_rating(PSY.get_tech(x)))

    return

end

function reactivepower_variables!(canonical::CanonicalModel,
                                 devices::IS.FlattenIteratorWrapper{R}) where {R<:PSY.RenewableGen}

    add_variable(canonical,
                 devices,
                 Symbol("Q_$(R)"),
                 false,
                 :nodal_balance_reactive)

    return

end

####################################### Reactive Power Constraints #########################
function reactivepower_constraints!(canonical::CanonicalModel,
                                    devices::IS.FlattenIteratorWrapper{R},
                                    device_formulation::Type{RenewableFullDispatch},
                                    system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                         S<:PM.AbstractPowerModel}

    range_data = Vector{NamedMinMax}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        tech = PSY.get_tech(d)
        name = PSY.get_name(d)
        if isnothing(PSY.get_reactivepowerlimits(tech))
            limits = (min = 0.0, max = 0.0)
            range_data[ix] = (PSY.get_name(d), limits)
            @warn("Reactive Power Limits of $(name) are nothing. Q_$(name) is set to 0.0")
        else
            range_data[ix] = (name, PSY.get_reactivepowerlimits(tech))
        end
    end

    device_range(canonical,
                range_data,
                Symbol("reactiverange_$(R)"),
                Symbol("Q_$(R)"))

    return

end

function reactivepower_constraints!(canonical::CanonicalModel,
                                    devices::IS.FlattenIteratorWrapper{R},
                                    device_formulation::Type{RenewableConstantPowerFactor},
                                    system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                        S<:PM.AbstractPowerModel}

    names = (PSY.get_name(d) for d in devices)
    time_steps = model_time_steps(canonical_model)
    p_variable_name = Symbol("P_$(R)")
    q_variable_name = Symbol("Q_$(R)")
    constraint_name = Symbol("reactiverange_$(R)")
    canonical_model.constraints[constraint_name] = JuMPConstraintArray(undef, names, time_steps)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(acos(PSY.get_powerfactor(PSY.get_tech(d))))
        canonical_model.constraints[constraint_name][name, t] = JuMP.@constraint(canonical_model.JuMPmodel,
                                canonical_model.variables[q_variable_name][name, t] ==
                                canonical_model.variables[p_variable_name][name, t] * pf)
    end

    return

end


######################## output constraints without Time Series ############################
function _get_time_series(devices::IS.FlattenIteratorWrapper{R},
                          time_steps::UnitRange{Int64}) where {R<:PSY.RenewableGen}

    names = Vector{String}(undef, length(devices))
    series = Vector{Vector{Float64}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        names[ix] = PSY.get_name(d)
        tech = PSY.get_tech(d)
        series[ix] = fill(PSY.get_rating(tech), (time_steps[end]))
    end

    return names, series

    names = Vector{String}(undef, length(forecasts))
    ratings = Vector{Float64}(undef, length(forecasts))
    series = Vector{Vector{Float64}}(undef, length(forecasts))

    for (ix, f) in enumerate(forecasts)
        component = PSY.get_component(f)
        names[ix] = PSY.get_name(component)
        series[ix] = values(PSY.get_timeseries(f))
        ratings[ix] = PSY.get_tech(component).rating
    end

    return names, ratings, series

end


function activepower_constraints!(canonical::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{R},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                         D<:AbstractRenewableDispatchFormulation,
                                                         S<:PM.AbstractPowerModel}

    parameters = model_has_parameters(canonical_model)

    if parameters
        time_steps = model_time_steps(canonical_model)
        device_timeseries_param_ub(canonical,
                            _get_time_series(devices, time_steps),
                            Symbol("activerange_$(R)"),
                            UpdateRef{R}(Symbol("P_$(R)")),
                            Symbol("P_$(R)"))

    else
        range_data = [(PSY.get_name(d), (min = 0.0, max = PSY.get_rating(PSY.get_tech(d)))) for d in devices]
        device_range(canonical,
                    range_data,
                    Symbol("activerange_$(R)"),
                    Symbol("P_$(R)"))
    end

    return

end

########################## Addition of to the nodal balances ###############################
function nodal_expression!(canonical::CanonicalModel,
                           devices::IS.FlattenIteratorWrapper{G},
                           system_formulation::Type{S}) where {G<:PSY.Generator,
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
            ts_vector = TS.values(PSY.get_forecast(G,
                                                   device,
                                                   initial_time,
                                                   "rating"))
        else
            ts_vector = ones(time_steps[end])
        end
        ts_data_active[ix] = (name, bus_number, active_power, ts_vector)
        ts_data_reactive[ix] = (name, bus_number, active_power * pf, ts_vector)
    end

    if parameters
        include_parameters(canonical,
                           ts_data_active,
                           UpdateRef{G}(Symbol("P_$(G)")),
                           :nodal_balance_active)
        include_parameters(canonical,
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

function nodal_expression!(canonical::CanonicalModel,
                           devices::IS.FlattenIteratorWrapper{G},
                           system_formulation::Type{S}) where {G<:PSY.Generator,
                                                               S<:PM.AbstractActivePowerModel}

    initial_time = model_initial_time(canonical_model)
    forecast = model_uses_forecasts(canonical_model)
    parameters = model_has_parameters(canonical_model)
    time_steps = model_time_steps(canonical_model)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))

    for (ix, device) in enumerate(devices)
        bus_number = PSY.get_number(PSY.get_bus(device))
        tech = PSY.get_tech(device)
        active_power = forecast ? PSY.get_rating(tech) : PSY.get_activepower(device)
        PSY.get_forecast(G, device, initial_time, label)
        if forecast
            ts_vector = TS.values(PSY.get_forecast(G,
                                                   device,
                                                   initial_time,
                                                   "rating"))
        else
            ts_vector = ones(time_steps[end])
        end
        ts_data_active[ix] = (name, bus_number, active_power, ts_vector)
    end

    if parameters
        include_parameters(canonical,
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

##################################### renewable generation cost ############################
function cost_function(canonical::CanonicalModel,
                       devices::IS.FlattenIteratorWrapper{PSY.RenewableDispatch},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {D<:AbstractRenewableDispatchFormulation,
                                                           S<:PM.AbstractPowerModel}

    add_to_cost(canonical,
                devices,
                Symbol("P_RenewableDispatch"),
                :fixed,
                -1.0)

    return

end
