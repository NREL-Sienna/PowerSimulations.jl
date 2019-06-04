##################################################################################################
function nodal_expression(ps_m::CanonicalModel,
                         devices,
                         system_formulation::Type{S}) where {S <: PM.AbstractPowerFormulation}                         

                             

    if model_with_parameters(ps_m)
        _nodal_expression_param(ps_m, devices, system_formulation)
    else
        _nodal_expression_fixed(ps_m, devices, system_formulation)
    end

    return

end
