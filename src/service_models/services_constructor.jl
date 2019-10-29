function construct_service!(canonical::CanonicalModel,sys::PSY.System,
                            model::ServiceModel{S, Sr},
                            ::Type{T};
                            kwargs...) where {S<:PSY.Service,
                                              Sr<:AbstractServiceFormulation,
                                              T<:PM.AbstractPowerModel}


    services = PSY.get_components(S, sys)
    _add_nodal_expressions!(canonical,services,sys)
    _add_device_expression!(canonical, Symbol("activerange"), sys)
    _add_device_expression!(canonical, Symbol("ramp_up"), sys)
    for service in services
        
        #Variables
        activereserve_variables!(canonical, service)

        #Constraints
        activereserve_constraints!(canonical, service, Sr)

        reserve_ramp_constraints!(canonical,  service, Sr)

        #TODO: bulid the balance constraints elsewhere
        nodal_expression!(canonical,service, T)
        service_balance(canonical,service)
    end
    return

end

function _add_nodal_expressions!(canonical_model::CanonicalModel,
                                services::IS.FlattenIteratorWrapper{S},
                                sys::PSY.System) where {S<:PSY.Service}

    V = JuMP.variable_type(canonical_model.JuMPmodel)
    parameters = model_has_parameters(canonical_model)
    time_steps = model_time_steps(canonical_model)
    bus_numbers = sort([PSY.get_number(b) for b in PSY.get_components(PSY.Bus, sys)])
    for serv in services
        name = Symbol(serv.name,"_","balance")
        add_expression(canonical_model,
                    name, 
                    _make_container_array(V, parameters, bus_numbers, time_steps))
    end
    return 
end

function _add_device_expression!(canonical_model::CanonicalModel,
                                name ::Symbol,
                                sys::PSY.System) 
    
    expr = exp(canonical_model,name)
    if isnothing(expr)
        V = JuMP.variable_type(canonical_model.JuMPmodel)
        generators = [PSY.get_name(g) for g in PSY.get_components(PSY.Generator,sys)]
        parameters = model_has_parameters(canonical_model)
        time_steps = model_time_steps(canonical_model)

        add_expression(canonical_model,
                    name, 
                    _make_container_array(V, parameters, generators, time_steps))
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
