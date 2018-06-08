
# TODO: Change the types in T from generator to Thermal 

"""
This function add the variables for power generation output to the model
"""
function GenerationVariables(m::JuMP.Model, devices::Array{T,1}, Time) where T <: Generator 
    on_set = [d.name for d in devices if d.status == true]
    t = 1:Time
    @variable(m::JuMP.Model, P_th[on_set,t]) # Power output of generators
    return true    
end

"""
This function add the variables for power generation commitment to the model
"""
function CommitmentVariables(m::JuMP.Model, devices::Array{T,1}, Time) where T <: Generator 
    on_set = [d.name for d in devices if d.status == true]
    t = 1:Time
    @variable(m::JuMP.Model, on_th[on_set,t], Bin) # Power output of generators
    @variable(m::JuMP.Model, start_th[on_set,t], Bin) # Power output of generators
    @variable(m::JuMP.Model, stop_th[on_set,t], Bin) # Power output of generators
    return true    
end

"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function PowerConstraints(m::JuMP.Model, P_th, devices::Array{T,1}, Time) where T <: Generator 

    (length(P_th.indexsets[2]) != Time) ? error("Length of time dimension inconsistent"): true
    for (ix, name) in enumerate(P_th.indexsets[1])
            if name == devices[ix].name
                for t in P_th.indexsets[2]
                    @constraint(m, P_th[name, t] >= devices[ix].tech.realpowerlimits.min)
                    @constraint(m, P_th[name, t] <= devices[ix].tech.realpowerlimits.max)
                end    
            else
                error("Bus name in Array and variable do not match")
            end
    end
    return true
end

"""
This function adds the power limits of generators when there are CommitmentVariables
"""
function PowerConstraints(m::JuMP.Model, P_th, on_th, devices::Array{T,1}, Time) where T <: Generator 

    (length(P_th.indexsets[2]) != Time) ? error("Length of time dimension inconsistent"): true
    for (ix, name) in enumerate(P_th.indexsets[1])
            if name == devices[ix].name
                for t in P_th.indexsets[2]
                    @constraint(m, P_th[name, t] >= devices[ix].tech.realpowerlimits.min*on_th[name,t])
                    @constraint(m, P_th[name, t] <= devices[ix].tech.realpowerlimits.max*on_th[name,t])
                end    
            else
                error("Bus name in Array and variable do not match")
            end
    end
    return true
end
