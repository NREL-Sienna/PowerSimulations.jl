function GenerationVariables(m::JuMP.Model, devices::Array{T,1}, time_steps) where T <: HydroGen
    on_set = [d.name for d in devices if d.status == true]
    t = 1:time_steps
    @variable(m::JuMP.Model, phg[on_set,t]) # Power output of generators
    return phg    
end