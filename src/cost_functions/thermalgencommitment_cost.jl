function commitmentcost(start::JuMP.JuMPArray{JuMP.Variable}, stop::JuMP.JuMPArray{JuMP.Variable}, status::JuMP.JuMPArray{JuMP.Variable}, generators::Array{ThermalGen})

    cost = 0.0;

    for (ix, name) in enumerate(status.indexsets[1])
        if name == generators[ix].name
            for time in status.indexsets[2]

                if generators[ix].econ.startupcost > 0

                    cost = cost + cost(start[string(name),time], generators[ix].econ.startupcost)

                end

                if generators[ix].econ.shutdncost > 0

                    cost = cost + cost(stop[string(name),time], generators[ix].econ.shutdncost)

                end

                if generators[ix].econ.fixedcost > 0

                    cost = cost + cost(status[string(name),time], generators[ix].econ.fixedcost)

                end


            end
        else
            error("Bus name in Array and variable do not match")
        end
    end

    return cost

end