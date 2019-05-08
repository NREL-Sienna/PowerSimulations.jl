abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end

abstract type AbstractRenewableDispatchForm <: AbstractRenewableFormulation end

struct RenewableFixed <: AbstractRenewableFormulation end

struct RenewableFullDispatch <: AbstractRenewableDispatchForm end

struct RenewableConstantPowerFactor <: AbstractRenewableDispatchForm end

########################### renewable generation variables ############################################

function activepower_variables(ps_m::CanonicalModel, 
                               devices::Vector{R}, 
                               time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen}

    add_variable(ps_m,
                 devices,
                 time_range,
                 Symbol("Pre_$(R)"),
                 false,
                 :var_active)

    return

end

function reactivepower_variables(ps_m::CanonicalModel, 
                                 devices::Vector{R}, 
                                 time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen}

    add_variable(ps_m,
                 devices,
                 time_range,
                 Symbol("Qre_$(R)"),
                 false,
                 :var_reactive)

    return

end

####################################### Reactive Power Constraints ######################################

function reactivepower_constraints(ps_m::CanonicalModel,
                                    devices::Vector{R},
                                    device_formulation::Type{RenewableFullDispatch},
                                    system_formulation::Type{S},
                                    time_range::UnitRange{Int64},
                                    parameters::Bool) where {R <: PSY.RenewableGen,
                                                            S <: PM.AbstractPowerFormulation}


    range_data = [(r.name, r.tech.reactivepowerlimits) for r in devices]

    device_range(ps_m,
                range_data,
                time_range,
                Symbol("renewable_reactive_range_$(R)"),
                Symbol("Qre_$(R)"))
    
    return

end

function reactivepower_constraints(ps_m::CanonicalModel,
                                    devices::Vector{R},
                                    device_formulation::Type{RenewableConstantPowerFactor},
                                    system_formulation::Type{S},
                                    time_range::UnitRange{Int64},
                                    parameters::Bool) where {R <: PSY.RenewableGen,
                                                             S <: PM.AbstractPowerFormulation}

    names = [r.name for r in devices]
    p_variable_name = Symbol("Pre_$(R)")
    q_variable_name = Symbol("Qre_$(R)")
    constraint_name = Symbol("renewable_reactive_range_$(R)")
    ps_m.constraints[constraint_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, names, time_range)

    for t in time_range, d in devices
        ps_m.constraints[constraint_name][d.name, t] = JuMP.@constraint(ps_m.JuMPmodel, 
                                ps_m.variables[q_variable_name][d.name, t] == 
                                ps_m.variables[p_variable_name][d.name, t]*sin(acos(d.tech.powerfactor)))
    end

    return

end


######################## output constraints without Time Series ###################################

function activepower_constraints(ps_m::CanonicalModel,
                                devices::Vector{R},
                                device_formulation::Type{D},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64},
                                parameters::Bool) where {R <: PSY.RenewableGen,
                                                         D <: AbstractRenewableDispatchForm,
                                                         S <: PM.AbstractPowerFormulation}

                                                   
    range_data = [(g.name, (min = 0.0, max = g.tech.installedcapacity)) for g in devices] 
    
    if parameters
        @error("Parametrized Constraints without Time Series data not currently supported")                  
    end

    device_range(ps_m, 
                 range_data, 
                 time_range, 
                 Symbol("renewable_active_range_$(R)"),
                 Symbol("Pre_$(R)")
                 )
    return

end

######################### output constraints with Time Series ##############################################

function _get_time_series(forecasts::Vector{R}) where {R <: PSY.Deterministic{<:PSY.RenewableGen}}

    names = Vector{String}(undef, length(forecasts))
    series = Vector{Vector{Float64}}(undef, length(forecasts))

    for (ix,f) in enumerate(forecasts)
        names[ix] = f.component.name
        series[ix] = values(f.data)*f.component.tech.installedcapacity
    end

    return names, series

end

function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Vector{R},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64},
                                 parameters::Bool) where {R <: PSY.Deterministic{<:PSY.RenewableGen},
                                                          D <: AbstractRenewableDispatchForm,
                                                          S <: PM.AbstractPowerFormulation}
    
    forecast_device_type = typeof(devices[1].component)

    if parameters
        device_timeseries_param_ub(ps_m,
                                   _get_time_series(devices),
                                   time_range,
                                   Symbol("renewable_active_ub_$(forecast_device_type)"),
                                   Symbol("Param_$(forecast_device_type)"),
                                   Symbol("Pre_$(forecast_device_type)"))
    else
        device_timeseries_ub(ps_m,
                            _get_time_series(devices),
                            time_range,
                            Symbol("renewable_active_ub_$(forecast_device_type)"),
                            Symbol("Pre_$(forecast_device_type)"))
    end

    return

end

############################ injection expression with parameters ####################################

########################################### Devices ####################################################

