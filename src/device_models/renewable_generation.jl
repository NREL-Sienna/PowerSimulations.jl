function GenerationVariables(m::JuMP.Model, devices::Array{T,1}, time_steps) where T <: RenewableGen
    on_set = [d.name for d in devices if d.available == true && !isa(d, RenewableFix)]
    t = 1:time_steps
    @variable(m::JuMP.Model, pre[on_set,t]) # Power output of generators
    return pre
end

"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function PowerConstraints(m::JuMP.Model, pre::PowerVariable, devices::Array{T,1}, time_periods::Int) where T <: RenewableCurtailment
    (length(pre.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])
    @constraintref Pmax_re[1:length(pre.indexsets[1]),1:length(pre.indexsets[2])]
    @constraintref Pmin_re[1:length(pre.indexsets[1]),1:length(pre.indexsets[2])]
    for (ix, name) in enumerate(pre.indexsets[1])
            if name == devices[ix].name
                for t in pre.indexsets[2]
                    Pmin_re[ix, t] = @constraint(m, pre[name, t] >= 0.0)
                    Pmax_re[ix, t] = @constraint(m, pre[name, t] <= devices[ix].tech.installedcapacity*devices[ix].scalingfactor.values[t])
                end
            else
                error("Bus name in Array and variable do not match")
            end
    end
    return true
end
