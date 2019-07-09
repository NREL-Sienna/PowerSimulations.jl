abstract type AbstractLoadFormulation <: AbstractDeviceFormulation end

abstract type AbstractControllablePowerLoadForm <: AbstractLoadFormulation end

struct StaticPowerLoad <: AbstractLoadFormulation end

struct InterruptiblePowerLoad <: AbstractControllablePowerLoadForm end

struct DispatchablePowerLoad <: AbstractControllablePowerLoadForm end

########################### dispatchable load variables ############################################

function activepower_variables(ps_m::CanonicalModel,
                               devices::PSY.FlattenIteratorWrapper{L}) where {L <: PSY.ElectricLoad}
    add_variable(ps_m,
                 devices,
                 Symbol("P_$(L)"),
                 false,
                 :nodal_balance_active, -1.0)

    return

end


function reactivepower_variables(ps_m::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{L}) where {L <: PSY.ElectricLoad}
    add_variable(ps_m,
                 devices,
                 Symbol("Q_$(L)"),
                 false,
                 :nodal_balance_reactive, -1.0)

    return

end

function commitment_variables(ps_m::CanonicalModel,
                              devices::PSY.FlattenIteratorWrapper{L}) where {L <: PSY.ElectricLoad}

    add_variable(ps_m,
                 devices,
                 Symbol("ON_$(L)"),
                 true)

    return

end

####################################### Reactive Power Constraints ######################################
"""
Reactive Power Constraints on Loads Assume Constant PowerFactor
"""
function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::PSY.FlattenIteratorWrapper{L},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S}) where {L <: PSY.ElectricLoad,
                                                                       D <: AbstractControllablePowerLoadForm,
                                                                       S <: PM.AbstractPowerFormulation}
    time_steps = model_time_steps(ps_m)
    key = Symbol("reactive_$(L)")
    ps_m.constraints[key] = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)

    for t in time_steps, d in devices
            ps_m.constraints[key][PSY.get_name(d), t] = JuMP.@constraint(ps_m.JuMPmodel,
                                                             ps_m.variables[Symbol("Q_$(L)")][PSY.get_name(d), t] ==
                                                             ps_m.variables[Symbol("P_$(L)")][PSY.get_name(d), t] * sin(atan((PSY.get_maxreactivepower(d)/PSY.get_maxactivepower(d)))))
    end

    return

end


