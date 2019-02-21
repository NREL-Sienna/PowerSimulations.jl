
function time_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}, initial_conditions::Array{Float64,2}) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerFormulation}

    duration_data = [(g.name, g.tech.timelimits) for g in devices if !isa(g.tech.timelimits, Nothing)]

    if !isempty(duration_data)

        device_duration_retrospective(ps_m, duration_data, initial_conditions, time_range, "time", ("on_th", "start_th", "stop_th"))

    else

        @warn "Data doesn't contain generators with time-up/down limits, consider adjusting your formulation"

    end


end
