function variablecost(m::JuMP.Model, pre::JumpVariable, devices::Array{T}) where T <: PowerSystems.RenewableGen

    cost = JuMP.AffExpr()

    for (ix, name) in enumerate(pre.axes[1])
        if name == devices[ix].name
                JuMP.add_to_expression!(cost,precost(pre[name,:], devices[ix]))
        else
            error("Bus name in Array and variable do not match")
        end
    end

    return cost

end

function precost(vars::Array{JuMP.VariableRef,1}, device::Union{PowerSystems.RenewableCurtailment,PowerSystems.RenewableFullDispatch})

    return cost =sum(device.econ.curtailpenalty*(-vars))

end