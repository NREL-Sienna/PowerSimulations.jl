function variablecost(m::JuMP.Model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}) where {T <: PowerSystems.ThermalGen, D <: AbstractThermalDispatchForm, S <: PM.AbstractPowerFormulation}

    p_th = m[:p_th]
    time_index = m[:p_th].axes[2]
    name_index = m[:p_th].axes[1]

    cost = JuMP.AffExpr()

    for  (ix, name) in enumerate(name_index)
        if name == devices[ix].name
            c = gencost(m, p_th[name,:], devices[ix].econ.variablecost)
        else
            error("Bus name in Array and variable do not match")
        end
            (isa(cost,JuMP.AffExpr) && isa(c,JuMP.AffExpr)) ? JuMP.add_to_expression!(cost,c) : (isa(cost,JuMP.GenericQuadExpr) && isa(c,JuMP.GenericQuadExpr) ? JuMP.add_to_expression!(cost,c) : cost += c)
    end

    return cost

end

function gencost(m::JuMP.Model, variable::JuMPArray{JuMP.VariableRef}, cost_component::Function)

    # TODO: Make type stable later, now it can return AffExpr or GenericQuadExpr

    total = [cost_component(e) for e in variable]

    cost = @expression(m, sum(total))

    return cost

end

function gencost(m::JuMP.Model, variable::JuMPArray{JuMP.VariableRef}, cost_component::Float64)

    # TODO: Make type stable later, now it can return AffExpr or GenericQuadExpr

    cost = @expression(m, sum(cost_component*variable))

    return cost

end

function pwlgencost(m::JuMP.Model, var::JuMPArray{JuMP.VariableRef}, cost_component::Array{Tuple{Float64, Float64}})

    pwlvars = @variable(m, [i = 1:(length(cost_component)-1)], basename = "{pwl{$(var)}}", lowerbound = 0.0, upperbound = (cost_component[i+1][1] - cost_component[i][1]))
    @constraint(m, sum(pwlvars) == var)

    cost = JuMP.GenericAffExpr(pwlvars, [c[2]/c[1] for c in cost_component[2:end]], 0.0)

    return cost
end

function gencost(m::JuMP.Model, variable::JuMPArray{JuMP.VariableRef}, cost_component::Array{Tuple{Float64, Float64}})

    cost = JuMP.AffExpr()

    for var in variable
        c = pwlgencost(m, var, cost_component)
        JuMP.add_to_expression!(cost,c)
    end

    return cost

end