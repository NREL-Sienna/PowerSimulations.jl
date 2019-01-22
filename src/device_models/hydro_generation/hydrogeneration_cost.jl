function variablecost(phy::JumpVariable, devices::Array{T}) where T <: PSY.HydroGen

    cost = JuMP.AffExpr()

    for (ix, name) in enumerate(pre.axes[1])
        if name == devices[ix].name
                JuMP.add_to_expression!(cost,precost(phy[name,:], devices[ix]))
        else
            @error "Bus name in Array and variable do not match"
        end
    end

    return cost

end

function precost(X::JuMP.JuMP.VariableRef, device::Union{PSY.RenewableCurtailment,PSY.RenewableFullDispatch})

    return cost = sum(device.econ.curtailcost*(-X))

end