function activepowervariables(ps_m::CanonicalModel, devices::Array{R,1}, time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen}

    add_variable(ps_m, devices, time_range, "Pre", false, "var_active")

end

function reactivepowervariables(ps_m::CanonicalModel, devices::Array{R,1}, time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen}

    add_variable(ps_m, devices, time_range, "Qre", false, "var_reactive")

end


