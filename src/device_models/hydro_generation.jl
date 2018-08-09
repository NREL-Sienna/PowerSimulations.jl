function activepowervariables(m::JuMP.Model, devices_netinjection::A, devices::Array{T,1}, time_periods::Int64) where {A <: JumpExpressionMatrix, T <: PowerSystems.HydroGen}

    on_set = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    phy = @variable(m, phy[on_set,t]) # Power output of generators

    devices_netinjection = varnetinjectiterate!(devices_netinjection,  phy, t, devices)

    return phy, devices_netinjection

end

"""
This function adds the power limits of  hydro generators when there are no CommitmentVariables
"""
function powerconstraints(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.HydroCurtailment

    phy = m[:phy]
    time_index = m[:phy].axes[2]
    name_index = m[:phy].axes[1]

    (length(phy.axes[2]) != time_periods) ? error("Length of time dimension inconsistent"): true

    pmax_thermal = JuMP.JuMPArray(Array{ConstraintRef}(length.(indices(phy))), name_index, time_index)
    pmin_thermal = JuMP.JuMPArray(Array{ConstraintRef}(length.(indices(phy))), name_index, time_index)

    for t in phy.axes[2], (ix, name) in enumerate(phy.axes[1])
        if name == devices[ix].name
            pmin_hg[name, t] = @constraint(m, phy[name, t] >= 0.0)
            pmax_hg[name, t] = @constraint(m, phy[name, t] <= devices[ix].tech.realpowerlimits.max * devices[ix].scalingfactor.values[t])
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :pmax_hydro, pmax_hg)
    JuMP.registercon(m, :pmin_hydro, pmin_hg)

    return m

end
