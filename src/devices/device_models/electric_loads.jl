abstract type AbstractLoadFormulation <: AbstractDeviceFormulation end

abstract type AbstractControllablePowerLoadForm <: AbstractLoadFormulation end

struct StaticPowerLoad <: AbstractLoadFormulation end

struct InterruptiblePowerLoad <: AbstractControllablePowerLoadForm end

struct DispatchablePowerLoad <: AbstractControllablePowerLoadForm end

########################### dispatchable load variables ############################################

function activepower_variables(ps_m::CanonicalModel,
                               devices::PSY.FlattenedVectorsIterator{L},
                               lookahead::UnitRange{Int64}) where {L <: PSY.ElectricLoad}

    add_variable(ps_m,
                 devices,
                 lookahead,
                 Symbol("Pel_$(L)"),
                 false,
                 :nodal_balance_active, -1)

    return

end


function reactivepower_variables(ps_m::CanonicalModel,
                                 devices::PSY.FlattenedVectorsIterator{L},
                                 lookahead::UnitRange{Int64}) where {L <: PSY.ElectricLoad}

    add_variable(ps_m,
                 devices,
                 lookahead,
                 Symbol("Qel_$(L)"),
                 false,
                 :nodal_balance_reactive, -1)

    return

end

function commitment_variables(ps_m::CanonicalModel,
                              devices::PSY.FlattenedVectorsIterator{L},
                              lookahead::UnitRange{Int64}) where {L <: PSY.ElectricLoad}

    add_variable(ps_m, 
                 devices, 
                 lookahead, 
                 Symbol("ONel_$(L)"), 
                 true)

    return

end

####################################### Reactive Power Constraints ######################################
"""
Reactive Power Constraints on Loads Assume Constant PowerFactor
"""
function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::PSY.FlattenedVectorsIterator{L},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S},
                                   lookahead::UnitRange{Int64}) where {L <: PSY.ElectricLoad,
                                                                        D <: AbstractControllablePowerLoadForm,
                                                                        S <: PM.AbstractPowerFormulation}

    ps_m.constraints[:load_reactive_ub] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, [d.name for d in devices], lookahead)

    for t in lookahead, d in devices
            ps_m.constraints[:load_reactive_ub][d.name, t] = JuMP.@constraint(ps_m.JuMPmodel,
                                                             ps_m.variables[Symbol("Qel_$(L)")][d.name, t] == 
                                                             ps_m.variables[Symbol("Pel_$(L)")][d.name, t] * sin(atan((d.maxreactivepower/d.maxactivepower))))
    end

    return

end


