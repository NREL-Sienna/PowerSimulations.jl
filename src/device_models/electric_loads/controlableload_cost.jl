function variablecost(m::JuMP.AbstractModel, devices::Array{PSY.InterruptibleLoad,1}, device_formulation::Type{D}, system_formulation::Type{S}) where {D <: FullControllablePowerLoad, S <: PM.AbstractPowerFormulation}

    p_cl = m[:p_cl]
    time_index = m[:p_cl].axes[2]
    name_index = m[:p_cl].axes[1]

    var_cost = AffExpr()

    for  (ix, name) in enumerate(name_index)
         c = gencost(m, p_cl[name,:], -1*devices[ix].sheddingcost)
        JuMP.add_to_expression!(var_cost,c)
    end

    return var_cost

end
