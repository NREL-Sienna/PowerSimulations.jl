function variablecost(m::JuMP.Model, devices::Array{PowerSystems.RenewableCurtailment,1}, device_formulation::Type{D}, system_formulation::Type{S}) where {D <: AbstractRenewablelDispatchForm, S <: PM.AbstractPowerFormulation}

    p_re = m[:p_re]
    time_index = m[:p_re].axes[2]
    name_index = m[:p_re].axes[1]

    cost = JuMP.AffExpr()

    for (ix, name) in enumerate(name_index)
        if name == devices[ix].name
                JuMP.add_to_expression!(cost,precost(p_re[name,:], devices[ix]))
        else
            error("Bus name in Array and variable do not match")
        end
    end

    return cost

end

function precost(vars::Array{JuMP.VariableRef,1}, device::Union{PowerSystems.RenewableCurtailment,PowerSystems.RenewableFullDispatch})

    return cost =sum(device.econ.curtailpenalty*(-vars))

end