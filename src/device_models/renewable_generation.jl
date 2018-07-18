function generationvariables(m::JuMP.Model, devices_netinjection:: A, devices::Array{T,1}, time_periods) where {A <: PowerExpressionArray, T <: PowerSystems.RenewableGen}

    on_set = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    pre = @variable(m::JuMP.Model, pre[on_set,t]) # Power output of generators

    devices_netinjection = varnetinjectiterate!(devices_netinjection,  pre, t, devices)

    return pre, devices_netinjection
end

"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function powerconstraints(m::JuMP.Model, pre::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.RenewableCurtailment

    (length(pre.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true

    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])

    @constraintref Pmax_re[1:length(pre.indexsets[1]),1:length(pre.indexsets[2])]
    @constraintref Pmin_re[1:length(pre.indexsets[1]),1:length(pre.indexsets[2])]

    for t in pre.indexsets[2], (ix, name) in enumerate(pre.indexsets[1])
        if name == devices[ix].name
            Pmin_re[ix, t] = @constraint(m, pre[name, t] >= 0.0)
            Pmax_re[ix, t] = @constraint(m, pre[name, t] <= devices[ix].tech.installedcapacity*devices[ix].scalingfactor.values[t])
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :PmaxRenewable, Pmax_re)
    JuMP.registercon(m, :PminRenewable, Pmin_re)

    return m
end
