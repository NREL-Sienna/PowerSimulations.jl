function variablecost(m::JuMP.Model, pcl::JumpVariable, devices::Array{PowerSystems.InterruptibleLoad})

    cost = JuMP.AffExpr()

    for (ix, name) in enumerate(pcl.axes[1])
        if name == devices[ix].name
                JuMP.add_to_expression!(cost,cloadcost(pcl[name,:], devices[ix]))
        else
            error("Bus name in Array and variable do not match")
        end
    end

    return cost

end

function cloadcost(variable::Array{JuMP.VariableRef,1}, device::PowerSystems.InterruptibleLoad)

    return cost = sum(-1*device.sheddingcost*variable)

end