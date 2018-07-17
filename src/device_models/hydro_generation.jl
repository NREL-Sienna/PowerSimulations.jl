function generationvariables(m::JuMP.Model, DevicesNetInjection::A, devices::Array{T,1}, time_periods) where {A <: PowerExpressionArray, T <: PowerSystems.HydroGen}

    on_set = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    phy = @variable(m::JuMP.Model, phy[on_set,t]) # Power output of generators

    DevicesNetInjection = varnetinjectiterate!(DevicesNetInjection, phy, t, devices)

    return phy, DevicesNetInjection

end

"""
This function adds the power limits of  hydro generators when there are no CommitmentVariables
"""
function powerconstraints(m::JuMP.Model, phy::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.HydroCurtailment
    (length(phy.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true

    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])

    @constraintref Pmax_hg[1:length(phy.indexsets[1]),1:length(phy.indexsets[2])]
    @constraintref Pmin_hg[1:length(phy.indexsets[1]),1:length(phy.indexsets[2])]

    for t in phy.indexsets[2], (ix, name) in enumerate(phy.indexsets[1])
        if name == devices[ix].name
            Pmin_hg[ix, t] = @constraint(m, phy[name, t] >= 0.0)
            Pmax_hg[ix, t] = @constraint(m, phy[name, t] <= devices[ix].tech.realpowerlimits.max * devices[ix].scalingfactor.values[t])
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :PmaxHydro, Pmax_hg)
    JuMP.registercon(m, :PminHydro, Pmin_hg)

    return m

end
