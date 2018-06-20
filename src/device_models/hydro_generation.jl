function GenerationVariables(m::JuMP.Model, devices::Array{T,1}, time_steps) where T <: HydroGen
    on_set = [d.name for d in devices if d.available == true && !isa(d, HydroFix) ]
    t = 1:time_steps
    @variable(m::JuMP.Model, phg[on_set,t]) # Power output of generators
    return phg
end

"""
This function adds the power limits of  hydro generators when there are no CommitmentVariables
"""
function PowerConstraints(m::JuMP.Model, phg::PowerVariable, devices::Array{T,1}, time_periods::Int) where T <: HydroCurtailment
    (length(phg.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    @constraintref Pmax_hg[1:length(phg.indexsets[1]),1:length(phg.indexsets[2])]
    @constraintref Pmin_hg[1:length(phg.indexsets[1]),1:length(phg.indexsets[2])]
    for (ix, name) in enumerate(phg.indexsets[1])
            if name == devices[ix].name
                for t in phg.indexsets[2]
                    Pmin_hg[ix, t] = @constraint(m, phg[name, t] >= 0.0)
                    Pmax_hg[ix, t] = @constraint(m, phg[name, t] <= devices[ix].tech.realpowerlimits.max * devices[ix].scalingfactor.values[t])
                end
            else
                error("Bus name in Array and variable do not match")
            end
    end
    return true
end
