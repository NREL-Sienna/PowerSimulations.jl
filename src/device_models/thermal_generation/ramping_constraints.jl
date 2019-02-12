

"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function ramp_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}, initial_conditions::Array{Float64,1}) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerFormulation}

    p_rate_data = [(g.name, g.tech.ramplimits, g.tech.activepowerlimits) for g in devices if !isa(g.tech.ramplimits, Nothing)]

    if !isempty(p_rate_data)

        device_mixedinteger_rateofchange(ps_m, p_rate_data, initial_conditions, time_range, "ramp_thermal", ("Pth", "start_th", "stop_th"))
        @info "Thermal Ramp Model doesn't include Reactive Power Ramp Constraints"
        #TODO: ramping for reactive power

    else

        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"

    end

end

function ramp_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}, initial_conditions::Array{Float64,1}) where {T <: PSY.ThermalGen, D <: AbstractThermalDispatchForm, S <: PM.AbstractPowerFormulation}

    p_rate_data = [(g.name, g.tech.ramplimits) for g in devices if !isa(g.tech.ramplimits, Nothing)]

    if !isempty(p_rate_data)

        device_linear_rateofchange(ps_m, p_rate_data, initial_conditions, time_range, "ramp_thermal", "Pth")
        #TODO: ramping for reactive power
        @info "Thermal Ramp Model doesn't include Reactive Power Ramp Constraints"

    else

        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"

    end

end


"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function ramp_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}, initial_conditions::Array{Float64,1}) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractActivePowerFormulation}

    p_rate_data = [(g.name, g.tech.ramplimits, g.tech.activepowerlimits) for g in devices if !isa(g.tech.ramplimits, Nothing)]

    if !isempty(p_rate_data)

        device_mixedinteger_rateofchange(ps_m, p_rate_data, initial_conditions, time_range, "ramp_thermal", ("Pth", "start_th", "stop_th"))

    else

        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"

    end

end

function ramp_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}, initial_conditions::Array{Float64,1}) where {T <: PSY.ThermalGen, D <: AbstractThermalDispatchForm, S <: PM.AbstractActivePowerFormulation}

    p_rate_data = [(g.name, g.tech.ramplimits) for g in devices if !isa(g.tech.ramplimits, Nothing)]

    if !isempty(p_rate_data)

        device_linear_rateofchange(ps_m, p_rate_data, initial_conditions, time_range, "ramp_thermal", "Pth")

    else

        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"

    end

end
