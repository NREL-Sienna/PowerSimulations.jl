function variablecost(pre::PowerVariable, devices::Array{T}) where T <: PowerSystems.RenewableGen

    cost = JuMP.AffExpr()

    for (ix, name) in enumerate(pre.indexsets[1])
        if name == devices[ix].name
                append!(cost,precost(pre[name,:], devices[ix]))
        else
            error("Bus name in Array and variable do not match")
        end
    end

    return cost

end

function precost(X::JuMP.Variable, device::Union{PowerSystems.RenewableCurtailment,PowerSystems.RenewableFullDispatch})

    return cost =sum(device.econ.curtailcost*(-X))
end