"""
This function adds the power limits of renewable energy generators that can be dispatched
"""
function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Array{R,1},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S},
                                 time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                      D <: AbstractRenewableDispatchForm,
                                                                      S <: PM.AbstractPowerFormulation}

    ts_data = [(r.name, values(r.scalingfactor)*r.tech.installedcapacity) for r in devices]

    device_timeseries_ub(ps_m, ts_data , time_range, "renewable_active_ub", "Pre")

end

"""
This function adds the reactive power limits of renewable generators that can be dispatched
"""
function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Array{R,1},
                                   device_formulation::Type{RenewableFullDispatch},
                                   system_formulation::Type{S},
                                   time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,                                                                     S <: PM.AbstractPowerFormulation}

    range_data = [(r.name, r.tech.reactivepowerlimits) for r in devices]

    device_range(ps_m, range_data , time_range, "renewable_reactive_range", "Qre")

end

"""
This function adds the reactive power limits of renewable generators that can be dispatched
"""
function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Array{R,1},
                                   device_formulation::Type{RenewableConstantPowerFactor},
                                   system_formulation::Type{S},
                                   time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen,
                                                                        S <: PM.AbstractPowerFormulation}

    names = [r.name for r in devices]

    ps_m.constraints["renewable_reactive"] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, names, time_range)

    for t in time_range, d in devices

        ps_m.constraints["renewable_reactive"][d.name, t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables["Qre"][d.name, t] == ps_m.variables["Pre"][d.name, t]*sin(acos(d.tech.powerfactor)))

    end

end

