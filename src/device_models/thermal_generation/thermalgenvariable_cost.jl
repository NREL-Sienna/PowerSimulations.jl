function variablecost(m::JuMP.Model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}) where {T <: PowerSystems.ThermalGen, D <: AbstractThermalDispatchForm, S <: PM.AbstractPowerFormulation}

    p_th = m[:p_th]
    time_index = m[:p_th].axes[2]
    name_index = m[:p_th].axes[1]

    var_cost = JuMP.AffExpr()

    for  (ix, name) in enumerate(name_index)
        if name == devices[ix].name
            c = gencost(m, p_th[name,:], devices[ix].econ.variablecost)
        else
            error("Bus name in Array and variable do not match")
        end
            (isa(var_cost,JuMP.AffExpr) && isa(c,JuMP.AffExpr)) ? JuMP.add_to_expression!(var_cost,c) : (isa(var_cost,JuMP.GenericQuadExpr) && isa(c,JuMP.GenericQuadExpr) ? JuMP.add_to_expression!(var_cost,c) : var_cost += c)
    end

    return var_cost

end

function gencost(m::JuMP.Model, variable::JuMPArray{JuMP.VariableRef}, cost_component::Function)

    store = Array{JuMP.AbstractJuMPScalar,1}(undef,length(variable.axes[1]))

    for (ix, element) in enumerate(variable)
        store[ix] = cost_component(element)
    end

    gen_cost = sum(store)

    return gen_cost

end

function gencost(m::JuMP.Model, variable::JuMPArray{JuMP.VariableRef}, cost_component::Float64)

    gen_cost = @expression(m, sum(cost_component*variable))

    return gen_cost

end

function pwlgencost(m::JuMP.Model, variable::VariableRef, cost_component::Array{Tuple{Float64, Float64}})

    pwlvars = @variable(m, [i = 1:(length(cost_component)-1)], basename = "pwl_{$(variable)}", lower_bound = 0.0, upper_bound = (cost_component[i+1][1] - cost_component[i][1]))

    @constraint(m, sum(pwlvars) == variable)

    coefficients = [c[2]/c[1] for c in cost_component[2:end]]

    # TODO: Check for performance this syntax, the changes in GenericAffExpr might require refactoring

    gen_cost = AffExpr()

    for (ix, variable) in enumerate(pwlvars)

        gen_cost = JuMP.add_to_expression!(gen_cost,coefficients[ix]*variable)

    end

    return gen_cost
end

function gencost(m::JuMP.Model, variable::JuMPArray{JuMP.VariableRef}, cost_component::Array{Tuple{Float64, Float64}})

    gen_cost = JuMP.AffExpr()

    for var in variable
        c = pwlgencost(m, var, cost_component)
        JuMP.add_to_expression!(gen_cost,c)
    end

    return gen_cost

end