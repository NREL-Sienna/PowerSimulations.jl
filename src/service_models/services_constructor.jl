function construct_service!(canonical_model::CanonicalModel,
                            service::Type{SD},
                            service_formulation::Type{SV},
                            devices::Dict{Symbol, DeviceModel},
                            system_formulation::Type{S},
                            sys::PSY.System;
                            kwargs...) where {SD<:PSY.Service,
                                              SV<:AbstractServiceFormulation,
                                              S<:PM.AbstractPowerFormulation}
                                              
                                              
    for mod in devices
        devices = PSY.get_components(mod[2].device, sys)

        contributingdevices = filter(x -> x in service.contributingdevices, devices)

        if validate_available_devices(contributingdevices, mod[2].device)
            return
        end

        #Variables
        activereserve_variables!(canonical_model, contributingdevices)

        #Constraints
        activereserve_constraints!(canonical_model, contributingdevices, mod[2].formulation, S)

        reserve_ramp_constraints!(canonical_model, contributingdevices,  mod[2].formulation, S)
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

        p_rsv =  reservevariables(m, dev_set, sys.time_periods)
        m =  reserves(m, dev_set, service, sys.time_periods)

    end

    return m

end
=#
