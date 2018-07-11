function variablecostload(pcl::JuMP.JuMPArray{JuMP.Variable}, loads::Array{InterruptibleLoad})

    cost = 0.0;

    for (ix, name) in enumerate(Pcl.indexsets[1])
        if name == loads[ix].name
            for time in P_l.indexsets[2]
                cost = cost + cloadcost(pcl[string(name),time], loads[ix].sheddingcost)
            end
        else
            error("Bus name in Array and variable do not match")
        end
    end

    return cost

end

function cloadcost(X::JuMP.Variable, cost_component::Float64)

    return cost = X*cost_component
end