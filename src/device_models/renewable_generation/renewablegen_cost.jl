function cost_function(ps_m::CanonicalModel, devices::Array{PSY.RenewableCurtailment,1}, device_formulation::Type{D}, system_formulation::Type{S}) where {D <: AbstractRenewableDispatchForm, S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m, devices, :Pre, :curtailpenalty, -1)

    return nothing

end