######################## output constraints without Time Series ###################################
function _get_time_series(devices::PSY.FlattenIteratorWrapper{T},
                          time_steps::UnitRange{Int64}) where {T <: PSY.ElectricLoad}

    names = Vector{String}(undef, length(devices))
    series = Vector{Vector{Float64}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        names[ix] = PSY.get_name(d)
        series[ix] = fill(PSY.get_maxactivepower(d), (time_steps[end]))
    end

    return names, series

end

function activepower_constraints(ps_m::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{L},
                                 device_formulation::Type{DispatchablePowerLoad},
                                 system_formulation::Type{S}) where {L <: PSY.ElectricLoad,
                                                                     S <: PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)

    if model_has_parameters(ps_m)
        device_timeseries_param_ub(ps_m,
                                   _get_time_series(devices, time_steps),
                                   Symbol("active_ub_$(L)"),
                                   Symbol("Param_$(L))"),
                                   Symbol("P_$(L)"))
    else
        range_data = [(PSY.get_name(d), (min = 0.0, max = PSY.get_maxactivepower(d))) for d in devices]
        device_range(ps_m,
                    range_data,
                    Symbol("active_range_$(L)"),
                    Symbol("P_$(L)")
                    )
    end

    return

end

"""
This function works only if the the Param_L <= PSY.get_maxactivepower(g)
"""
function activepower_constraints(ps_m::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{L},
                                 device_formulation::Type{InterruptiblePowerLoad},
                                 system_formulation::Type{S}) where {L <: PSY.ElectricLoad,
                                                          S <: PM.AbstractPowerFormulation}
    time_steps = model_time_steps(ps_m)

    if model_has_parameters(ps_m)
        device_timeseries_ub_bigM(ps_m,
                                 _get_time_series(devices, time_steps),
                                 Symbol("active_ub_$(L)"),
                                 Symbol("P_$(L)"),
                                 Symbol("P_$(L)"),
                                 Symbol("ON_$(L)"))
    else
        device_timeseries_ub_bin(ps_m,
                                _get_time_series(devices, time_steps),
                                Symbol("active_ub_$(L)"),
                                Symbol("P_$(L)"),
                                Symbol("ON_$(L)"))
    end

    return

end

######################### output constraints with Time Series ##############################################

function _get_time_series(forecasts::PSY.FlattenIteratorWrapper{PSY.Deterministic{L}}) where {L <: PSY.ElectricLoad}

    names = Vector{String}(undef, length(forecasts))
    series = Vector{Vector{Float64}}(undef, length(forecasts))

    for (ix,f) in enumerate(forecasts)
        names[ix] = PSY.get_component(f) |> PSY.get_name
        series[ix] = values(PSY.get_data(f)) * (PSY.get_component(f) |> PSY.get_maxactivepower)
    end

    return names, series

end

function activepower_constraints(ps_m::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{PSY.Deterministic{L}},
                                 device_formulation::Type{DispatchablePowerLoad},
                                 system_formulation::Type{S}) where {L <: PSY.ElectricLoad,
                                                                     S <: PM.AbstractPowerFormulation}

    if model_has_parameters(ps_m)
        device_timeseries_param_ub(ps_m,
                                   _get_time_series(devices),
                                   Symbol("active_ub_$(L)"),
                                   Symbol("P_$(L)"),
                                   Symbol("P_$(L)"))
    else
        device_timeseries_ub(ps_m,
                            _get_time_series(devices),
                            Symbol("active_ub_$(L)"),
                            Symbol("P_$(L)"))
    end

    return

end

function activepower_constraints(ps_m::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{PSY.Deterministic{L}},
                                 device_formulation::Type{InterruptiblePowerLoad},
                                 system_formulation::Type{S}) where {L <: PSY.ElectricLoad,
                                                                     S <: PM.AbstractPowerFormulation}

    if model_has_parameters(ps_m)
        device_timeseries_ub_bigM(ps_m,
                                 _get_time_series(devices),
                                 Symbol("active_ub_$(L)"),
                                 Symbol("P_$(L)"),
                                 Symbol("P_$(L)"),
                                 Symbol("ON_$(L)"))
    else
        device_timeseries_ub_bin(ps_m,
                                _get_time_series(devices),
                                Symbol("active_ub_$(L)"),
                                Symbol("P_$(L)"),
                                Symbol("ON_$(L)"))
    end

    return

end


############################ injection expression with parameters ####################################

########################################### Devices ####################################################

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{L},
                                system_formulation::Type{S}) where {L <: PSY.ElectricLoad,
                                                                    S <: PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)
    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))
    ts_data_reactive = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        time_series_vector_active = fill(-1*PSY.get_maxactivepower(d), (time_steps[end]))
        time_series_vector_reactive = fill(-1*PSY.get_maxreactivepower(d), (time_steps[end]))
        ts_data_active[ix] = (PSY.get_name(d), PSY.get_bus(d) |> PSY.get_number, time_series_vector_active)
        ts_data_reactive[ix] = (PSY.get_name(d), PSY.get_bus(d) |> PSY.get_number, time_series_vector_reactive)
    end

    include_parameters(ps_m,
                  ts_data_active,
                  Symbol("P_$(eltype(devices))"),
                  :nodal_balance_active)
    include_parameters(ps_m,
                   ts_data_reactive,
                   Symbol("Q_$(eltype(devices))"),
                   :nodal_balance_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{L},
                                system_formulation::Type{S}) where {L <: PSY.ElectricLoad,
                                                                    S <: PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)
    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        time_series_vector = fill(-1*PSY.get_maxactivepower(d), (time_steps[end]))
        ts_data_active[ix] = (PSY.get_name(d), PSY.get_bus(d) |> PSY.get_number, time_series_vector)
    end

    include_parameters(ps_m,
                  ts_data_active,
                  Symbol("P_$(eltype(devices))"),
                  :nodal_balance_active)

    return

end

