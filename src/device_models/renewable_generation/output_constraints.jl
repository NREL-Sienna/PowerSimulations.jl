"""
This function adds the power limits of renewable energy generators that can be dispatched
"""
function activepower(ps_m::CanonicalModel, devices::Array{R,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {R <: PowerSystems.RenewableGen, D <: AbstractRenewableDispatchForm, S <: PM.AbstractPowerFormulation}

    ts_data = [(r.name, values(r.scalingfactor)*r.tech.installedcapacity) for r in devices]

    device_timeseries_ub(ps_m, ts_data , time_range, "renewable_active_ub", "Pre")

end

"""
This function adds the reactive power limits of renewable generators that can be dispatched
"""
function reactivepower(ps_m::CanonicalModel, devices::Array{R,1}, device_formulation::Type{RenewableFullDispatch}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {R <: PowerSystems.RenewableGen,  S <: AbstractACPowerModel}

    range_data = [(r.name, r.tech.reactivepowerlimits) for r in devices]

    device_range(ps_m, range_data , time_range, "renewable_reactive_range", "Qre")

end

"""
This function adds the reactive power limits of renewable generators that can be dispatched
"""
function reactivepower(ps_m::CanonicalModel, devices::Array{R,1}, device_formulation::Type{RenewableConstantPowerFactor}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {R <: PowerSystems.RenewableGen,  S <: AbstractACPowerModel}

    ts_data = [(r.name, values(r.scalingfactor)*r.tech.installedcapacity*sin(acos(r.tech.powerfactor))) for r in devices]

    device_timeseries_ub(ps_m, ts_data , time_range, "renewable_reactive_ub", "Qre")
    device_timeseries_lb(ps_m, ts_data , time_range, "renewable_reactive_lb", "Qre")

end
