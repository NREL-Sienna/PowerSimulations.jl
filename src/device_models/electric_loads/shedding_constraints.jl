"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function powerconstraints(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ElectricLoad

    pcl = m[:pcl]
    time_index = m[:pcl].axes[2]
    name_index = m[:pcl].axes[1]

    (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

    pmax_cl = JuMP.JuMPArray(Array{ConstraintRef}(length.(indices(pcl))), name_index, time_index)
    for t in time_index, (ix, name) in enumerate(name_index)
        if name == devices[ix].name
            pmax_cl[name, t] = @constraint(m, pcl[name, t] <= devices[ix].maxrealpower*devices[ix].scalingfactor.values[t])
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :loadcontrollimit, pmax_cl)

    return m
end
