##################################################################################################
function nodal_expression(ps_m::CanonicalModel,
                         devices,
                         system_formulation::Type{S},
                         parameters::Bool) where {S <: PM.AbstractPowerFormulation}                         

    if parameters
        _nodal_expression_param(ps_m, devices, system_formulation)
    else
        _nodal_expression_fixed(ps_m, devices, system_formulation)
    end

    return

end
