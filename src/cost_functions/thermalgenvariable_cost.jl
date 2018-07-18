function variablecost(m::JuMP.Model, pth::PowerVariable, devices::Array{T}) where T <: PowerSystems.ThermalGen

    cost = JuMP.AffExpr()

    for  (ix, name) in enumerate(pth.indexsets[1])
        if name == devices[ix].name
            c = gencost(m, pth[name,:], devices[ix].econ.variablecost)
        else
            error("Bus name in Array and variable do not match")
        end
            (isa(cost,JuMP.AffExpr) && isa(c,JuMP.AffExpr)) ? append!(cost,c) : (isa(cost,JuMP.GenericQuadExpr) && isa(c,JuMP.GenericQuadExpr) ? append!(cost,c) : cost += c)
    end

    return cost

end

function gencost(m::JuMP.Model, variable::Array{JuMP.Variable,1}, cost_component::Function)

    # TODO: Make type stable later, now it can return AffExpr or GenericQuadExpr

    total = [cost_component(e) for e in variable]

    cost = @expression(m, sum(total))

    return cost

end

function pwlgencost(m::JuMP.Model, var::JuMP.Variable, cost_component::Array{Tuple{Float64, Float64}})

    pwlvars = @variable(m, [i = 1:(length(cost_component)-1)], basename = "{pwl{$(var)}}", lowerbound = 0.0, upperbound = (cost_component[i+1][1] - cost_component[i][1]))
    @constraint(m, sum(pwlvars) == var)

    cost = JuMP.GenericAffExpr(pwlvars, [c[2]/c[1] for c in cost_component[2:end]], 0.0)

    return cost
end

function gencost(m::JuMP.Model, variable::Array{JuMP.Variable,1}, cost_component::Array{Tuple{Float64, Float64}})

    cost = JuMP.AffExpr()

    for var in variable
        c = pwlgencost(m, var, cost_component)
        append!(cost,c)
    end

    return cost

end