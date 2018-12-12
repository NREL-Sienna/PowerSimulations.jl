### Variables for Thermal Generation ####

"""
This function add the variables for power generation output to the model
"""
function activepowervariables(ps_m::canonical_model, devices::Array{T,1}, time_range::UnitRange{Int64}) where {T <: PowerSystems.ThermalGen}

    add_variable(ps_m, devices, time_range, "Pth"; expression = "var_active")

end

"""
This function add the variables for power generation output to the model
"""
function reactivepowervariables(ps_m::canonical_model, devices::Array{T,1}, time_range::UnitRange{Int64}) where {T <: PowerSystems.ThermalGen}

    add_variable(ps_m, devices, time_range, "Qth"; expression = "var_active")

end

"""
This function add the variables for power generation commitment to the model
"""
function commitmentvariables(ps_m::canonical_model, devices::Array{T,1}, time_range::UnitRange{Int64}) where {T <: PowerSystems.ThermalGen}

    add_variable(ps_m, devices, time_range, "on_th", true)
    add_variable(ps_m, devices, time_range, "start_th", true)
    add_variable(ps_m, devices, time_range, "stop_th", true)

end