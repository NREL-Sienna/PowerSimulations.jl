abstract type AbstractRenewableFormulation<:AbstractDeviceFormulation end

abstract type AbstractRenewableDispatchForm<:AbstractRenewableFormulation end

struct RenewableFixed<:AbstractRenewableFormulation end

struct RenewableFullDispatch<:AbstractRenewableDispatchForm end

struct RenewableConstantPowerFactor<:AbstractRenewableDispatchForm end

########################### renewable generation variables ############################################

function activepower_variables(ps_m::CanonicalModel,
                               devices::PSY.FlattenIteratorWrapper{R}) where {R<:PSY.RenewableGen}

    add_variable(ps_m,
                 devices,
                 Symbol("P_$(R)"),
                 false,
                 :nodal_balance_active;
                 lb = x -> 0.0)

    return

end

function reactivepower_variables(ps_m::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{R}) where {R<:PSY.RenewableGen}

    add_variable(ps_m,
                 devices,
                 Symbol("Q_$(R)"),
                 false,
                 :nodal_balance_reactive)

    return

end

####################################### Reactive Power Constraints ######################################
function reactivepower_constraints(ps_m::CanonicalModel,
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

    device_range(ps_m,
                range_data,
                Symbol("reactiverange_$(R)"),
                Symbol("Q_$(R)"))

    return

end

function reactivepower_constraints(ps_m::CanonicalModel,
                                    devices::PSY.FlattenIteratorWrapper{R},
                                    device_formulation::Type{RenewableConstantPowerFactor},
                                    system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                        S<:PM.AbstractPowerFormulation}

    names = (PSY.get_name(d) for d in devices)
    time_steps = model_time_steps(ps_m)
    p_variable_name = Symbol("P_$(R)")
    q_variable_name = Symbol("Q_$(R)")
    constraint_name = Symbol("reactiverange_$(R)")
    ps_m.constraints[constraint_name] = JuMPConstraintArray(undef, names, time_steps)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(acos(PSY.get_tech(d) |> PSY.get_powerfactor))
        ps_m.constraints[constraint_name][name, t] = JuMP.@constraint(ps_m.JuMPmodel,
                                ps_m.variables[q_variable_name][name, t] ==
                                ps_m.variables[p_variable_name][name, t] * pf)
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

function activepower_constraints(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{R},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                         D<:AbstractRenewableDispatchForm,
                                                         S<:PM.AbstractPowerFormulation}

    parameters = model_has_parameters(ps_m)

    if parameters
        time_steps = model_time_steps(ps_m)
        device_timeseries_param_ub(ps_m,
                            _get_time_series(devices, time_steps),
                            Symbol("activerange_$(R)"),
                            RefParam{R}(Symbol("P_$(R)")),
                            Symbol("P_$(R)"))

    else
        range_data = [(PSY.get_name(d), (min = 0.0, max = PSY.get_tech(d) |> PSY.get_rating)) for d in devices]
        device_range(ps_m,
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

function activepower_constraints(ps_m::CanonicalModel,
                                 forecasts::Vector{PSY.Deterministic{R}},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                     D<:AbstractRenewableDispatchForm,
                                                                     S<:PM.AbstractPowerFormulation}

    if model_has_parameters(ps_m)
        device_timeseries_param_ub(ps_m,
                                   _get_time_series(forecasts),
                                   Symbol("activerange_$(R)"),
                                   RefParam{R}(Symbol("P_$(R)")),
                                   Symbol("P_$(R)"))
    else
        device_timeseries_ub(ps_m,
                            _get_time_series(forecasts),
                            Symbol("activerange_$(R)"),
                            Symbol("P_$(R)"))
    end

    return

end
#=
function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Vector{PSY.Deterministic{R}},
                                 device_formulation::Type{RenewableCommitment},
                                 system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                     S<:PM.AbstractPowerFormulation}

    if model_has_parameters(ps_m)
        device_timeseries_ub_bigM(ps_m,
                                 _get_time_series(devices),
                                 Symbol("active_$(R)"),
                                 Symbol("P_$(R)"),
                                 RefParam{R}(Symbol("P_$(R)")),
                                 Symbol("ON_$(R)"))
    else
        device_timeseries_ub_bin(ps_m,
                                _get_time_series(devices),
                                Symbol("active_$(R)"),
                                Symbol("P_$(R)"),
                                Symbol("ON_$(R)"))
    end

    return

end
=#
############################ injection expression with parameters ####################################

########################################### Devices ####################################################

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{R},
                                system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                    S<:PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))
    ts_data_reactive = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        bus_number = PSY.get_bus(d) |> PSY.get_number
        tech = PSY.get_tech(d)
        name = PSY.get_name(d)
        pf = sin(acos(PSY.get_tech(d) |> PSY.get_powerfactor))
        time_series_vector = ones(time_steps[end])
        ts_data_active[ix] = (name, bus_number, PSY.get_rating(tech), time_series_vector)
        ts_data_reactive[ix] = (name, bus_number, PSY.get_rating(tech) * pf, time_series_vector)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    RefParam{R}(Symbol("P_$(R)")),
                    :nodal_balance_active)
    include_parameters(ps_m,
                    ts_data_reactive,
                    RefParam{R}(Symbol("Q_$(R)")),
                    :nodal_balance_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{R},
                                system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                    S<:PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        bus_number = PSY.get_bus(d) |> PSY.get_number
        tech = PSY.get_tech(d)
        name = PSY.get_name(d)
        time_series_vector = ones(time_steps[end])
        ts_data_active[ix] = (name, bus_number, PSY.get_rating(tech), time_series_vector)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    RefParam{R}(Symbol("P_$(R)")),
                    :nodal_balance_active)

    return

