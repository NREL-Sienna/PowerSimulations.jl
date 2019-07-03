abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end

abstract type AbstractRenewableDispatchForm <: AbstractRenewableFormulation end

struct RenewableFixed <: AbstractRenewableFormulation end

struct RenewableFullDispatch <: AbstractRenewableDispatchForm end

struct RenewableConstantPowerFactor <: AbstractRenewableDispatchForm end

########################### renewable generation variables ############################################

function activepower_variables(ps_m::CanonicalModel,
                               devices::PSY.FlattenIteratorWrapper{R}) where {R <: PSY.RenewableGen}

    add_variable(ps_m,
                 devices,
                 Symbol("P_$(R)"),
                 false,
                 :nodal_balance_active)

    return

end

function reactivepower_variables(ps_m::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{R}) where {R <: PSY.RenewableGen}

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
                                    system_formulation::Type{S}) where {R <: PSY.RenewableGen,
                                                                         S <: PM.AbstractPowerFormulation}

    range_data = Vector{NamedMinMax}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        if isnothing(PSY.get_tech(d) |> PSY.get_reactivepowerlimits)
            limits = (min = 0.0, max = 0.0)
            range_data[ix] = (PSY.get_name(d), limits)
            @warn("Reactive Power Limits of $(PSY.get_name) are nothing. Q_$(PSY.get_name(d)) is set to 0.0")
        else
            range_data[ix] = (PSY.get_name(d), PSY.get_tech(d) |> PSY.get_reactivepowerlimits)
        end
    end

    device_range(ps_m,
                range_data,
                Symbol("reactive_range_$(R)"),
                Symbol("Q_$(R)"))

    return

end

function reactivepower_constraints(ps_m::CanonicalModel,
                                    devices::PSY.FlattenIteratorWrapper{R},
                                    device_formulation::Type{RenewableConstantPowerFactor},
                                    system_formulation::Type{S}) where {R <: PSY.RenewableGen,
                                                                         S <: PM.AbstractPowerFormulation}

    names = (PSY.get_name(d) for d in devices)
    time_steps = model_time_steps(ps_m)
    p_variable_name = Symbol("P_$(R)")
    q_variable_name = Symbol("Q_$(R)")
    constraint_name = Symbol("reactive_range_$(R)")
    ps_m.constraints[constraint_name] = JuMPConstraintArray(undef, names, time_steps)

    for t in time_steps, d in devices
        ps_m.constraints[constraint_name][PSY.get_name(d), t] = JuMP.@constraint(ps_m.JuMPmodel,
                                ps_m.variables[q_variable_name][PSY.get_name(d), t] ==
                                ps_m.variables[p_variable_name][PSY.get_name(d), t]*sin(acos(PSY.get_tech(d) |> PSY.get_powerfactor)))
    end

    return

end


