### Variables for Thermal Generation ####

"""
This function add the variables for power generation output to the model
"""
function activepowervariables(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where {A <: JumpExpressionMatrix, T <: PowerSystems.ThermalGen}
    
    on_set = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    pth = @variable(m, pth[on_set,t]) # Power output of generators

    return pth
end

"""
This function add the variables for power generation output to the model
"""
function reactivepowervariables(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where {A <: JumpExpressionMatrix, T <: PowerSystems.ThermalGen}
    
    on_set = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    qth = @variable(m, qth[on_set,t]) # Power output of generators

    return qth
end

"""
This function add the variables for power generation commitment to the model
"""
function commitmentvariables(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ThermalGen

    on_set = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    @variable(m, onth[on_set,t], Bin) # Power output of generators
    @variable(m, startth[on_set,t], Bin) # Power output of generators
    @variable(m, stopth[on_set,t], Bin) # Power output of generators

    return onth, startth, stopth
end