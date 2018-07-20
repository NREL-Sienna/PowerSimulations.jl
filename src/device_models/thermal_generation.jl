
### Variables for Thermal Generation ####

"""
This function add the variables for power generation output to the model
"""
function generationvariables(m::JuMP.Model, devices_netinjection::A, devices::Array{T,1}, time_periods::Int64) where {A <: PowerExpressionArray, T <: PowerSystems.ThermalGen}
    on_set = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    pth = @variable(m::JuMP.Model, pth[on_set,t]) # Power output of generators

    varnetinjectiterate!(devices_netinjection,  pth, t, devices)

    return pth, devices_netinjection
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

include("thermal_generation/powerlimits_constraints.jl")
include("thermal_generation/ramping_constraints.jl")
include("thermal_generation/unitcommitment_constraints.jl")