######################## output constraints without Time Series ###################################
function _get_time_series(devices::PSY.FlattenedVectorsIterator{T}, 
                          lookahead::UnitRange{Int64}) where {T <: PSY.ElectricLoad}

    names = Vector{String}(undef, length(devices))
    series = Vector{Vector{Float64}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        names[ix] = d.name
        series[ix] = fill(d.maxactivepower, (lookahead[end]))
    end

    return names, series

end

function activepower_constraints(ps_m::CanonicalModel,
                                 devices::PSY.FlattenedVectorsIterator{L},
                                 device_formulation::Type{DispatchablePowerLoad},
                                 system_formulation::Type{S},
                                 lookahead::UnitRange{Int64},
                                 parameters::Bool) where {L <: PSY.ElectricLoad,
                                                          S <: PM.AbstractPowerFormulation}
    if parameters
        device_timeseries_param_ub(ps_m,
                                   _get_time_series(devices, lookahead),
                                   lookahead,
                                   Symbol("active_ub_$(L)"),
                                   Symbol("Param_$(L))"),
                                   Symbol("Pel_$(L)"))
    else
        range_data = [(g.name, (min = 0.0, max = g.maxactivepower)) for g in devices] 
        device_range(ps_m, 
                    range_data, 
                    lookahead, 
                    Symbol("active_range_$(L)"),
                    Symbol("Pel_$(L)")
                    )
    end

    return

end

######################### output constraints with Time Series ##############################################

function _get_time_series(forecasts::Vector{L}) where {L <: PSY.Deterministic{<:PSY.ElectricLoad}}

    names = Vector{String}(undef, length(forecasts))
    series = Vector{Vector{Float64}}(undef, length(forecasts))

    for (ix,f) in enumerate(forecasts)
        names[ix] = f.component.name
        series[ix] = values(f.data)*f.component.maxreactivepower
    end

    return names, series

end

function activepower_constraints(ps_m::CanonicalModel,
                                 devices::PSY.FlattenedVectorsIterator{L},
                                 device_formulation::Type{DispatchablePowerLoad},
                                 system_formulation::Type{S},
                                 lookahead::UnitRange{Int64},
                                 parameters::Bool) where {L <: PSY.Deterministic{<:PSY.ElectricLoad},
                                                          D <: AbstractControllablePowerLoadForm,
                                                          S <: PM.AbstractPowerFormulation}
    
    forecast_device_type = typeof(forecasts[1].component)

    if parameters
        device_timeseries_param_ub(ps_m,
                                   _get_time_series(devices),
                                   lookahead,
                                   Symbol("load_active_ub_$(forecast_device_type)"),
                                   Symbol("Param_$(forecast_device_type)"),
                                   Symbol("Pel_$(forecast_device_type)"))
    else
        device_timeseries_ub(ps_m,
                            _get_time_series(devices),
                            lookahead,
                            Symbol("load_active_ub_$(forecast_device_type)"),
                            Symbol("Pel_$(forecast_device_type)"))
    end

    return

end


############################ injection expression with parameters ####################################

########################################### Devices ####################################################

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::PSY.FlattenedVectorsIterator{L},
                                system_formulation::Type{S},
                                lookahead::UnitRange{Int64}) where {L <: PSY.ElectricLoad,
                                                                     S <: PM.AbstractPowerFormulation}

    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))
    ts_data_reactive = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        time_series_vector_active = fill(-1*d.maxactivepower, (lookahead[end]))
        time_series_vector_reactive = fill(-1*d.maxreactivepower, (lookahead[end]))
        ts_data_active[ix] = (d.name, d.bus.number, time_series_vector_active)
        ts_data_reactive[ix] = (d.name, d.bus.number, time_series_vector_reactive)
    end

    include_parameters(ps_m, 
                  ts_data_active, 
                  lookahead, 
                  Symbol("Pel_$(eltype(devices))"), 
                  :nodal_balance_active)
    include_parameters(ps_m, 
                   ts_data_reactive, 
                   lookahead, 
                   Symbol("Qel_$(eltype(devices))"), 
                   :nodal_balance_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::PSY.FlattenedVectorsIterator{L},
                                system_formulation::Type{S},
                                lookahead::UnitRange{Int64}) where {L <: PSY.ElectricLoad,
                                                                     S <: PM.AbstractActivePowerFormulation}
    
    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        time_series_vector = fill(-1*d.maxactivepower, (lookahead[end]))
        ts_data_active[ix] = (d.name, d.bus.number, time_series_vector)
    end

    include_parameters(ps_m, 
                  ts_data_active, 
                  lookahead, 
                  Symbol("Pel_$(eltype(devices))"), 
                  :nodal_balance_active)
    
    return

end

