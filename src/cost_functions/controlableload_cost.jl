function variablecost(m::JuMP.Model, pcl::PowerVariable, devices::Array{PowerSystems.InterruptibleLoad})

    cost = JuMP.AffExpr()

    for (ix, name) in enumerate(pcl.indexsets[1])
        if name == devices[ix].name
                append!(cost,cloadcost(pcl[name,:], devices[ix]))
        else
            error("Bus name in Array and variable do not match")
        end
    end

    return cost

end

function cloadcost(variable::Array{JuMP.Variable,1}, device::PowerSystems.InterruptibleLoad)

    return cost = sum(-1*device.sheddingcost*variable)

end