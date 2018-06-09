

function StorageVariables(m::JuMP.Model, devices::Array{T,1}, T) where T <: Storage
    on_set = [d.name for d in devices if d.status == true]
    t = 1:T
    @variable(m, P_st[on_set,t]) 
    return P_st              
end