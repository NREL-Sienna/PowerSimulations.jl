function copper_plate(ps_m::CanonicalModel, expr_name::String, bus_count::Int64, time_range::UnitRange{Int64})

    devices_netinjection = _remove_undef!(ps_m.expressions["$(expr_name)"])

    ps_m.constraints["CopperPlateBalance"] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, time_range)

    for t in time_range
        ps_m.constraints["CopperPlateBalance"][t] = JuMP.@constraint(ps_m.JuMPmodel, sum(ps_m.expressions["$(expr_name)"][1:bus_count,t]) == 0)
    end

end

