function activepower_variables(ps_m::CanonicalModel, devices::Array{H,1}, time_range::UnitRange{Int64}) where {H <: PSY.HydroGen}

    add_variable(ps_m, devices, time_range, "Phy", false, "var_active")

    return nothing

end

function reactivepower_variables(ps_m::CanonicalModel, devices::Array{H,1}, time_range::UnitRange{Int64}) where {H <: PSY.HydroGen}

    add_variable(ps_m, devices, time_range, "Qhy", false, "var_reactive")

    return nothing

end

"""
This function add the variables for power generation commitment to the model
"""
function commitment_variables(ps_m::CanonicalModel, devices::Array{H,1}, time_range::UnitRange{Int64}) where {H <: PSY.HydroGen}

    add_variable(ps_m, devices, time_range, "on_hy", true)
    add_variable(ps_m, devices, time_range, "start_hy", true)
    add_variable(ps_m, devices, time_range, "stop_hy", true)

    return nothing

end