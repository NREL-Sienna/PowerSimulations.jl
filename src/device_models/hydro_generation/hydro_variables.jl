function activepowervariables(ps_m::canonical_model, devices::Array{H,1}, time_range::UnitRange{Int64}) where {H <: PowerSystems.HydroGen}

    add_variable(ps_m, devices, time_range, "Phy", expression = "var_active")

end

function reactivepowervariables(ps_m::canonical_model, devices::Array{H,1}, time_range::UnitRange{Int64}) where {H <: PowerSystems.HydroGen}

    add_variable(ps_m, devices, time_range, "Qhy", expression = "var_reactive")

end