abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end

abstract type AbstractRenewableDispatchForm <: AbstractRenewableFormulation end

struct RenewableFixed <: AbstractRenewableFormulation end

struct RenewableFullDispatch <: AbstractRenewableDispatchForm end

struct RenewableConstantPowerFactor <: AbstractRenewableDispatchForm end

########################### renewable generation variables ############################################

function activepower_variables(ps_m::CanonicalModel, 
                               devices::PSY.FlattenedVectorsIterator{R}, 
                               time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen}

    add_variable(ps_m,
                 devices,
                 time_range,
                 Symbol("Pre_$(R)"),
                 false,
                 :nodal_balance_active)

    return

end

function reactivepower_variables(ps_m::CanonicalModel, 
                                 devices::PSY.FlattenedVectorsIterator{R}, 
                                 time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen}

    add_variable(ps_m,
                 devices,
                 time_range,
                 Symbol("Qre_$(R)"),
                 false,
                 :nodal_balance_reactive)

    return

end

####################################### Reactive Power Constraints ######################################

function reactivepower_constraints(ps_m::CanonicalModel,
                                    devices::PSY.FlattenedVectorsIterator{R},
                                    device_formulation::Type{RenewableFullDispatch},
                                    system_formulation::Type{S},
                                    time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                         S <: PM.AbstractPowerFormulation}


    range_data = [(r.name, r.tech.reactivepowerlimits) for r in devices]

    device_range(ps_m,
                range_data,
                time_range,
                Symbol("reactive_range_$(R)"),
                Symbol("Qre_$(R)"))
    
    return

end

function reactivepower_constraints(ps_m::CanonicalModel,
                                    devices::PSY.FlattenedVectorsIterator{R},
                                    device_formulation::Type{RenewableConstantPowerFactor},
                                    system_formulation::Type{S},
                                    time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                         S <: PM.AbstractPowerFormulation}

    names = [r.name for r in devices]
    p_variable_name = Symbol("Pre_$(R)")
    q_variable_name = Symbol("Qre_$(R)")
    constraint_name = Symbol("reactive_range_$(R)")
    ps_m.constraints[constraint_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, names, time_range)

    for t in time_range, d in devices
        ps_m.constraints[constraint_name][d.name, t] = JuMP.@constraint(ps_m.JuMPmodel, 
                                ps_m.variables[q_variable_name][d.name, t] == 
                                ps_m.variables[p_variable_name][d.name, t]*sin(acos(d.tech.powerfactor)))
    end

    return

end


######################## output constraints without Time Series ###################################
function _get_time_series(devices::PSY.FlattenedVectorsIterator{R}, 
                         time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen}

    names = Vector{String}(undef, length(devices))
    series = Vector{Vector{Float64}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        names[ix] = d.name
        series[ix] = fill(d.tech.rating, (time_range[end]))
    end

    return names, series

end

function activepower_constraints(ps_m::CanonicalModel,
                                devices::PSY.FlattenedVectorsIterator{R},
                                device_formulation::Type{D},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64},
                                parameters::Bool) where {R <: PSY.RenewableGen,
                                                         D <: AbstractRenewableDispatchForm,
                                                         S <: PM.AbstractPowerFormulation}
                                                  
    if parameters
        device_timeseries_param_ub(ps_m,
                            _get_time_series(devices, time_range),
                            time_range,
                            Symbol("active_ub_$(R)"),
                            Symbol("Param_$(R)"),
                            Symbol("Pre_$(R)"))
    
    else
        range_data = [(g.name, (min = 0.0, max = g.tech.rating)) for g in devices] 
        device_range(ps_m, 
                    range_data, 
                    time_range, 
                    Symbol("active_range_$(R)"),
                    Symbol("Pre_$(R)")
                    )
    end

    return

end

######################### output constraints with Time Series ##############################################

function _get_time_series(forecasts::Vector{R}) where {R <: PSY.Deterministic{<:PSY.RenewableGen}}

    names = Vector{String}(undef, length(forecasts))
    series = Vector{Vector{Float64}}(undef, length(forecasts))

    for (ix,f) in enumerate(forecasts)
        names[ix] = f.component.name
        series[ix] = values(f.data)*f.component.tech.rating
    end

    return names, series

end

function activepower_constraints(ps_m::CanonicalModel,
                                 forecasts::Vector{R},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64},
                                 parameters::Bool) where {R <: PSY.Deterministic{<:PSY.RenewableGen},
                                                          D <: AbstractRenewableDispatchForm,
                                                          S <: PM.AbstractPowerFormulation}
    
    forecast_device_type = typeof(forecasts[1].component)

    if parameters
        device_timeseries_param_ub(ps_m,
                                   _get_time_series(forecasts),
                                   time_range,
                                   Symbol("renewable_active_ub_$(forecast_device_type)"),
                                   Symbol("Param_P_$(forecast_device_type)"),
                                   Symbol("Pre_$(forecast_device_type)"))
    else
        device_timeseries_ub(ps_m,
                            _get_time_series(forecasts),
                            time_range,
                            Symbol("renewable_active_ub_$(forecast_device_type)"),
                            Symbol("Pre_$(forecast_device_type)"))
    end

    return

end

############################ injection expression with parameters ####################################

########################################### Devices ####################################################

