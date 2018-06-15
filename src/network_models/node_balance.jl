function BranchFlowVariables(m::JuMP.Model, devices::Array{T,1}, time_steps) where T <: Branch
    on_set = [d.name for d in devices if d.available == true]
    t = 1:time_steps
    @variable(m, fbr[on_set,t])
    return fbr
end

function CopperPlateNetwork(m::JuMP.Model, sys, flows, tp)
    devices = sys.network.branches
    @constraintref cpn[1:tp]
    on_set = [d.name for d in devices if d.available == true]
    for t in 1:tp
        cpn[t] = @constraint(m, sum(flows[i, t] for i in on_set) == 0)
    end

    return true
end

function KCLBalance(m, sys, fbr, pth, pcl, tp)
    @constraintref kcl[1:length(sys.buses), 1:tp]

    for (idx, b) in enumerate(sys.buses)
        # Branch Flows
        branches_from = [br.name for br in sys.network.branches if br.connectionpoints.from == b]
        branches_to = [br.name for br in sys.network.branches if br.connectionpoints.to == b]
        thermal = [th.name for th in sys.generators["Thermal"] if th.bus == b]
        loads = [cl.name for cl in sys.loads if cl.bus == b && !isa(cl, PowerSystems.StaticLoad)]

        for t = 1:tp

            # TODO: check for islanded buses
            isempty(branches_from) ? total_flows_from = 0.0 : total_flows_from = sum(fbr[i,t] for i in branches_from)
            isempty(branches_to) ? total_flows_to = 0.0 : total_flows_to = sum(fbr[i,t] for i in branches_to)

            isempty(thermal) ? total_th = 0.0 : total_th = sum(pth[i,t] for i in thermal)

            # isempty(renewable) ? total_re = 0.0 : total_re = sum(P_re[i,t] for i in renewable)
            # isempty(storage) ? total_st = 0.0 : total_st = sum(Pin[i,t] - Pout[i,t] for i in storage)
            # isempty(hydro) ? total_hy = 0.0 : total_hy = sum(Phy[i,t] for i in hydro)

            isempty(loads) ? total_cl = 0.0 : total_cl = sum(pcl[i,t] for i in loads)

            staticload = [sl.maxrealpower*sl.scalingfactor.values[t] for sl in sys.loads if sl.bus == b]

            isempty(staticload) ? total_staticload = 0.0 : total_staticload = sum(staticload)
            # FixedRenewables = sum([sl.maxrealpower*sl.scalingfactor.values[t] for sl in sys.loads if sl.bus == b && isa(sl, StaticLoad)])

            kcl[idx, t] = @constraint(m, total_flows_to - total_flows_from + total_th + total_cl - total_staticload == 0)

        end

    end

end