end

############################################## Time Series ###################################
function _nodal_expression_param(ps_m::CanonicalModel,
                                 forecasts::Vector{PSY.Deterministic{R}},
                                 system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                     S<:PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(forecasts))
    ts_data_reactive = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(forecasts))

    for (ix, f) in enumerate(forecasts)
        device = PSY.get_component(f)
        bus_number = PSY.get_bus(device) |> PSY.get_number
        tech = PSY.get_tech(device)
        name = PSY.get_name(device)
        pf = sin(acos(PSY.get_tech(device) |> PSY.get_powerfactor))
        time_series_vector = values(PSY.get_data(f))
        ts_data_active[ix] = (name, bus_number, PSY.get_rating(tech), time_series_vector)
        ts_data_reactive[ix] = (name, bus_number, PSY.get_rating(tech) * pf, time_series_vector)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    RefParam{R}(Symbol("P_$(R)")),
                    :nodal_balance_active)
    include_parameters(ps_m,
                    ts_data_reactive,
                    RefParam{R}(Symbol("Q_$(R)")),
                    :nodal_balance_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                forecasts::Vector{PSY.Deterministic{R}},
                                system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                    S<:PM.AbstractActivePowerFormulation}

    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(forecasts))

    for (ix, f) in enumerate(forecasts)
        device = PSY.get_component(f)
        device = PSY.get_component(f)
        bus_number = PSY.get_bus(device) |> PSY.get_number
        tech = PSY.get_tech(device)
        name = PSY.get_name(device)
        time_series_vector = values(PSY.get_data(f))
        ts_data_active[ix] = (name, bus_number, PSY.get_rating(tech), time_series_vector)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    RefParam{R}(Symbol("P_$(R)")),
                    :nodal_balance_active)

    return

end

############################ injection expression with fixed values ####################################
########################################### Devices ####################################################
function _nodal_expression_fixed(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{R},
                                system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                     S<:PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)

    for t in time_steps, d in devices
        bus_number = PSY.get_bus(d) |> PSY.get_number
        active_power = PSY.get_tech(d) |> PSY.get_rating
        reactive_power = active_power * sin(acos(PSY.get_tech(d) |> PSY.get_powerfactor))
        _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                            bus_number,
                            t,
                            active_power)
        _add_to_expression!(ps_m.expressions[:nodal_balance_reactive],
                            bus_number,
                            t,
                            reactive_power)
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                    devices::PSY.FlattenIteratorWrapper{R},
                                    system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                         S<:PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)

    for t in time_steps, d in devices
        bus_number = PSY.get_bus(d) |> PSY.get_number
        active_power = PSY.get_tech(d) |> PSY.get_rating
        _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                            bus_number,
                            t,
                            active_power)
    end

    return

end


############################################## Time Series ###################################
function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::Vector{PSY.Deterministic{R}},
                                system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                    S<:PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)

    for f in forecasts
        device = PSY.get_component(f)
        bus_number = PSY.get_bus(device) |> PSY.get_number
        active_power = PSY.get_tech(device) |> PSY.get_rating
        reactive_power = active_power * sin(acos(PSY.get_tech(device) |> PSY.get_powerfactor))
        time_series_vector = values(PSY.get_data(f))
        for t in time_steps
            _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                                bus_number,
                                t,
                                time_series_vector[t] * active_power)
            _add_to_expression!(ps_m.expressions[:nodal_balance_reactive],
                                bus_number,
                                t,
                                time_series_vector[t] * reactive_power)
        end
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::Vector{PSY.Deterministic{R}},
                                system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                    S<:PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)

    for f in forecasts
        device = PSY.get_component(f)
        bus_number = PSY.get_bus(device) |> PSY.get_number
        active_power = PSY.get_tech(device) |> PSY.get_rating
        time_series_vector = values(PSY.get_data(f))
        for t in time_steps
            _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                                bus_number,
                                t,
                                time_series_vector[t] * active_power)
        end
    end

    return

end

##################################### renewable generation cost ######################################
function cost_function(ps_m::CanonicalModel,
                       devices::PSY.FlattenIteratorWrapper{PSY.RenewableDispatch},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {D<:AbstractRenewableDispatchForm,
                                                           S<:PM.AbstractPowerFormulation}

    add_to_cost(ps_m,
                devices,
                Symbol("P_RenewableDispatch"),
                :fixed,
                -1.0)

    return

end
