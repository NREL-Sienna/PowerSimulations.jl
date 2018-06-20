function NodePowerBalanceNetwork(m, sys, fbr, pth, pcl, tp)
    devices = sys.network.branches
    @constraintref flows[1:length(branches) 1:tp]

    on_set = [d.name for d in devices if d.available == true]

    for br in branches
        for t in 1:tp
            cpn[t] = @constraint(m, sum(flows[i, t] for i in on_set) == 0)
        end
    end

    return true

end