function _nodal_expression_param(ps_m::CanonicalModel,
                                    devices::PSY.FlattenedVectorsIterator{R},
                                    system_formulation::Type{S},
                                    time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                         S <: PM.AbstractPowerFormulation}

    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))
    ts_data_reactive = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        time_series_vector = fill(d.tech.rating, (time_range[end]))
        ts_data_active[ix] = (d.name, d.bus.number, time_series_vector)
        ts_data_reactive[ix] = (d.name, d.bus.number, time_series_vector * sin(acos(d.tech.powerfactor)))
    end

    include_parameters(ps_m,
                    ts_data_active,
                    time_range,
                    Symbol("Param_P_$(R)"),
                    :nodal_balance_active)
    include_parameters(ps_m,
                    ts_data_reactive,
                    time_range,
                    Symbol("Param_Q_$(R)"),
                    :nodal_balance_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::PSY.FlattenedVectorsIterator{R},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                     S <: PM.AbstractActivePowerFormulation}

    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        time_series_vector = fill(d.tech.rating, (time_range[end]))
        ts_data_active[ix] = (d.name, d.bus.number, time_series_vector)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    time_range,
                    Symbol("Pre_$(R)"),
                    :nodal_balance_active)
    
    return

end

############################################## Time Series ###################################

function _nodal_expression_param(ps_m::CanonicalModel,
                                    forecasts::Vector{R},
                                    system_formulation::Type{S},
                                    time_range::UnitRange{Int64}) where {R <: PSY.Deterministic{<:PSY.RenewableGen},
                                                                         S <: PM.AbstractPowerFormulation}

    forecast_device_type = typeof(forecasts[1].component)

    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(forecasts))
    ts_data_reactive = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(forecasts))

    for (ix,f) in enumerate(forecasts)
        device = f.component
        time_series_vector = values(f.data)*device.tech.rating
        ts_data_active[ix] = (device.name, device.bus.number, time_series_vector)
        ts_data_reactive[ix] = (device.name, device.bus.number, time_series_vector * sin(acos(device.tech.powerfactor)))
    end

    include_parameters(ps_m,
                    ts_data_active,
                    time_range,
                    Symbol("Param_P_$(forecast_device_type)"),
                    :nodal_balance_active)
    include_parameters(ps_m,
                    ts_data_reactive,
                    time_range,
                    Symbol("Param_Q_$(forecast_device_type)"),
                    :nodal_balance_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                forecasts::Vector{R},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64}) where {R <: PSY.Deterministic{<:PSY.RenewableGen},
                                                                     S <: PM.AbstractActivePowerFormulation}

    forecast_device_type = typeof(forecasts[1].component)
    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(forecasts))

    for (ix,f) in enumerate(forecasts)
        device = f.component
        time_series_vector = values(f.data)*device.tech.rating
        ts_data_active[ix] = (device.name, device.bus.number, time_series_vector)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    time_range,
                    Symbol("Param_P_$(forecast_device_type)"),
                    :nodal_balance_active)
    
    return

end

############################ injection expression with fixed values ####################################

########################################### Devices ####################################################
function _nodal_expression_fixed(ps_m::CanonicalModel,
                                devices::PSY.FlattenedVectorsIterator{R},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                     S <: PM.AbstractPowerFormulation}

    for t in time_range, d in devices
        _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                            d.bus.number,
                            t,
                            d.tech.rating)
        _add_to_expression!(ps_m.expressions[:nodal_balance_reactive],
                            d.bus.number,
                            t,
                            d.tech.rating * sin(acos(d.tech.powerfactor)))
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                    devices::PSY.FlattenedVectorsIterator{R},
                                    system_formulation::Type{S},
                                    time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                         S <: PM.AbstractActivePowerFormulation}

    for t in time_range, d in devices
        _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                            d.bus.number,
                            t,
                            d.tech.rating)
    end

    return

end


############################################## Time Series ###################################
function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::Vector{R},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64}) where {R <: PSY.Deterministic{<:PSY.RenewableGen},
                                                                     S <: PM.AbstractPowerFormulation}
    for f in forecasts
        time_series_vector = values(f.data)*f.component.tech.rating
        device = f.component
        for t in time_range
            _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                                device.bus.number,
                                t,
                                time_series_vector[t])
            _add_to_expression!(ps_m.expressions[:nodal_balance_reactive],
                                device.bus.number,
                                t,
                                time_series_vector[t] * sin(acos(device.tech.powerfactor)))
        end
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::Vector{R},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64}) where {R <: PSY.Deterministic{<:PSY.RenewableGen},
                                                                     S <: PM.AbstractActivePowerFormulation}

    for f in forecasts
        time_series_vector = values(f.data)*f.component.tech.rating
        device = f.component
        for t in time_range
            _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                                device.bus.number,
                                t,
                                time_series_vector[t])
        end
    end

    return

end

##################################### renewable generation cost ######################################

function cost_function(ps_m::CanonicalModel,
                       devices::PSY.FlattenedVectorsIterator{PSY.RenewableCurtailment},
                       device_formulation::Type{D},
                       system_formulation::Type{S},
                       resolution::Dates.Period) where {D <: AbstractRenewableDispatchForm,
                                                           S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m, 
                devices,
                resolution, 
                Symbol("Pre_RenewableCurtailment"), 
                :curtailpenalty, 
                -1)

    return

end
