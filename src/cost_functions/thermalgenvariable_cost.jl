function variablecostgen(pth::JuMP.JuMPArray{JuMP.Variable}, generators::Array{T}) where T <: PowerSystems.ThermalGen

    cost = 0.0;

    for (ix, name) in enumerate(pth.indexsets[1])
        if name == generators[ix].name
            for time in pth.indexsets[2]
                cost = cost + gencost(pth[string(name),time], generators[ix].econ.variablecost)
            end
        else
            error("Bus name in Array and variable do not match")
        end
    end

    return cost

end

function gencost(X::JuMP.Variable, cost_component::Real)

    return cost = X*cost_component
end

function gencost(X::JuMP.Variable, cost_component::Function)

    return cost_component(X)
end