############################################## Time Series ###################################
function _nodal_expression_param(ps_m::CanonicalModel,
                                forecasts::Vector{L},
                                system_formulation::Type{S},
                                lookahead::UnitRange{Int64}) where {L <: PSY.Deterministic{<:PSY.ElectricLoad},
                                                                     S <: PM.AbstractPowerFormulation}

    forecast_device_type = typeof(forecasts[1].component)

    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(forecasts))
    ts_data_reactive = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(forecasts))

    for (ix,f) in enumerate(forecasts)
        device = f.component
        time_series_vector_active = -1*values(f.data)*device.maxactivepower
        time_series_vector_reactive = -1*values(f.data)*device.maxreactivepower
        ts_data_active[ix] = (device.name, device.bus.number, time_series_vector_active)
        ts_data_reactive[ix] = (device.name, device.bus.number, time_series_vector_reactive)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    lookahead,
                    Symbol("Param_P_$(forecast_device_type)"),
                    :nodal_balance_active)
    include_parameters(ps_m,
                    ts_data_reactive,
                    lookahead,
                    Symbol("Param_Q_$(forecast_device_type)"),
                    :nodal_balance_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                forecasts::Vector{L},
                                system_formulation::Type{S},
                                lookahead::UnitRange{Int64}) where {L <: PSY.Deterministic{<:PSY.ElectricLoad},
                                                                     S <: PM.AbstractActivePowerFormulation}

    forecast_device_type = typeof(forecasts[1].component)

    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(forecasts))

    for (ix,f) in enumerate(forecasts)
        device = f.component
        time_series_vector = -1*values(f.data)*device.maxactivepower
        ts_data_active[ix] = (device.name, device.bus.number, time_series_vector)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    lookahead,
                    Symbol("Param_P_$(forecast_device_type)"),
                    :nodal_balance_active)

    return

end

############################ injection expression with fixed values ####################################

########################################### Devices ####################################################

function _nodal_expression_fixed(ps_m::CanonicalModel,
                                devices::PSY.FlattenedVectorsIterator{L},
                                system_formulation::Type{S},
                                lookahead::UnitRange{Int64}) where {L <: PSY.ElectricLoad,
                                                                     S <: PM.AbstractPowerFormulation}

    for t in lookahead, d in devices
        _add_to_expression!(ps_m.expressions[:nodal_balance_active], 
                            d.bus.number, 
                            t, 
                            -1*d.maxactivepower);
        _add_to_expression!(ps_m.expressions[:nodal_balance_reactive], 
                            d.bus.number, 
                            t, 
                            -1*d.maxreactivepower);
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                devices::PSY.FlattenedVectorsIterator{L},
                                system_formulation::Type{S},
                                lookahead::UnitRange{Int64}) where {L <: PSY.ElectricLoad,
                                                                     S <: PM.AbstractActivePowerFormulation}

    for t in lookahead, d in devices
        _add_to_expression!(ps_m.expressions[:nodal_balance_active], 
                            d.bus.number, 
                            t, 
                            -1*d.maxactivepower)
    end

    return

end

############################################## Time Series ###################################

function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::Vector{L},
                                system_formulation::Type{S},
                                lookahead::UnitRange{Int64}) where {L <: PSY.Deterministic{<:PSY.ElectricLoad},
                                                                     S <: PM.AbstractPowerFormulation}

    for f in forecasts
        time_series_vector_active = -1*values(f.data)*f.component.maxactivepower
        time_series_vector_reactive = -1*values(f.data)*f.component.maxreactivepower
        device = f.component
        for t in lookahead           
            _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                                device.bus.number,
                                t,
                                time_series_vector_active[t])
            _add_to_expression!(ps_m.expressions[:nodal_balance_reactive],
                                device.bus.number,
                                t,
                                time_series_vector_reactive[t])
        end
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::Vector{L},
                                system_formulation::Type{S},
                                lookahead::UnitRange{Int64}) where {L <: PSY.Deterministic{<:PSY.ElectricLoad},
                                                                     S <: PM.AbstractActivePowerFormulation}

    for f in forecasts
        time_series_vector_active = -1*values(f.data)*f.component.maxactivepower
        device = f.component
        for t in lookahead           
            _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                                device.bus.number,
                                t,
                                time_series_vector_active[t])
        end
    end

    return

end

##################################### Controllable Load Cost ######################################

function cost_function(ps_m::CanonicalModel,
                       devices::PSY.FlattenedVectorsIterator{PSY.InterruptibleLoad},
                       device_formulation::Type{DispatchablePowerLoad},
                       system_formulation::Type{S}) where {S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m, devices,
                      Symbol("Pel_DispatchablePowerLoad"),
                      :sheddingcost)

    return

end
