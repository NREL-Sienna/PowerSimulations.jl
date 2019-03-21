abstract type AbstractLoadFormulation <: AbstractDeviceFormulation end

abstract type AbstractControllablePowerLoadForm <: AbstractLoadFormulation end

struct StaticPowerLoad <: AbstractLoadFormulation end

struct InterruptiblePowerLoad <: AbstractControllablePowerLoadForm end

# load variables

function activepower_variables(ps_m::CanonicalModel, devices::Array{L,1}, time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad}

    add_variable(ps_m, devices, time_range, :Pel, false, :var_active, -1)

    return

end


function reactivepower_variables(ps_m::CanonicalModel, devices::Array{L,1}, time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad}

    add_variable(ps_m, devices, time_range, :Qel, false, :var_reactive, -1)

    return

end


# shedding constraints

function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Array{L,1},
                                 device_formulation::Type{InterruptiblePowerLoad},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad,
                                                                      S <: PM.AbstractPowerFormulation}

    ts_data = [(l.name, l.maxactivepower * values(l.scalingfactor)) for l in devices]

    device_timeseries_param_ub(ps_m, ts_data , time_range, :load_active_ub, Symbol("Pel_$(eltype(devices))"), :Pel)

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

    ps_m.constraints[:load_reactive_ub] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, [l.name for l in devices], time_range)

    for t in time_range, l in devices
            #Estimate PF from the load data. TODO: create a power factor field in PowerSystems
            ps_m.constraints[:load_reactive_ub][l.name, t] = JuMP.@constraint(ps_m.JuMPmodel,  ps_m.variables[:Qel][l.name, t] == ps_m.variables[:Pel][l.name, t] * sin(atan((l.maxreactivepower/l.maxactivepower))))

    end

    return

end


# controllable load cost

function cost_function(ps_m::CanonicalModel, devices::Array{PSY.InterruptibleLoad,1}, device_formulation::Type{D}, system_formulation::Type{S}) where {D <: InterruptiblePowerLoad, S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m, devices, :Pel, :sheddingcost)

    return

end


# Injection Expression

function nodal_expression(ps_m::CanonicalModel, devices::Array{L,1}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad, S <: PM.AbstractPowerFormulation}

    for t in time_range, d in devices

        _add_to_expression!(ps_m.expressions[:var_active], d.bus.number, t, -1*d.maxactivepower * values(d.scalingfactor)[t])

        _add_to_expression!(ps_m.expressions[:var_reactive], d.bus.number, t, -1*d.maxreactivepower*values(d.scalingfactor)[t])

    end


end


function nodal_expression(ps_m::CanonicalModel, devices::Array{L,1}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad, S <: PM.AbstractActivePowerFormulation}

    for t in time_range, d in devices

        _add_to_expression!(ps_m.expressions[:var_active], d.bus.number, t, -1*d.maxactivepower * values(d.scalingfactor)[t])

    end

    return

end
