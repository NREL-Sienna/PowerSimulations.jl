
function reservevariables(m::JuMP.Model, devices::Array{}, time_periods::Int64) where {A <: JumpExpressionMatrix}

    on_set = [d.name for d in devices]

    t = 1:time_periods

    p_rsv = @variable(m, p_rsv[on_set,t] >= 0)

    return p_rsv

end

function reserves(m::JuMP.Model, devices::Array{R,1}, service::PowerSystems.StaticReserve, time_periods::Int64) where {R <: PowerSystems.PowerSystemDevice}

    p_rsv = m[:p_rsv]
    time_index = m[:p_rsv].axes[2]
    name_index = m[:p_rsv].axes[1]

    (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

    P_max = [gen.tech.activepowerlimits.max for gen in devices] # this won't work for non-generators
    R_max = [(gen.tech.ramplimits != nothing  ? gen.tech.ramplimits.up : gen.tech.activepowerlimits.max ) for gen in devices]

    pmin_rsv = JuMP.JuMPArray(Array{ConstraintRef}(undef,length(time_index)), time_index) #minimum system reserve provision
    pmax_rsv = JuMP.JuMPArray(Array{ConstraintRef}(undef, length.(JuMP.axes(p_rsv))), name_index, time_index) #maximum generator reserve provision
    #pramp_rsv = JuMP.JuMPArray(Array{ConstraintRef}(undef, length.(JuMP.axes(p_rsv))), name_index, time_index) #maximum generator reserve provision


    for t in time_index
        # TODO: check the units of ramplimits
        pmin_rsv[t] = @constraint(m, sum([p_rsv[name,t] for name in name_index]) >= service.requirement)
        for (ix, name) in enumerate(name_index)
            if name == devices[ix].name
                pmax_rsv[name,t] = @constraint(m, get_pg(m,devices[ix],t) + p_rsv[name,t] <= P_max[ix])
                #pramp_rsv[name,t] = @constraint(m, p_rsv[name,t] <= R_max[ix] * service.timeframe)
            else
                error("Gen name in Array and variable do not match")
            end
        end

    end

    JuMP.registercon(m, :RsvProvisionMin, pmin_rsv)
    JuMP.registercon(m, :RsvProvisionMax, pmax_rsv)
    #JuMP.registercon(m, :RsvProvisionRamp, pramp_rsv)

    return m

end