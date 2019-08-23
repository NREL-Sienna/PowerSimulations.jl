abstract type AbstractRenewableFormulation<:AbstractDeviceFormulation end

abstract type AbstractRenewableDispatchForm<:AbstractRenewableFormulation end

struct RenewableFixed<:AbstractRenewableFormulation end

struct RenewableFullDispatch<:AbstractRenewableDispatchForm end

struct RenewableConstantPowerFactor<:AbstractRenewableDispatchForm end

########################### renewable generation variables ############################################

function activepower_variables(canonical_model::CanonicalModel,
                               devices::PSY.FlattenIteratorWrapper{R}) where {R<:PSY.RenewableGen}

    add_variable(canonical_model,
                 devices,
                 Symbol("P_$(R)"),
                 false,
                 :nodal_balance_active;
                 lb_value = x -> 0.0,
                 ub_value = x -> PSY.get_tech(x) |> PSY.get_rating)

    return

end

function reactivepower_variables(canonical_model::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{R}) where {R<:PSY.RenewableGen}

    add_variable(canonical_model,
                 devices,
                 Symbol("Q_$(R)"),
                 false,
                 :nodal_balance_reactive)

    return

end

####################################### Reactive Power Constraints ######################################
function reactivepower_constraints(canonical_model::CanonicalModel,
                                    devices::PSY.FlattenIteratorWrapper{R},
                                    device_formulation::Type{RenewableFullDispatch},
                                    system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                         S<:PM.AbstractPowerFormulation}

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

    device_range(canonical_model,
                range_data,
                Symbol("reactiverange_$(R)"),
                Symbol("Q_$(R)"))

    return

end

function reactivepower_constraints(canonical_model::CanonicalModel,
                                    devices::PSY.FlattenIteratorWrapper{R},
                                    device_formulation::Type{RenewableConstantPowerFactor},
                                    system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                        S<:PM.AbstractPowerFormulation}

    names = (PSY.get_name(d) for d in devices)
    time_steps = model_time_steps(canonical_model)
    p_variable_name = Symbol("P_$(R)")
    q_variable_name = Symbol("Q_$(R)")
    constraint_name = Symbol("reactiverange_$(R)")
    canonical_model.constraints[constraint_name] = JuMPConstraintArray(undef, names, time_steps)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(acos(PSY.get_tech(d) |> PSY.get_powerfactor))
        canonical_model.constraints[constraint_name][name, t] = JuMP.@constraint(canonical_model.JuMPmodel,
                                canonical_model.variables[q_variable_name][name, t] ==
                                canonical_model.variables[p_variable_name][name, t] * pf)
    end

    return

end


######################## output constraints without Time Series ###################################
function _get_time_series(devices::PSY.FlattenIteratorWrapper{R},
                          time_steps::UnitRange{Int64}) where {R<:PSY.RenewableGen}

    names = Vector{String}(undef, length(devices))
    series = Vector{Vector{Float64}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        names[ix] = PSY.get_name(d)
        tech = PSY.get_tech(d)
        series[ix] = fill(PSY.get_rating(tech), (time_steps[end]))
    end

    return names, series

end

function activepower_constraints(canonical_model::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{R},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                         D<:AbstractRenewableDispatchForm,
                                                         S<:PM.AbstractPowerFormulation}

    parameters = model_has_parameters(canonical_model)

    if parameters
        time_steps = model_time_steps(canonical_model)
        device_timeseries_param_ub(canonical_model,
                            _get_time_series(devices, time_steps),
                            Symbol("activerange_$(R)"),
                            RefParam{R}(Symbol("P_$(R)")),
                            Symbol("P_$(R)"))

    else
        range_data = [(PSY.get_name(d), (min = 0.0, max = PSY.get_tech(d) |> PSY.get_rating)) for d in devices]
        device_range(canonical_model,
                    range_data,
                    Symbol("activerange_$(R)"),
                    Symbol("P_$(R)"))
    end

    return

end

######################### output constraints with Time Series ##############################################

function _get_time_series(forecasts::Vector{PSY.Deterministic{R}}) where {R<:PSY.RenewableGen}

    names = Vector{String}(undef, length(forecasts))
    ratings = Vector{Float64}(undef, length(forecasts))
    series = Vector{Vector{Float64}}(undef, length(forecasts))

    for (ix, f) in enumerate(forecasts)
        component = PSY.get_component(f)
        names[ix] = PSY.get_name(component)
        series[ix] = values(PSY.get_data(f))
        ratings[ix] = PSY.get_tech(component).rating
    end

    return names, ratings, series

end

function activepower_constraints(canonical_model::CanonicalModel,
                                 forecasts::Vector{PSY.Deterministic{R}},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                     D<:AbstractRenewableDispatchForm,
                                                                     S<:PM.AbstractPowerFormulation}

    if model_has_parameters(canonical_model)
        device_timeseries_param_ub(canonical_model,
                                   _get_time_series(forecasts),
                                   Symbol("activerange_$(R)"),
                                   RefParam{R}(Symbol("P_$(R)")),
                                   Symbol("P_$(R)"))
    else
        device_timeseries_ub(canonical_model,
                            _get_time_series(forecasts),
                            Symbol("activerange_$(R)"),
                            Symbol("P_$(R)"))
    end

    return

end

##################################### renewable generation cost ######################################
function cost_function(canonical_model::CanonicalModel,
                       devices::PSY.FlattenIteratorWrapper{PSY.RenewableDispatch},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {D<:AbstractRenewableDispatchForm,
                                                           S<:PM.AbstractPowerFormulation}

    add_to_cost(canonical_model,
                devices,
                Symbol("P_RenewableDispatch"),
                :fixed,
                -1.0)

    return

end
