
function get_devices(sys::PowerSystems.PowerSystem,category::Type{PowerSystems.ThermalGen})
    return sys.generators.thermal
end
function get_devices(sys::PowerSystems.PowerSystem,category::Type{PowerSystems.RenewableGen})
    return sys.generators.renewable
end
function get_devices(sys::PowerSystems.PowerSystem,category::Type{PowerSystems.HydroGen})
    return sys.generators.hydro
end
function get_devices(sys::PowerSystems.PowerSystem,category::Type{PowerSystems.PowerSystems.ElectricLoad})
    return sys.loads
end


function constructservice!(m::JuMP.Model, service::PowerSystems.StaticReserve, category_formulation::Type{PS.RampLimitedReserve},devices::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, sys::PowerSystems.PowerSystem; args...)

    dev_set = Array{NamedTuple{(:device,:formulation),Tuple{PowerSystems.PowerSystemDevice,DataType}}}([])

    for category in devices
        if category != nothing
            D = get_devices(sys,category.device)
            for d in D
                if d in service.contributingdevices
                    push!(dev_set,(device=d,formulation=category.formulation))
                end
            end
        end
    end

    if !isempty(dev_set)

        p_rsv =  reservevariables(m, dev_set, sys.time_periods)
        m =  PS.reserves(m, dev_set, service, sys.time_periods)

    end

    return m

end