######################## output constraints without Time Series ###################################
function _get_time_series(devices::PSY.FlattenIteratorWrapper{R},
                          time_steps::UnitRange{Int64}) where {R <: PSY.RenewableGen}

    names = Vector{String}(undef, length(devices))
    series = Vector{Vector{Float64}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        names[ix] = PSY.get_name(d)
        series[ix] = fill(PSY.get_tech(d) |> PSY.get_rating, (time_steps[end]))
    end

    return names, series

end

function activepower_constraints(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{R},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {R <: PSY.RenewableGen,
                                                         D <: AbstractRenewableDispatchForm,
                                                         S <: PM.AbstractPowerFormulation}

    parameters = model_has_parameters(ps_m)

    if parameters
        time_steps = model_time_steps(ps_m)
        device_timeseries_param_ub(ps_m,
                            _get_time_series(devices, time_steps),
                            Symbol("active_ub_$(R)"),
                            Symbol("Param_$(R)"),
                            Symbol("P_$(R)"))

    else
        range_data = [(PSY.get_name(d), (min = 0.0, max = PSY.get_tech(d) |> PSY.get_rating)) for d in devices]
        device_range(ps_m,
                    range_data,
                    Symbol("active_range_$(R)"),
                    Symbol("P_$(R)"))
    end

    return

end

######################### output constraints with Time Series ##############################################

function _get_time_series(forecasts::PSY.FlattenIteratorWrapper{PSY.Deterministic{R}}) where {R <: PSY.RenewableGen}

    names = Vector{String}(undef, length(forecasts))
    series = Vector{Vector{Float64}}(undef, length(forecasts))

    for (ix,f) in enumerate(forecasts)
        names[ix] = PSY.get_component(f) |> PSY.get_name
        series[ix] = values(PSY.get_data(f)) * (PSY.get_component(f) |> PSY.get_tech |> PSY.get_rating)
    end

    return names, series

end

function activepower_constraints(ps_m::CanonicalModel,
                                 forecasts::PSY.FlattenIteratorWrapper{PSY.Deterministic{R}},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {R <: PSY.RenewableGen,
                                                                     D <: AbstractRenewableDispatchForm,
                                                                     S <: PM.AbstractPowerFormulation}

    parameters = model_has_parameters(ps_m)

    if parameters
        device_timeseries_param_ub(ps_m,
                                   _get_time_series(forecasts),
                                   Symbol("renewable_active_ub_$(R)"),
                                   Symbol("Param_P_$(R)"),
                                   Symbol("P_$(R)"))
    else
        device_timeseries_ub(ps_m,
                            _get_time_series(forecasts),
                            Symbol("renewable_active_ub_$(R)"),
                            Symbol("P_$(R)"))
    end

    return

end

############################ injection expression with parameters ####################################

########################################### Devices ####################################################

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{R},
                                system_formulation::Type{S}) where {R <: PSY.RenewableGen,
                                                                    S <: PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)
    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))
    ts_data_reactive = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        time_series_vector = fill(PSY.get_tech(d) |> PSY.get_rating, (time_steps[end]))
        ts_data_active[ix] = (PSY.get_name(d), PSY.get_bus(d) |> PSY.get_number, time_series_vector)
        ts_data_reactive[ix] = (PSY.get_name(d), PSY.get_bus(d) |> PSY.get_number, time_series_vector * sin(acos(PSY.get_tech(d) |> PSY.get_powerfactor)))
    end

    include_parameters(ps_m,
                    ts_data_active,
                    Symbol("Param_P_$(R)"),
                    :nodal_balance_active)
    include_parameters(ps_m,
                    ts_data_reactive,
                    Symbol("Param_Q_$(R)"),
                    :nodal_balance_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{R},
                                system_formulation::Type{S}) where {R <: PSY.RenewableGen,
                                                                    S <: PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)
    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        time_series_vector = fill(PSY.get_tech(d) |> PSY.get_rating, (time_steps[end]))
        ts_data_active[ix] = (PSY.get_name(d), PSY.get_bus(d) |> PSY.get_number, time_series_vector)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    Symbol("P_$(R)"),
                    :nodal_balance_active)

    return

end

