abstract type AbstractLoadFormulation <: AbstractDeviceFormulation end

abstract type AbstractControllablePowerLoadForm <: AbstractLoadFormulation end

struct StaticPowerLoad <: AbstractLoadFormulation end

struct InterruptiblePowerLoad <: AbstractControllablePowerLoadForm end

function _get_time_series(device::Array{T}) where {T <: PSY.ElectricLoad}

    names = Vector{String}(undef, length(device))
    series = Vector{Vector{Float64}}(undef, length(device)) 

    for (ix,d) in enumerate(devices) 
        names[ix] = d.name
        series[ix] = d.maxactivepower * values(d.scalingfactor)
    end

    return names, series

end

# load variables

function activepower_variables(ps_m::CanonicalModel, 
                               devices::Array{L,1}, 
                               time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad}

    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 :Pel, 
                 false, 
                 :var_active, -1)

    return

end


function reactivepower_variables(ps_m::CanonicalModel, 
                                 devices::Array{L,1}, 
                                 time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad}

    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 :Qel, 
                 false, 
                 :var_reactive, -1)

    return

end


# shedding constraints

function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Array{L,1},
                                 device_formulation::Type{InterruptiblePowerLoad},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64}; 
                                 parameters::Bool = true) where {L <: PSY.ElectricLoad,
                                                                      S <: PM.AbstractPowerFormulation}
    if parameters
        device_timeseries_param_ub(ps_m, 
                                   _get_time_series(devices), 
                                   time_range, 
                                   :load_active_ub, 
                                   Symbol("Pel_$(eltype(devices))"), 
                                   :Pel)
    else
        device_timeseries_ub(ps_m, 
                             _get_time_series(devices), 
                             time_range, 
                             :load_active_ub, 
                             :Pel)
    end

    return

end


function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Array{L,1},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S},
                                   time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad,
                                                                        D <: AbstractControllablePowerLoadForm,
                                                                        S <: PM.AbstractPowerFormulation}

    #TODO: Filter for loads with PF = 1.0

    ps_m.constraints[:load_reactive_ub] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, [d.name for d in devices], time_range)

    for t in time_range, d in devices
            #Estimate PF from the load data. TODO: create a power factor field in PowerSystems
            ps_m.constraints[:load_reactive_ub][d.name, t] = JuMP.@constraint(ps_m.JuMPmodel,  
                                                             ps_m.variables[:Qel][d.name, t] == ps_m.variables[:Pel][d.name, t] * sin(atan((d.maxreactivepower/d.maxactivepower))))
    end

    return

end


# controllable load cost

function cost_function(ps_m::CanonicalModel, 
                       devices::Array{PSY.InterruptibleLoad,1}, 
                       device_formulation::Type{D}, 
                       system_formulation::Type{S}) where {D <: InterruptiblePowerLoad, 
                                                           S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m, devices, 
                      :Pel, 
                      :sheddingcost)

    return

end


# Injection Expression with parameters

function nodal_expression(ps_m::CanonicalModel, 
                          devices::Array{L,1}, 
                          system_formulation::Type{S}, 
                          time_range::UnitRange{Int64},
                          parameters::Bool = true) where {L <: PSY.ElectricLoad, 
                                                               S <: PM.AbstractPowerFormulation}

        if parameters 
            nodal_expression_param(ps_m, fixed_resources, system_formulation, time_range)
        else 
            nodal_expression_fixed(ps_m, fixed_resources, system_formulation, time_range)
        end
    
    return    

end                                                               

function nodal_expression_param(ps_m::CanonicalModel, 
                                devices::Array{L,1}, 
                                system_formulation::Type{S}, 
                                time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad, 
                                                                     S <: PM.AbstractPowerFormulation}

    ts_data_active = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))
    ts_data_reactive = Vector{Tuple{String,Int64,Vector{Float64}}}(undef, length(devices))

    for (ix,d) in enumerate(devices)
        ts_data_active[ix] = (d.name, d.bus.number, -1*d.maxactivepower * values(d.scalingfactor)) 
        ts_data_reactive[ix] = (d.name, d.bus.number, -1*d.maxreactivepower * values(d.scalingfactor))
    end

    add_parameters(ps_m, ts_data_active, time_range, Symbol("Pel_$(eltype(devices))"), :var_active)
    add_parameters(ps_m, ts_data_reactive, time_range, Symbol("Qel_$(eltype(devices))"), :var_reactive)

end

function nodal_expression_param(ps_m::CanonicalModel, 
                                devices::Array{L,1}, 
                                system_formulation::Type{S}, 
                                time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad, 
                                                                     S <: PM.AbstractActivePowerFormulation}

    ts_data = [(d.name, d.bus.number, -1*d.maxactivepower * values(d.scalingfactor)) for d in devices]

    add_parameters(ps_m, ts_data, time_range, Symbol("Pel_$(eltype(devices))"), :var_active)

    return

end

# Injection Expression with fixed values

function nodal_expression_fixed(ps_m::CanonicalModel, 
                                devices::Array{L,1}, 
                                system_formulation::Type{S}, 
                                time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad, 
                                                                     S <: PM.AbstractPowerFormulation}

    for t in time_range, d in devices
        _add_to_expression!(ps_m.expressions[:var_active], d.bus.number, t, -1*d.maxactivepower * values(d.scalingfactor)[t]);
        _add_to_expression!(ps_m.expressions[:var_reactive], d.bus.number, t, -1*d.maxreactivepower * values(d.scalingfactor)[t]);
    end


end


function nodal_expression_fixed(ps_m::CanonicalModel, 
                                devices::Array{L,1}, 
                                system_formulation::Type{S}, 
                                time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad, 
                                                                     S <: PM.AbstractActivePowerFormulation}

    for t in time_range, d in devices
        _add_to_expression!(ps_m.expressions[:var_active], d.bus.number, t, -1*d.maxactivepower * values(d.scalingfactor)[t])
    end

    return

end
