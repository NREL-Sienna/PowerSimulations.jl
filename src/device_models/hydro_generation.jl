function generationvariables(m::JuMP.Model, devices_netinjection:: A, devices::Array{T,1}, time_periods::Int64) where {A <: PowerExpressionArray, T <: PowerSystems.HydroGen}

    on_set = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    phy = @variable(m::JuMP.Model, phy[on_set,t]) # Power output of generators

    devices_netinjection = varnetinjectiterate!(devices_netinjection,  phy, t, devices)

    return phy, devices_netinjection

end

"""
This function adds the power limits of  hydro generators when there are no CommitmentVariables
"""
function powerconstraints(m::JuMP.Model, phy::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.HydroCurtailment
    (length(phy.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true

    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])

    @constraintref pmax_hg[1:length(phy.indexsets[1]),1:length(phy.indexsets[2])]
    @constraintref pmin_hg[1:length(phy.indexsets[1]),1:length(phy.indexsets[2])]

    for t in phy.indexsets[2], (ix, name) in enumerate(phy.indexsets[1])
        if name == devices[ix].name
            pmin_hg[ix, t] = @constraint(m, phy[name, t] >= 0.0)
            pmax_hg[ix, t] = @constraint(m, phy[name, t] <= devices[ix].tech.realpowerlimits.max * devices[ix].scalingfactor.values[t])
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :pmax_hydro, pmax_hg)
    JuMP.registercon(m, :pmin_hydro, pmin_hg)

    return m

end
