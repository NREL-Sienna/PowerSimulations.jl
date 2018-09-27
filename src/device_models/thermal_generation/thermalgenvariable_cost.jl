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