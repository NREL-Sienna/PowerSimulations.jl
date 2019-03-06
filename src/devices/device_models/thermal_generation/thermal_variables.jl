### Variables for Thermal Generation ####

"""
This function add the variables for power generation output to the model
"""
function activepower_variables(ps_m::CanonicalModel, devices::Array{T,1}, time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    add_variable(ps_m, devices, time_range, :Pth, false, :var_active)

    return

end

"""
This function add the variables for power generation output to the model
"""
function reactivepower_variables(ps_m::CanonicalModel, devices::Array{T,1}, time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    add_variable(ps_m, devices, time_range, :Qth, false, :var_reactive)

    return

end

"""
This function add the variables for power generation commitment to the model
"""
function commitment_variables(ps_m::CanonicalModel, devices::Array{T,1}, time_range::UnitRange{Int64}) where {T <: PSY.ThermalGen}

    add_variable(ps_m, devices, time_range, :on_th, true)
    add_variable(ps_m, devices, time_range, :start_th, true)
    add_variable(ps_m, devices, time_range, :stop_th, true)

    return

end