function _nodal_expression_param(ps_m::CanonicalModel,
                                    devices::Vector{R},
                                    system_formulation::Type{S},
                                    time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                         S <: PM.AbstractPowerFormulation}

    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))
    ts_data_reactive = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        ts_data_active[ix] = (d.name, d.bus.number, ones(length(time_range))*d.tech.installedcapacity)
        ts_data_reactive[ix] = (d.name, d.bus.number, ones(length(time_range))*d.tech.installedcapacity*sin(acos(d.tech.powerfactor)))
    end

    add_parameters(ps_m,
                    ts_data_active,
                    time_range,
                    Symbol("Pre_$(R)"),
                    :var_active)
    add_parameters(ps_m,
                    ts_data_reactive,
                    time_range,
                    Symbol("Qre_$(R)"),
                    :var_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::Vector{R},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                     S <: PM.AbstractActivePowerFormulation}

    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        ts_data_active[ix] = (d.name, d.bus.number, ones(length(time_range)) * d.tech.installedcapacity)
    end

    add_parameters(ps_m,
                    ts_data_active,
                    time_range,
                    Symbol("Pre_$(R)"),
                    :var_active)
    
    return

end

############################################## Time Series ###################################

function _nodal_expression_param(ps_m::CanonicalModel,
                                    forecasts::Vector{R},
                                    system_formulation::Type{S},
                                    time_range::UnitRange{Int64}) where {R <: PSY.Deterministic{<:PSY.RenewableGen},
                                                                         S <: PM.AbstractPowerFormulation}

    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(forecasts))
    ts_data_reactive = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(forecasts))

    for (ix,f) in enumerate(forecasts)
        device = f.component
        ts_data_active[ix] = (d.name, d.bus.number, f.data*device.tech.installedcapacity)
        ts_data_reactive[ix] = (d.name, d.bus.number, f.data*device.tech.installedcapacity*sin(acos(d.tech.powerfactor)))
    end

    add_parameters(ps_m,
                    ts_data_active,
                    time_range,
                    Symbol("Pre_$(R)"),
                    :var_active)
    add_parameters(ps_m,
                    ts_data_reactive,
                    time_range,
                    Symbol("Qre_$(R)"),
                    :var_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                forecasts::Vector{R},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64}) where {R <: PSY.Deterministic{<:PSY.RenewableGen},
                                                                     S <: PM.AbstractActivePowerFormulation}

    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(forecasts))

    for (ix,f) in enumerate(forecasts)
        device= f.component
        ts_data_active[ix] = (d.name, d.bus.number, f.data*device.tech.installedcapacity)
    end

    add_parameters(ps_m,
                    ts_data_active,
                    time_range,
                    Symbol("Pre_$(R)"),
                    :var_active)
    
    return

end

############################ injection expression with fixed values ####################################

########################################### Devices ####################################################
function _nodal_expression_fixed(ps_m::CanonicalModel,
                                devices::Vector{R},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                     S <: PM.AbstractPowerFormulation}

    for t in time_range, d in devices
        _add_to_expression!(ps_m.expressions[:var_active],
                            d.bus.number,
                            t,
                            d.tech.installedcapacity)
        _add_to_expression!(ps_m.expressions[:var_reactive],
                            d.bus.number,
                            t,
                            d.tech.installedcapacity * sin(acos(d.tech.powerfactor)))
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                    devices::Vector{R},
                                    system_formulation::Type{S},
                                    time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                         S <: PM.AbstractActivePowerFormulation}

    for t in time_range, d in devices
        _add_to_expression!(ps_m.expressions[:var_active],
                            d.bus.number,
                            t,
                            d.tech.installedcapacity)
    end

    return

end


############################################## Time Series ###################################
function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::Vector{R},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64}) where {R <: PSY.Deterministic{<:PSY.RenewableGen},
                                                                     S <: PM.AbstractPowerFormulation}

    for t in time_range, f in forecasts
        _add_to_expression!(ps_m.expressions[:var_active],
                            f.component.bus.number,
                            t,
                            f.tech.installedcapacity * values(f.data)[t])
        _add_to_expression!(ps_m.expressions[:var_reactive],
                            f.component.bus.number,
                            t,
                            f.component.tech.installedcapacity * values(f.data)[t] * sin(acos(f.component.tech.powerfactor)))
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::Vector{R},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64}) where {R <: PSY.Deterministic{<:PSY.RenewableGen},
                                                                     S <: PM.AbstractActivePowerFormulation}

    for t in time_range, f in forecasts
        _add_to_expression!(ps_m.expressions[:var_active],
                            f.component.bus.number,
                            t,
                            f.tech.installedcapacity * values(f.data)[t])
    end

    return

end

##################################################################################################

function nodal_expression(ps_m::CanonicalModel,
                            devices::Vector{R},
                            system_formulation::Type{S},
                            time_range::UnitRange{Int64},
                            parameters::Bool) where {R <: Union{PSY.RenewableGen, PSY.Deterministic{<:PSY.RenewableGen}},
                                                     S <: PM.AbstractPowerFormulation}

    if parameters
        _nodal_expression_param(ps_m, devices, system_formulation, time_range)
    else
        _nodal_expression_fixed(ps_m, devices, system_formulation, time_range)
    end

    return

end


##################################### renewable generation cost ######################################

function cost_function(ps_m::CanonicalModel,
                       devices::Vector{PSY.RenewableCurtailment},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {D <: AbstractRenewableDispatchForm,
                                                           S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m, 
                devices, 
                Symbol("Pre_RenewableCurtailment"), 
                :curtailpenalty, 
                -1)

    return

end
