function construct_services!(canonical::Canonical,
                             sys::PSY.System,
                             services_template;
                             kwargs...)

    services = PSY.get_components(S, sys)
    _add_nodal_expressions(canonical, services, sys)
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
        push!(dict[typeof(d)], d)
    end
    return  [(k, v) for (k, v) in dict]
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
