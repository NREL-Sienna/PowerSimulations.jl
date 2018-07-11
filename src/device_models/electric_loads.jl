function loadvariables(m::JuMP.Model, devices::Array{T,1}, time_periods) where T <: ElectricLoad
    on_set = [d.name for d in devices if d.available == true && !isa(d, StaticLoad)]
    t in 1:time_periods
    @variable(m::JuMP.Model, pcl[on_set,t] >= 0.0) # Power output of generators
    return pcl
end

"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function powerconstraints(m::JuMP.Model, pcl::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: ElectricLoad
    (length(pcl.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])
    @constraintref Pmax_cl[1:length(pcl.indexsets[1]),1:length(pcl.indexsets[2])]
    for t in pcl.indexsets[2], (ix, name) in enumerate(pcl.indexsets[1])
        if name == devices[ix].name
            Pmax_cl[ix, t] = @constraint(m, pcl[name, t] <= devices[ix].maxrealpower*devices[ix].scalingfactor.values[t])
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :LoadControlLimit, Pmax_cl)

    return m
end
