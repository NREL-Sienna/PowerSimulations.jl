##################################################################################################

function nodal_expression(ps_m::CanonicalModel,
                            devices,
                            system_formulation::Type{S},
                            time_range::UnitRange{Int64},
                            parameters::Bool) where {S <: PM.AbstractPowerFormulation}

    if parameters
        _nodal_expression_param(ps_m, devices, system_formulation, time_range)
    else
        _nodal_expression_fixed(ps_m, devices, system_formulation, time_range)
    end

    return

end