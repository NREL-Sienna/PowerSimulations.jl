
"""
This function adds the active power limits of generators when there are no CommitmentVariables
"""
function activepower_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen, D <: AbstractThermalDispatchForm, S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.activepowerlimits) for g in devices]

    device_range(ps_m, range_data, time_range, "thermal_active_range", "Pth")

    return nothing

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""
function activepower_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.activepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m, range_data, time_range, "thermal_active_range", "Pth", "on_th")

    return nothing

end


"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactivepower_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen, D <: AbstractThermalDispatchForm, S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_range(ps_m, range_data , time_range, "thermal_reactive_range", "Qth")

    return nothing

end



"""
This function adds the reactive power limits of generators when there CommitmentVariables
"""
function reactivepower_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m, range_data , time_range, "thermal_reactive_range", "Qth", "on_th")

    return nothing

end

"""
This function adds the active power limits of generators when there are no CommitmentVariables
"""
function activepower_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{PSI.ThermalDispatchNoMin}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, (min = 0.0, max=g.tech.activepowerlimits.max)) for g in devices]

    device_range(ps_m, range_data, time_range, "thermal_active_range", "Pth")

    return nothing

end

"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactivepower_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{PSI.ThermalDispatchNoMin}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, (min = 0.0, max=g.tech.reactivepowerlimits.max)) for g in devices]

    device_range(ps_m, range_data , time_range, "thermal_reactive_range", "Qth")

    return nothing

end