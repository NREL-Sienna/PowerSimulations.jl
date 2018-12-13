function activepowervariables(ps_m::canonical_model, devices::Array{L,1}, time_range::UnitRange{Int64}) where {L <: PowerSystems.ElectricLoad}

    add_variable(ps_m, devices, time_range, "Pel", false, "var_active", -1)

end

function reactivepowervariables(ps_m::canonical_model, devices::Array{L,1}, time_range::UnitRange{Int64}) where {L <: PowerSystems.ElectricLoad}

    add_variable(ps_m, devices, time_range, "Qel", false, "var_reactive", -1)

end

