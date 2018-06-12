function BranchFlowVariables(m::JuMP.Model, devices::Array{T,1}, time_steps) where T <: Branch
    on_set = [d.name for d in devices if d.status == true]
    t = 1:time_steps
    @variable(m, f_br[on_set,t])
    return f_br
end

