function CopperPlateNetwork(m::JuMP.Model, sys, flows, tp)
    devices = sys.network.branches
    @constraintref cpn[1:tp]
    on_set = [d.name for d in devices if d.available == true]
    for t in 1:tp
        cpn[t] = @constraint(m, sum(flows[i, t] for i in on_set) == 0)
    end

    return true
end
