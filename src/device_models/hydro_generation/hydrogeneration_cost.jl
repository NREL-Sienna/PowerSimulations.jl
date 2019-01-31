function cost_function(ps_m::CanonicalModel, devices::Array{PSY.HydroGen,1}, device_formulation::Type{D}, system_formulation::Type{S}) where {D <: PSI.HydroDispatchRunOfRiver, S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m, devices, "Phy", :curtailcost)

end
