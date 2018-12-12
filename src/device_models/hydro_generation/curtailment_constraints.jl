"""
This function adds the power limits of  hydro generators when there are no CommitmentVariables
"""
function powerconstraints(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.HydroCurtailment

    phy = m[:phy]
    time_index = m[:phy].axes[2]
    name_index = m[:phy].axes[1]

    (length(phy.axes[2]) != time_periods) ? @error("Length of time dimension inconsistent") : true

    pmax_th = JuMP.Containers.DenseAxisArray(Array{ConstraintRef}(length.(JuMP.axes(phy))), name_index, time_index)
    pmin_th = JuMP.Containers.DenseAxisArray(Array{ConstraintRef}(length.(JuMP.axes(phy))), name_index, time_index)

    for t in phy.axes[2], (ix, name) in enumerate(phy.axes[1])
        if name == devices[ix].name
            pmin_hg[name, t] = @constraint(m, phy[name, t] >= 0.0)
            pmax_hg[name, t] = @constraint(m, phy[name, t] <= devices[ix].tech.activepowerlimits.max * values(devices[ix].scalingfactor)[t])
        else
            @error "Bus name in Array and variable do not match"
        end
    end

    JuMP.register_object(m, :pmax_hydro, pmax_hg)
    JuMP.register_object(m, :pmin_hydro, pmin_hg)

    return m

end
