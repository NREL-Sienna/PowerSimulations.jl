abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end

abstract type AbstractRenewableDispatchForm <: AbstractRenewableFormulation end

struct RenewableFixed <: AbstractRenewableFormulation end

struct RenewableFullDispatch <: AbstractRenewableDispatchForm end

struct RenewableConstantPowerFactor <: AbstractRenewableDispatchForm end

# renewable variables

function activepower_variables(ps_m::CanonicalModel, devices::Array{R,1}, time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen}

    add_variable(ps_m, devices, time_range, :Pre, false, :var_active)

    return

end

function reactivepower_variables(ps_m::CanonicalModel, devices::Array{R,1}, time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen}

    add_variable(ps_m, devices, time_range, :Qre, false, :var_reactive)

    return

end

# output constraints

function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Array{R,1},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                      D <: AbstractRenewableDispatchForm,
                                                                      S <: PM.AbstractPowerFormulation}

    ts_data = [(r.name, values(r.scalingfactor)*r.tech.installedcapacity) for r in devices]

    device_timeseries_param_ub(ps_m, ts_data , time_range, :renewable_active_ub, Symbol("Pre_$(eltype(devices))"), :Pre)

    return

end


function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Array{R,1},
                                   device_formulation::Type{RenewableFullDispatch},
                                   system_formulation::Type{S},
                                   time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(r.name, r.tech.reactivepowerlimits) for r in devices]

    device_range(ps_m, range_data , time_range, :renewable_reactive_range, :Qre)

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


# injection expression

function nodal_expression(ps_m::CanonicalModel, devices::Array{R,1}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen, S <: PM.AbstractPowerFormulation}

    for t in time_range, d in devices

        _add_to_expression!(ps_m.expressions[:var_active], d.bus.number, t, d.tech.installedcapacity * values(d.scalingfactor)[t])

        _add_to_expression!(ps_m.expressions[:var_reactive], d.bus.number, t, d.tech.installedcapacity * values(d.scalingfactor)[t]*sin(acos(d.tech.powerfactor)))

    end

    return

end


function nodal_expression(ps_m::CanonicalModel, devices::Array{R,1}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen, S <: PM.AbstractActivePowerFormulation}

    for t in time_range, d in devices

        _add_to_expression!(ps_m.expressions[:var_active], d.bus.number, t, d.tech.installedcapacity * values(d.scalingfactor)[t])

    end

    return

end


# renewable generation cost

function cost_function(ps_m::CanonicalModel, devices::Array{PSY.RenewableCurtailment,1}, device_formulation::Type{D}, system_formulation::Type{S}) where {D <: AbstractRenewableDispatchForm, S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m, devices, :Pre, :curtailpenalty, -1)

    return

end