############################################## Time Series ###################################
function _nodal_expression_param(ps_m::CanonicalModel,
                                forecasts::PSY.FlattenIteratorWrapper{PSY.Deterministic{L}},
                                system_formulation::Type{S}) where {L <: PSY.ElectricLoad,
                                                                    S <: PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)

    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(forecasts))
    ts_data_reactive = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(forecasts))

    for (ix,f) in enumerate(forecasts)
        device = PSY.get_component(f)
        time_series_vector_active = -1 * values(PSY.get_data(f)) * PSY.get_maxactivepower(device)
        time_series_vector_reactive = -1*values(PSY.get_data(f))* PSY.get_maxreactivepower(device)
        ts_data_active[ix] = (PSY.get_name(device), PSY.get_bus(device) |> PSY.get_number, time_series_vector_active)
        ts_data_reactive[ix] = (PSY.get_name(device), PSY.get_bus(device) |> PSY.get_number, time_series_vector_reactive)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    Symbol("Param_P_$(L)"),
                    :nodal_balance_active)
    include_parameters(ps_m,
                    ts_data_reactive,
                    Symbol("Param_Q_$(L)"),
                    :nodal_balance_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                forecasts::PSY.FlattenIteratorWrapper{PSY.Deterministic{L}},
                                system_formulation::Type{S}) where {L <: PSY.ElectricLoad,
                                                                    S <: PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)
    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(forecasts))

    for (ix,f) in enumerate(forecasts)
        device = PSY.get_component(f)
        time_series_vector = -1*values(PSY.get_data(f))*PSY.get_maxactivepower(device)
        ts_data_active[ix] = (PSY.get_name(device), PSY.get_bus(device) |> PSY.get_number, time_series_vector)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    Symbol("Param_P_$(L)"),
                    :nodal_balance_active)

    return

end

############################ injection expression with fixed values ####################################

########################################### Devices ####################################################

function _nodal_expression_fixed(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{L},
                                system_formulation::Type{S}) where {L <: PSY.ElectricLoad,
                                                                    S <: PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)

    for t in time_steps, d in devices
        _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                            PSY.get_bus(d) |> PSY.get_number,
                            t,
                            -1*PSY.get_maxactivepower(d));
        _add_to_expression!(ps_m.expressions[:nodal_balance_reactive],
                            PSY.get_bus.number(d),
                            t,
                            -1*PSY.get_maxreactivepower(d));
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{L},
                                system_formulation::Type{S}) where {L <: PSY.ElectricLoad,
                                                                    S <: PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)

    for t in time_steps, d in devices
        _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                            PSY.get_bus(d) |> PSY.get_number,
                            t,
                            -1*PSY.get_maxactivepower(d))
    end

    return

end

############################################## Time Series ###################################

function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::PSY.FlattenIteratorWrapper{PSY.Deterministic{L}},
                                system_formulation::Type{S}) where {L <: PSY.ElectricLoad,
                                                                    S <: PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)

    for f in forecasts
        time_series_vector_active = -1*values(PSY.get_data(f)) * (PSY.get_component(f) |> PSY.get_maxactivepower)
        time_series_vector_reactive = -1*values(PSY.get_data(f)) * (PSY.get_component(f) |> PSY.get_maxreactivepower)
        device = PSY.get_component(f)
        for t in time_steps
            _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                                PSY.get_bus(device) |> PSY.get_number,
                                t,
                                time_series_vector_active[t])
            _add_to_expression!(ps_m.expressions[:nodal_balance_reactive],
                                PSY.get_bus(device) |> PSY.get_number,
                                t,
                                time_series_vector_reactive[t])
        end
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::PSY.FlattenIteratorWrapper{PSY.Deterministic{L}},
                                system_formulation::Type{S}) where {L <: PSY.ElectricLoad,
                                                                    S <: PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)

    for f in forecasts
        time_series_vector_active = -1 * values(PSY.get_data(f)) * (PSY.get_component(f) |> PSY.get_maxactivepower)
        device = PSY.get_component(f)
        for t in time_steps
            _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                                PSY.get_bus(device) |> PSY.get_number,
                                t,
                                time_series_vector_active[t])
        end
    end

    return

end

##################################### Controllable Load Cost ######################################

function cost_function(ps_m::CanonicalModel,
                       devices::PSY.FlattenIteratorWrapper{L},
                       device_formulation::Type{DispatchablePowerLoad},
                       system_formulation::Type{S}) where {L <: PSY.ControllableLoad,
                                                           S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m,
                devices,
                Symbol("P_$(L)"),
                :variablecost)

    return

end

function cost_function(ps_m::CanonicalModel,
                       devices::PSY.FlattenIteratorWrapper{L},
                       device_formulation::Type{InterruptiblePowerLoad},
                       system_formulation::Type{S}) where {L <: PSY.ControllableLoad,
                                                           S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m,
                devices,
                Symbol("ON_$(L)"),
                :curtailpenalty)

    return

end
