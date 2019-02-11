
"""
This function adds the ramping limits of generators when there are no CommitmentVariables
"""
function ramp(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{ThermalRampLimited}, system_formulation::Type{S}, time_periods::Int64; kwargs...) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerFormulation}

    if :initialpower in keys(args)
        initialpower = args[:initialpower]
    else
        initialpower = Dict([name=>devices[ix].tech.activepower for (ix,name) in enumerate(name_index)])
    end


end


"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function ramp(m::JuMP.AbstractModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64; kwargs...) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractActivePowerFormulation}

        if :initialpower in keys(args)
            initialpower = args[:initialpower]
        else
            initialpower = Dict([name=>devices[ix].tech.activepower for (ix,name) in enumerate(name_index)])
        end


end
