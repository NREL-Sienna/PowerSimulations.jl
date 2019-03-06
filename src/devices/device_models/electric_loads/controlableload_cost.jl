function cost_function(ps_m::CanonicalModel, devices::Array{PSY.InterruptibleLoad,1}, device_formulation::Type{D}, system_formulation::Type{S}) where {D <: InterruptiblePowerLoad, S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m, devices, :Pel, :sheddingcost)

    return nothing

end

