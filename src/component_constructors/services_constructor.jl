

function constructservice!(m::JuMP.Model, service::PowerSystems.StaticReserve, sys::PowerSystems.PowerSystem; args...)

    dev_set = all_devices(sys,[gen.name for gen in service.contributingdevices])
#=
    P_max = [gen.tech.activepowerlimits.max for gen in qf]
    R_max = [(gen.tech.ramplimits != nothing  ? gen.tech.ramplimits.up : gen.tech.activepowerlimits.max ) for gen in qf]

    srp = JuMP.JuMPArray(Array{ConstraintRef}(undef,sys.time_periods), 1:sys.time_periods) #static reserve provision
    srr = JuMP.JuMPArray(Array{ConstraintRef}(undef,sys.time_periods), 1:sys.time_periods) #static reserve ramp

    for t in 1:sys.time_periods
        # TODO: check the units of ramplimits
        srp[t] = @constraint(m, sum([P_max[ix] - get_pg(m,g,t) for (ix,g) in enumerate(qf)]) >= service.requirement)
        srr[t] = @constraint(m, sum([get_pg(m,g,t) + R_max[ix]/60 * service.timeframe for (ix,g) in enumerate(qf)]) >= service.requirement)

    end

    JuMP.registercon(m, :StaticReserveProvision, srp)
    JuMP.registercon(m, :StaticReserveRamp, srr)
=#


    if !isempty(dev_set)

        p_rsv =  reservevariables(m, dev_set, sys.time_periods)
        print(typeof(dev_set))
        m =  reserves(m, dev_set, service, sys.time_periods)

    end

    return m

end