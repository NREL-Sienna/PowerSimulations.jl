function commitmentcost(m::JuMP.Model, start::PowerVariable, stop::PowerVariable, status::PowerVariable, generators::Array{T}) where T <: ThermalGen

    cost = JuMP.AffExpr()

    for (ix, name) in enumerate(status.indexsets[1])
        if name == generators[ix].name

                if generators[ix].econ.startupcost > 0

                    append!(cost,sum(start[string(name),:]*generators[ix].econ.startupcost))

                end

                if generators[ix].econ.shutdncost > 0

                    append!(cost,sum(stop[name,:]*generators[ix].econ.shutdncost))

                end

                if generators[ix].econ.fixedcost > 0

                    append!(cost,sum(status[name,:]*generators[ix].econ.fixedcost))

                end
        else
            error("Bus name in Array and variable do not match")
        end
    end

    return cost

end