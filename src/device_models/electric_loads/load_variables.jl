function activepowervariables(ps_m::canonical_model, devices::Array{L,1}, time_range::UnitRange{Int64}) where {L <: PowerSystems.ElectricLoad}

    add_variable(ps_m, devices, time_range, "Pel", expression = "var_active", sign = -1)

end

function reactivepowervariables(ps_m::canonical_model, devices::Array{L,1}, time_range::UnitRange{Int64}) where {L <: PowerSystems.ElectricLoad}

    add_variable(ps_m, devices, time_range, "Qel", expression = "var_reactive", sign = -1)

end

