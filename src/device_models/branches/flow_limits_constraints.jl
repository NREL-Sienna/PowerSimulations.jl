function flowconstraints(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.Branch

    fbr = m[:fbr]
    name_index = m[:fbr].axes[1]
    time_index = m[:fbr].axes[2]

    (length(fbr.axes[2]) != time_periods) ? error("Length of time dimension inconsistent") : true

    Flow_max_tf = JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), name_index, time_index)
    Flow_max_ft = JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), name_index, time_index)

    for t in time_index, (ix, name) in enumerate(name_index)
        if name == devices[ix].name
            Flow_max_tf[ix, t] = @constraint(m, fbr[name, t] <= devices[ix].rate.to_from)
            Flow_max_ft[ix, t] = @constraint(m, fbr[name, t] >= -1*devices[ix].rate.from_to)
        else
            error("Branch name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :Flow_max_ToFrom, Flow_max_tf)
    JuMP.registercon(m, :Flow_max_FromTo, Flow_max_ft)

    return m
end
