function variablecostre(P_re::JuMP.JuMPArray{JuMP.Variable}, Device::Array{RenewableCurtailment})

    cost = 0.0;

    for (ix, name) in enumerate(P_re.indexsets[1])
        if name == loads[ix].name
            for time in P_l.indexsets[2]
                cost = cost + loadcost(P_l[string(name),time], Device[ix].sheddingcost)
            end
        else
            error("Bus name in Array and variable do not match")
        end
    end

    return cost

end

function loadcost(X::JuMP.Variable, cost_component::Float64)

    return cost = X*cost_component
end