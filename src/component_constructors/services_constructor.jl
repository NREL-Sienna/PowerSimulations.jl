function constructservice!(m::JuMP.Model, service::PowerSystems.StaticReserve, sys::PowerSystems.PowerSystem; args...)

    qualifying_units =[]

    for source in sys.generators

        if typeof(source) <: Array{<:PowerSystems.Generator}
    
            for gen in source
    
                gen.name in service.contributingdevices ? push!(qualifying_units,gen.name) : continue
    
            end

        end

    end

    srr = JuMP.JuMPArray(Array{ConstraintRef}(undef,sys.time_periods), 1:sys.time_periods)

    for t in 1:time_periods
        # TODO: Check is sum() is the best way to do this in terms of speed. 
        # TODO: this doesn't have the correct syntax to access the P_max, P_g, rampup values.
        srr[t] = @constraint(m, sum(minimum(P_max[qualifying_units] - P_g[qualifying_units,t],
                                            gen[qualifying_units].rampup/60 * service.timeframe)) >= service.requirement)
    end

    JuMP.registercon(m, :StaticReserveRequirement, srr)

    return m

end