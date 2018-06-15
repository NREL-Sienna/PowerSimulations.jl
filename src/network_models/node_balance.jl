function BranchFlowVariables(m::JuMP.Model, devices::Array{T,1}, time_steps) where T <: Branch
    on_set = [d.name for d in devices if d.available == true]
    t = 1:time_steps
    @variable(m, fbr[on_set,t])
    return fbr
end

function KCLBalance(m, sys, fbr, pth, pre, pin, pout, phy, pcl)

    for b in sys.buses
        #Branch Flows
        branches_from = [br.name for br in sys5.network.branches if br.connectionpoints.from == b]
        branches_to = [br.name for br in sys5.network.branches if br.connectionpoints.to == b]
        thermal = [th.name for th in generators_th if th.bus == b]
        renewable = [re.name for re in generators_re if re.bus == b && !isa(d, RenewableFix)]
        hydro = [hy.name for re in generators_hy if re.bus == b && !isa(d,HydroFix)]
        loads = [cl.name for cl in ]

    for t = 1:5

        isempty(branches_from) ? error("bus is islanded, correct topology of the system") : total_flows_from = sum(fbr[i,t] for i in branches)

        isempty(branches_to) ? error("bus is islanded, correct topology of the system") : total_flows_to = sum(fbr[i,t] for i in branches)

        isempty(thermal) ? total_th = 0.0 : total_th = sum(P_th[i,t] for i in thermal)

        isempty(renewable) ? total_re = 0.0 : total_re = sum(P_re[i,t] for i in renewable)

        isempty(storage) ? total_st = 0.0 : total_st = sum(Pin[i,t] - Pout[i,t] for i in storage)

        isempty(hydro) ? total_hy = 0.0 : total_hy = sum(Phy[i,t] for i in hydro)

        isempty(load) ? total_cl = 0.0 : total_cl = sum(pcl[i,t] for i in loads)

        staticload = sum([sl.maxrealpower*sl.scalingfactor.values[t] for sl in sys5b.loads if sl.bus == b && isa(sl, StaticLoad)])

        FixedRenewables = sum([sl.maxrealpower*sl.scalingfactor.values[t] for sl in sys5b.loads if sl.bus == b && isa(sl, StaticLoad)])

        netload = renewable_fix + hydro_fix + static_load

        @constraint(m, sum_totals == netload )

    end





end