function construct_service!(ps_m::CanonicalModel,
                            service::Type{SD},
                            service_formulation::Type{SV},
                            system_formulation::Type{S},
                            sys::PSY.System,
                            time_range::UnitRange{Int64};
                            kwargs...) where {SD <: PSY.Service,
                                              SV <: AbstractServiceFormulation,
                                              S <:  PM.AbstractPowerFormulation}

    return

end


#=

##################
This code still need to be rewritten for the new infrastructure in PowerSimulations
##################


function get_devices(sys::PSY.System,device::Type{PSY.ThermalGen})
    return sys.generators.thermal
end
function get_devices(sys::PSY.System,device::Type{PSY.RenewableGen})
    return sys.generators.renewable
end
function get_devices(sys::PSY.System,device::Type{PSY.HydroGen})
    return sys.generators.hydro
end
function get_devices(sys::PSY.System,device::Type{PSY.PSY.ElectricLoad})
    return sys.loads
end


function construct_service!(m::JuMP.AbstractModel, service::PSY.StaticReserve, device_formulation::Type{RampLimitedReserve},devices::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, sys::PSY.System; kwargs...)

    dev_set = Array{NamedTuple{(:device,:formulation),Tuple{PSY.Device,DataType}}}([])

    for device in devices
        if device != nothing
            D = get_devices(sys,device.device)
            for d in D
                if d in service.contributingdevices
                    push!(dev_set,(device=d,formulation=device.formulation))
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