##################################################################################################
function nodal_expression(canonical_model::CanonicalModel,
                         devices,
                         system_formulation::Type{S}) where {S<:PM.AbstracPowerModel}



    if model_has_parameters(canonical_model)
        _nodal_expression_param(canonical_model, devices, system_formulation)
    else
        _nodal_expression_fixed(canonical_model, devices, system_formulation)
    end

    return

end
