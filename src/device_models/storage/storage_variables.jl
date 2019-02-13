function activepower_variables(ps_m::CanonicalModel, devices::Array{T,1}, time_range::UnitRange{Int64}) where {T <: PSY.Storage}

    add_variable(ps_m, devices, time_range, "Psin", false,"var_active", -1)
    add_variable(ps_m, devices, time_range, "Psout", false, "var_active")

end

function reactivepower_variables(ps_m::CanonicalModel, devices::Array{T,1}, time_range::UnitRange{Int64}) where {T <: PSY.Storage}

    add_variable(ps_m, devices, time_range, "Qst", false, "var_reactive")

end

function energystoragevariables(ps_m::CanonicalModel, devices::Array{T,1}, time_range::UnitRange{Int64}) where T <: PSY.Storage

    add_variable(ps_m, devices, time_range, false, "Est")

end