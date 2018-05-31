function BranchFlowVariables(m::JuMP.Model, devices::Array{T,1}, T) where T <: Branch
    on_set = [d.name for d in devices if d.status == true]
    t = 1:PowerSystem.timesteps
    @variable(m, f_br[on_set,t])
    return true   
end