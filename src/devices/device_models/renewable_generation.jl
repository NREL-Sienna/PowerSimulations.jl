abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end

abstract type AbstractRenewableDispatchForm <: AbstractRenewableFormulation end

struct RenewableFixed <: AbstractRenewableFormulation end

struct RenewableFullDispatch <: AbstractRenewableDispatchForm end

struct RenewableConstantPowerFactor <: AbstractRenewableDispatchForm end

# renewable variables

function activepower_variables(ps_m::CanonicalModel, devices::Array{R,1}, time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen}

    add_variable(ps_m,
                 devices,
                 time_range,
                 :Pre,
                 false,
                 :var_active)

    return

end

function reactivepower_variables(ps_m::CanonicalModel, devices::Array{R,1}, time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen}

    add_variable(ps_m,
                 devices,
                 time_range,
                 :Qre,
                 false,
                 :var_reactive)

    return

end

###### output constraints without Time Series ##############

function activepower_constraints(ps_m::CanonicalModel,
                                devices::Array{R,1},
                                device_formulation::Type{D},
                                system_formulation::Type{S},
                                parameters::Bool) where {R <: PSY.RenewableGen,
                                                                    D <: AbstractRenewableDispatchForm,
                                                                    S <: PM.AbstractPowerFormulation}


    if parameters
        device_timeseries_param_ub(ps_m,
                                    _get_time_series(devices),
                                    time_range,
                                    :renewable_active_ub,
                                    Symbol("Pre_$(eltype(devices))"),
                                    :Pre)
    else
        device_timeseries_ub(ps_m,
                            _get_time_series(devices),
                            time_range,
                            :renewable_active_ub,
                            :Pre)
    end

    return

end


function reactivepower_constraints(ps_m::CanonicalModel,
                                devices::Array{R,1},
                                device_formulation::Type{RenewableFullDispatch},
                                system_formulation::Type{S}) where {R <: PSY.RenewableGen,
                                                                    S <: PM.AbstractPowerFormulation}

    range_data = [(r.name, r.tech.reactivepowerlimits) for r in devices]

    device_range(ps_m,
                range_data ,
                time_range,
                :renewable_reactive_range,
                :Qre)

    return

end


function reactivepower_constraints(ps_m::CanonicalModel,
                                devices::Array{R,1},
                                device_formulation::Type{RenewableConstantPowerFactor},
                                system_formulation::Type{S}) where {R <: PSY.RenewableGen,
                                                                    S <: PM.AbstractPowerFormulation}

    names = [r.name for r in devices]

    ps_m.constraints[:renewable_reactive] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, names, time_range)

    for t in time_range, d in devices
        ps_m.constraints[:renewable_reactive][d.name, t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[:Qre][d.name, t] == ps_m.variables[:Pre][d.name, t]*sin(acos(d.tech.powerfactor)))
    end

    return

end

###### output constraints with Time Series ##############

function _get_time_series(devices::Array{T}) where {T <: PSY.RenewableGen}

    names = Vector{String}(undef, length(devices))
    series = Vector{Vector{Float64}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        names[ix] = d.name
        series[ix] = values(d.scalingfactor)*d.tech.installedcapacity
    end

    return names, series

end

function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Array{R,1},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64},
                                 parameters::Bool) where {R <: PSY.RenewableGen,
                                                                      D <: AbstractRenewableDispatchForm,
                                                                      S <: PM.AbstractPowerFormulation}

    if parameters
        device_timeseries_param_ub(ps_m,
                                   _get_time_series(devices),
                                   time_range,
                                   :renewable_active_ub,
                                   Symbol("Pre_$(eltype(devices))"),
                                   :Pre)
    else
        device_timeseries_ub(ps_m,
                            _get_time_series(devices),
                            time_range,
                            :renewable_active_ub,
                            :Pre)
    end

    return

end


function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Array{R,1},
                                   device_formulation::Type{RenewableFullDispatch},
                                   system_formulation::Type{S},
                                   time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(r.name, r.tech.reactivepowerlimits) for r in devices]

    device_range(ps_m,
                range_data ,
                time_range,
                :renewable_reactive_range,
                :Qre)

    return

end


function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Array{R,1},
                                   device_formulation::Type{RenewableConstantPowerFactor},
                                   system_formulation::Type{S},
                                   time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                        S <: PM.AbstractPowerFormulation}

    names = [r.name for r in devices]

    ps_m.constraints[:renewable_reactive] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, names, time_range)

    for t in time_range, d in devices
        ps_m.constraints[:renewable_reactive][d.name, t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[:Qre][d.name, t] == ps_m.variables[:Pre][d.name, t]*sin(acos(d.tech.powerfactor)))
    end

    return

end

##### Injection Expression with parameters #####

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::Array{R,1},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                     S <: PM.AbstractPowerFormulation}

    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))
    ts_data_reactive = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        ts_data_active[ix] = (d.name, d.bus.number, values(d.scalingfactor)*d.tech.installedcapacity)
        ts_data_reactive[ix] = (d.name, d.bus.number, values(d.scalingfactor)*d.tech.installedcapacity)
    end

    add_parameters(ps_m,
                   ts_data_active,
                   time_range,
                   Symbol("Pre_$(eltype(devices))"),
                   :var_active)
    add_parameters(ps_m,
                   ts_data_reactive,
                   time_range,
                   Symbol("Qre_$(eltype(devices))"),
                   :var_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::Array{R,1},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                     S <: PM.AbstractActivePowerFormulation}

    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        ts_data_active[ix] = (d.name, d.bus.number, values(d.scalingfactor)*d.tech.installedcapacity)
    end

    add_parameters(ps_m,
                   ts_data_active,
                   time_range,
                   Symbol("Pre_$(eltype(devices))"),
                   :var_active)
    return

end


###### injection expression with fixed values #######

function _nodal_expression_fixed(ps_m::CanonicalModel,
                                devices::Array{R,1},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                     S <: PM.AbstractPowerFormulation}

    for t in time_range, d in devices
        _add_to_expression!(ps_m.expressions[:var_active],
                            d.bus.number,
                            t,
                            d.tech.installedcapacity * values(d.scalingfactor)[t])
        _add_to_expression!(ps_m.expressions[:var_reactive],
                            d.bus.number,
                            t,
                            d.tech.installedcapacity * values(d.scalingfactor)[t]*sin(acos(d.tech.powerfactor)))
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                devices::Array{R,1},
                                system_formulation::Type{S},
                                time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                     S <: PM.AbstractActivePowerFormulation}

    for t in time_range, d in devices
        _add_to_expression!(ps_m.expressions[:var_active],
                            d.bus.number,
                            t,
                            d.tech.installedcapacity * values(d.scalingfactor)[t])
    end

    return

end


function nodal_expression(ps_m::CanonicalModel,
                          devices::Array{R,1},
                          system_formulation::Type{S},
                          time_range::UnitRange{Int64},
                          parameters::Bool) where {R <: PSY.RenewableGen,
                                                          S <: PM.AbstractPowerFormulation}

    if parameters
        _nodal_expression_param(ps_m, devices, system_formulation, time_range)
    else
        _nodal_expression_fixed(ps_m, devices, system_formulation, time_range)
    end

    return

end



######## renewable generation cost ##############

function cost_function(ps_m::CanonicalModel,
                       devices::Array{PSY.RenewableCurtailment,1},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {D <: AbstractRenewableDispatchForm,
                                                           S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m, devices, :Pre, :curtailpenalty, -1)

    return

end
