function LoadVariables(m::JuMP.Model, devices::Array{T,1}, time_steps) where T <: ElectricLoad
    on_set = [d.name for d in devices if d.status == true && !isa(d, StaticLoad)]
    t = 1:time_steps
    @variable(m::JuMP.Model, pcl[on_set,t] >= 0.0) # Power output of generators
    return pcl    
end

"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function PowerConstraints(m::JuMP.Model, pcl::JuMP.JuMPArray{JuMP.Variable,2,Tuple{Array{String,1},UnitRange{Int64}}}, devices::Array{T,1}, time_periods::Int) where T <: ElectricLoad
    (length(pcl.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    @constraintref Pmax_cl[1:length(pcl.indexsets[1]),1:length(pcl.indexsets[2])]
    for (ix, name) in enumerate(pcl.indexsets[1])
            if name == devices[ix].name
                for t in pcl.indexsets[2]
                    Pmax_cl[ix, t] = @constraint(m, pcl[name, t] <= devices[ix].maxrealpower*devices[ix].scalingfactor.values[t])
                end    
            else
                error("Bus name in Array and variable do not match")
            end
    end
    return true
end