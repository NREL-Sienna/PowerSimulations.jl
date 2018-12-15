function activepowervariables(ps_m::canonical_model, devices::Array{H,1}, time_range::UnitRange{Int64}) where {H <: PowerSystems.HydroGen}

    add_variable(ps_m, devices, time_range, "Phy", false, "var_active")

end

function reactivepowervariables(ps_m::canonical_model, devices::Array{H,1}, time_range::UnitRange{Int64}) where {H <: PowerSystems.HydroGen}

    add_variable(ps_m, devices, time_range, "Qhy", false, "var_reactive")

end

"""
This function add the variables for power generation commitment to the model
"""
function commitmentvariables(ps_m::canonical_model, devices::Array{H,1}, time_range::UnitRange{Int64}) where {H <: PowerSystems.HydroGen}

    add_variable(ps_m, devices, time_range, "on_hy", true)
    add_variable(ps_m, devices, time_range, "start_hy", true)
    add_variable(ps_m, devices, time_range, "stop_hy", true)

end