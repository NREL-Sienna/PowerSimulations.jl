### Constraints for Thermal Generation without commitment variables ####

"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""
function commitment_constraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}, initial_conditions::Array{Float64,1}) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerFormulation}

    named_initial_conditions = [(d.name, initial_conditions[ix]) for (ix, d) in enumerate(devices)]

    device_commitment(ps_m, named_initial_conditions, time_range, "commitment_th", ("start_th", "stop_th", "on_th"))

end

