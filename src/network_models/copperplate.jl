function CopperPlateNetwork(m::JuMP.Model, NetInjection::Array{JuMP.AffExpr}, tp)
    @constraintref cpn[1:tp]
    for t in 1:tp
        # TODO: Check is sum() is the best way to do this. Update in JuMP 0.19 to append!()
        cpn[t] = @constraint(m, sum(Nets[:,t]) == 0)
    end

    return true
end