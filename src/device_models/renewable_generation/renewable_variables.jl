function activepowervariables(ps_m::canonical_model, devices::Array{R,1}, time_range::UnitRange{Int64}) where {R <: PowerSystems.RenewableGen}

    add_variable(ps_m, devices, time_range, "Pre"; expression = "var_active")

end

function reactivepowervariables(ps_m::canonical_model, devices::Array{R,1}, time_range::UnitRange{Int64}) where {R <: PowerSystems.RenewableGen}

    add_variable(ps_m, devices, time_range, "Qre"; expression = "var_reactive")

end


