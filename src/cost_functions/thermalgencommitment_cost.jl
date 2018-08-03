function commitmentcost(m::JuMP.Model, start::JumpVariable, stop::JumpVariable, status::JumpVariable, generators::Array{T}) where T <: ThermalGen

    cost = JuMP.AffExpr()

    for (ix, name) in enumerate(status.axes[1])
        if name == generators[ix].name

                if generators[ix].econ.startupcost > 0

                    JuMP.add_to_expression!(cost,sum(start[string(name),:]*generators[ix].econ.startupcost))

                end

                if generators[ix].econ.shutdncost > 0

                    JuMP.add_to_expression!(cost,sum(stop[name,:]*generators[ix].econ.shutdncost))

                end

                if generators[ix].econ.fixedcost > 0

                    JuMP.add_to_expression!(cost,sum(status[name,:]*generators[ix].econ.fixedcost))

                end
        else
            error("Bus name in Array and variable do not match")
        end
    end

    return cost

end