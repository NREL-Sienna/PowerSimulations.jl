
function activepower_constraints(ps_m::CanonicalModel, devices::Array{H,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {H <: PSY.HydroGen, D <: AbstractHydroDispatchForm, S <: PM.AbstractPowerFormulation}

    range_data = [(h.name, h.tech.activepowerlimits) for h in devices]

    device_range(ps_m, range_data, time_range, hydro_active_range, :Phy)

    return

end


function activepower_constraints(ps_m::CanonicalModel, devices::Array{H,1}, device_formulation::Type{HydroDispatchRunOfRiver}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {H <: PSY.HydroGen, S <: PM.AbstractPowerFormulation}

    ts_data = [(h.name, values(h.scalingfactor)*h.tech.installedcapacity) for h in devices]

    device_timeseries_ub(ps_m, ts_data , time_range, hydro_active_ub, :Phy)

    return

end



function activepower_constraints(ps_m::CanonicalModel, devices::Array{H,1}, device_formulation::Type{HydroDispatchSeasonalFlow}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {H <: PSY.HydroGen, S <: PM.AbstractPowerFormulation}

    #TODO: Add To Power Systems a data type to support this
    ts_data_ub = [(h.name, values(h.scalingfactor)*h.tech.installedcapacity) for h in devices]
    ts_data_lb = [(h.name, values(h.scalingfactor)*h.tech.installedcapacity) for h in devices]

    device_timeseries_ub(ps_m, ts_data_ub , time_range, :hydro_active_ub, :Phy)
    device_timeseries_lb(ps_m, ts_data_lb , time_range, :hydro_active_lb, :Phy)

    return

end





function reactivepower_constraints(ps_m::CanonicalModel, devices::Array{H,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {H <: PSY.HydroGen, D <: AbstractHydroDispatchForm, S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_range(ps_m, range_data, time_range, :hydro_reactive_range, :Qhy)

    return

end


function activepower_constraints(ps_m::CanonicalModel, devices::Array{H,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {H <: PSY.HydroGen, D <: AbstractHydroFormulation, S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.activepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m, range_data, time_range, :hydro_active_range, :Phy, :on_hy)

    return

end


function reactivepower_constraints(ps_m::CanonicalModel, devices::Array{H,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {H <: PSY.HydroGen, D <: AbstractHydroFormulation, S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m, range_data , time_range, :hydro_reactive_range, :Qhy, :on_hy)

    return

end