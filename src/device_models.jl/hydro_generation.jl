
function LoadVariables(m::JuMP.Model, devices::Array{T,1}, T) where T <: DispatchHydro
    on_set = [d.name for d in devices if d.status == true]
    t = 1:T
    @variable(m::JuMP.Model, P_hg[on_set,t]) # Power output of generators
    return true    
end