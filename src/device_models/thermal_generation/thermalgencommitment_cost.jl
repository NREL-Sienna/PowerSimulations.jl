function commitmentcost(m::JuMP.AbstractModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}) where {T <: PSY.ThermalGen, D <: AbstractThermalCommitmentForm, S <: PM.AbstractPowerFormulation}

    on_th = m[:on_th]
    start_th = m[:start_th]
    stop_th = m[:stop_th]

    name_index = m[:on_th].axes[1]

    commit_cost = JuMP.AffExpr()

    for (ix, name) in enumerate(name_index)
        if name == devices[ix].name

                if devices[ix].econ.startupcost > 0

                    JuMP.add_to_expression!(commit_cost,sum(start_th[name,:])*devices[ix].econ.startupcost)

                end

                if devices[ix].econ.shutdncost > 0

                    JuMP.add_to_expression!(commit_cost,sum(stop_th[name,:])*devices[ix].econ.shutdncost)

                end

                if devices[ix].econ.fixedcost > 0

                    JuMP.add_to_expression!(commit_cost,sum(on_th[name,:])*devices[ix].econ.fixedcost)

                end
        else
            @error "Bus name in Array and variable do not match"
        end
    end

    return commit_cost

end