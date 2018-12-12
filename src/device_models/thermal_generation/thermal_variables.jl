### Variables for Thermal Generation ####

"""
This function add the variables for power generation output to the model
"""
function activepowervariables(ps_m::canonical_model, devices::Array{T,1}, time_periods::Int64) where {T <: PowerSystems.ThermalGen}

    on_set = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    ps_m.variables["P_th"] = @variable(ps_m.JuMPmodel, [on_set,t], start = 0.0, base_name="Pth", container = DenseAxisArray) # Power output of generators

end

"""
This function add the variables for power generation output to the model
"""
function reactivepowervariables(ps_m::canonical_model, devices::Array{T,1}, time_periods::Int64) where {T <: PowerSystems.ThermalGen}

    on_set = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    ps_m.variables["Q_th"] = @variable(ps_m.JuMPmodel, [on_set,t], start = 0.0, base_name="Qth", container = DenseAxisArray) # Power output of generators

end

"""
This function add the variables for power generation commitment to the model
"""

function commitmentvariables(ps_m::canonical_model, devices::Array{T,1}, time_periods::Int64) where {T <: PowerSystems.ThermalGen}

    on_set = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    ps_m.variables["on_th"]  = @variable(ps_m.JuMPmodel, [on_set,t], Bin, container = DenseAxisArray) # Power output of generators
    ps_m.variables["start_th"]  = @variable(ps_m.JuMPmodel, [on_set,t], Bin, container = DenseAxisArray) # Power output of generators
    ps_m.variables["stop_th"]  = @variable(ps_m.JuMPmodel, [on_set,t], Bin, container = DenseAxisArray) # Power output of generators

end