export VariableCost 

function VariableCost(P_g::JuMP.JuMPArray{JuMP.Variable}, generators::Array{ThermalGen})

    cost = 0.0;

    for (ix, name) in enumerate(P_g.indexsets[1])
        if name == generators[ix].name
            for time in P_g.indexsets[2]
                cost = cost + Cost(P_g[string(name),time], generators[ix].econ.variablecost)
            end
        else
            error("Bus name in Array and variable do not match")
        end
    end

    return cost

end

function Cost(X::JuMP.Variable, cost_component::Real) 

    return cost = X*cost_component
end

function Cost(X::JuMP.Variable, cost_component::Function)

    return cost_component(X)
end