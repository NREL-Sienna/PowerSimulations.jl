function activepower_variables(ps_m::CanonicalModel, devices::Array{R,1}, time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen}

    add_variable(ps_m, devices, time_range, :Pre, false, :var_active)

    return

end

function reactivepower_variables(ps_m::CanonicalModel, devices::Array{R,1}, time_range::UnitRange{Int64}) where {R <: PSY.RenewableGen}

    add_variable(ps_m, devices, time_range, :Qre, false, :var_reactive)

    return

end