############################################## Time Series ###################################
function _nodal_expression_param(ps_m::CanonicalModel,
                                 forecasts::PSY.FlattenIteratorWrapper{PSY.Deterministic{R}},
                                 system_formulation::Type{S}) where {R <: PSY.RenewableGen,
                                                                     S <: PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)
    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(forecasts))
    ts_data_reactive = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(forecasts))

    for (ix,f) in enumerate(forecasts)
        device = PSY.get_component(f)
        time_series_vector = values(PSY.get_data(f))*(PSY.get_tech(device) |> PSY.get_rating)
        ts_data_active[ix] = (PSY.get_name(device), PSY.get_bus(device) |> PSY.get_number, time_series_vector)
        ts_data_reactive[ix] = (PSY.get_name(device), 
                                PSY.get_bus(device) |> PSY.get_number, 
                                time_series_vector * sin(acos(PSY.get_tech(device) |> PSY.get_powerfactor)))
    end

    include_parameters(ps_m,
                    ts_data_active,
                    Symbol("Param_P_$(R)"),
                    :nodal_balance_active)
    include_parameters(ps_m,
                    ts_data_reactive,
                    Symbol("Param_Q_$(R)"),
                    :nodal_balance_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                forecasts::PSY.FlattenIteratorWrapper{PSY.Deterministic{R}},
                                system_formulation::Type{S}) where {R <: PSY.RenewableGen,
                                                                    S <: PM.AbstractActivePowerFormulation}

    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(forecasts))

    for (ix,f) in enumerate(forecasts)
        device = PSY.get_component(f)
        time_series_vector = values(PSY.get_data(f)) * (PSY.get_tech(device) |> PSY.get_rating)
        ts_data_active[ix] = (PSY.get_name(device), 
                              PSY.get_bus(device) |> PSY.get_number, 
                              time_series_vector)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    Symbol("Param_P_$(R)"),
                    :nodal_balance_active)

    return

end

############################ injection expression with fixed values ####################################
########################################### Devices ####################################################
function _nodal_expression_fixed(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{R},
                                system_formulation::Type{S}) where {R <: PSY.RenewableGen,
                                                                     S <: PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)

    for t in time_steps, d in devices
        _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                            PSY.get_bus(d) |> PSY.get_number,
                            t,
                            PSY.get_tech(d) |> PSY.get_rating)
        _add_to_expression!(ps_m.expressions[:nodal_balance_reactive],
                            PSY.get_bus(d) |> PSY.get_number,
                            t,
                            (PSY.get_tech(d) |> PSY.get_rating) * sin(acos(PSY.get_tech(d) |> PSY.get_powerfactor)))
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                    devices::PSY.FlattenIteratorWrapper{R},
                                    system_formulation::Type{S}) where {R <: PSY.RenewableGen,
                                                                         S <: PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)

    for t in time_steps, d in devices
        _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                            PSY.get_bus(d) |> PSY.get_number,
                            t,
                            PSY.get_tech(d) |> PSY.get_rating)
    end

    return

end


############################################## Time Series ###################################
function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::PSY.FlattenIteratorWrapper{PSY.Deterministic{R}},
                                system_formulation::Type{S}) where {R <: PSY.RenewableGen,
                                                                    S <: PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)

    for f in forecasts
        time_series_vector = values(PSY.get_data(f)) * (PSY.get_component(f) |> PSY.get_tech |> PSY.get_rating)
        device = PSY.get_component(f)
        for t in time_steps
            _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                                PSY.get_bus(device) |> PSY.get_number,
                                t,
                                time_series_vector[t])
            _add_to_expression!(ps_m.expressions[:nodal_balance_reactive],
                                PSY.get_bus(device) |> PSY.get_number,
                                t,
                                time_series_vector[t] * sin(acos(PSY.get_tech(device) |> PSY.get_powerfactor)))
        end
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::PSY.FlattenIteratorWrapper{PSY.Deterministic{R}},
                                system_formulation::Type{S}) where {R <: PSY.RenewableGen,
                                                                    S <: PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)

    for f in forecasts
        time_series_vector = values(PSY.get_data(f)) * (PSY.get_component(f) |> PSY.get_tech |> PSY.get_rating)
        device = PSY.get_component(f)
        for t in time_steps
            _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                                PSY.get_bus(device) |> PSY.get_number,
                                t,
                                time_series_vector[t])
        end
    end

    return

end

##################################### renewable generation cost ######################################
function cost_function(ps_m::CanonicalModel,
                       devices::PSY.FlattenIteratorWrapper{PSY.RenewableDispatch},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {D <: AbstractRenewableDispatchForm,
                                                           S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m,
                devices,
                Symbol("P_RenewableDispatch"),
                :curtailpenalty,
                -1.0)

    return

end
