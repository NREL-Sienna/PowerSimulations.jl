function construct_service!(canonical::Canonical,sys::PSY.System,
                            model::ServiceModel{S, Sr},
                            ::Type{T};
                            kwargs...) where {S<:PSY.Service,
                                              Sr<:AbstractServiceFormulation,
                                              T<:PM.AbstractPowerModel}


    services = PSY.get_components(S, sys)
    _add_nodal_expressions(canonical,services,sys)
    for service in services
        for (type_device,devices) in _get_devices_bytype(PSY.get_contributingdevices(service))
            #Variables
            activereserve_variables!(canonical, service, devices)

            #Constraints
            activereserve_constraints!(canonical, service, devices, Sr)

        end
        service_balance_constraint!(canonical,service)
    end
    return

end

function _get_devices_bytype(devices::IS.FlattenIteratorWrapper{T}) where {T<:PSY.ThermalGen}

    dict = Dict{DataType,Vector}()
    device_type_pairs = [(typeof(d),d) for d in devices]
    for d in devices
        push!(dict[typeof(d)],d)
    end
    return  [(k,v) for (k,v) in dict]
end

function _add_nodal_expressions!(canonical::Canonical,
                                S::IS.FlattenIteratorWrapper{SR},
                                sys::PSY.System) where {SR<:PSY.Service}

    V = JuMP.variable_type(canonical.JuMPmodel)
    parameters = model_has_parameters(canonical)
    time_steps = model_time_steps(canonical)
    for service in S
        name = Symbol(PSY.get_name(service),"_","balance")
        add_expression(canonical,
                    name, 
                    _make_container_array(V, parameters, time_steps))
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
