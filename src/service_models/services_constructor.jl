function construct_service!(canonical::CanonicalModel,
                            service::Type{SD},
                            service_formulation::Type{SV},
                            devices::Dict{Symbol, DeviceModel},
                            system_formulation::Type{S},
                            sys::PSY.System;
                            kwargs...) where {SD<:PSY.Service,
                                              SV<:AbstractServiceFormulation,
                                              S<:PM.AbstractPowerFormulation}
                                              
    sys_service = PSY.get_components(service, sys)
    for serv in sys_service 
        for mod in devices
            sys_devices = PSY.get_components(mod[2].device, sys)

            contributingdevices = filter(x -> x in serv.contributingdevices, collect(sys_devices))

            if validate_available_devices(contributingdevices, mod[2].device)
                return
            end

            #Variables
            activereserve_variables!(canonical_model, contributingdevices)

            #Constraints
            activereserve_constraints!(canonical_model, contributingdevices, mod[2].formulation, S)

            reserve_ramp_constraints!(canonical_model, contributingdevices,  mod[2].formulation, S)

        end
        buses = PSY.get_components(PSY.Bus, sys)
        bus_count = length(buses)
        _retrieve_forecasts(sys, PSY.StaticReserve)
        # Adding actual demand for that service by using the serv.service -> find the forecast
        copper_plate_reserve(canonical_model,:reserve_balance_active,bus_count) # based on type of reserve/service
    end

    return

end


#=

##################
This code still need to be rewritten for the new infrastructure in PowerSimulations
##################


function get_devices(sys::PSY.System, device::Type{PSY.ThermalGen})
    return sys.generators.thermal
end
function get_devices(sys::PSY.System, device::Type{PSY.RenewableGen})
    return sys.generators.renewable
end
function get_devices(sys::PSY.System, device::Type{PSY.HydroGen})
    return sys.generators.hydro
end
function get_devices(sys::PSY.System, device::Type{PSY.PSY.ElectricLoad})
    return sys.loads
end


function construct_service!(m::JuMP.AbstractModel, service::PSY.StaticReserve, device_formulation::Type{RampLimitedReserve}, devices::Array{NamedTuple{(:device, :formulation), Tuple{DataType, DataType}}}, sys::PSY.System; kwargs...)

    dev_set = Array{NamedTuple{(:device, :formulation), Tuple{PSY.Device, DataType}}}([])

    for device in devices
        if device != nothing
            D = get_devices(sys, device.device)
            for d in D
                if d in service.contributingdevices
                    push!(dev_set, (device=d, formulation=device.formulation))
                end
            end
        end
    end

    if !isempty(dev_set)

        p_rsv =  reservevariables!(m, dev_set, sys.time_periods)
        m =  reserves(m, dev_set, service, sys.time_periods)

    end

    return m

end
=#
