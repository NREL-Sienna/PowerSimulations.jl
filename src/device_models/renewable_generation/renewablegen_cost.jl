function variablecost(m::JuMP.Model, devices::Array{PowerSystems.RenewableCurtailment,1}, device_formulation::Type{D}, system_formulation::Type{S}) where {D <: AbstractRenewablelDispatchForm, S <: PM.AbstractPowerFormulation}

    p_re = m[:p_re]
    time_index = m[:p_re].axes[2]
    name_index = m[:p_re].axes[1]

    var_cost = JuMP.AffExpr()

    for  (ix, name) in enumerate(name_index)
        if name == devices[ix].name
            c = PowerSimulations.gencost(m, p_re[name,:], devices[ix].econ.curtailpenalty)
        else
            error("Bus name in Array and variable do not match")
        end
            (isa(var_cost,JuMP.AffExpr) && isa(c,JuMP.AffExpr)) ? JuMP.add_to_expression!(var_cost,c) : (isa(var_cost,JuMP.GenericQuadExpr) && isa(c,JuMP.GenericQuadExpr) ? JuMP.add_to_expression!(var_cost,c) : var_cost += c)
    end

    return var_cost

end
