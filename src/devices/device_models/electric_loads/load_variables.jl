function activepower_variables(ps_m::CanonicalModel, devices::Array{L,1}, time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad}

    add_variable(ps_m, devices, time_range, :Pel, false, :var_active, -1)

    return

end

function reactivepower_variables(ps_m::CanonicalModel, devices::Array{L,1}, time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad}

    add_variable(ps_m, devices, time_range, :Qel, false, :var_reactive, -1)

    return

end
