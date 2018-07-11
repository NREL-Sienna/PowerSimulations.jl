function variablecost(pre::PowerVariable, devices::Array{T}) where T <: PowerSystems.RenewableGen

    cost = JuMP.AffExpr()

    for (ix, name) in enumerate(pre.indexsets[1])
        if name == devices[ix].name
            for t in pre.indexsets[2]
                append!(cost,precost(pre[name,t], devices[ix]))
            end
        else
            error("Bus name in Array and variable do not match")
        end
    end

    return cost

end

function precost(X::JuMP.Variable, device::Union{PowerSystems.RenewableCurtailment,PowerSystems.RenewableFullDispatch})

    return cost = device.econ.curtailcost*(-X)
end