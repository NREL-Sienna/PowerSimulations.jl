

function constructservice!(m::JuMP.Model, service::PowerSystems.StaticReserve, category_formulation::Type{RampLimitedReserve}, sys::PowerSystems.PowerSystem; args...)

    dev_set = all_devices(sys,[gen.name for gen in service.contributingdevices])

    if !isempty(dev_set)

        p_rsv =  reservevariables(m, dev_set, sys.time_periods)
        m =  reserves(m, dev_set, service, sys.time_periods)

    end

    return m

end