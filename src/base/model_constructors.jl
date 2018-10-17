function buildmodel!(sys::PowerSystems.PowerSystem, op_model::PowerOperationModel; args...)

    #TODO: Add check model spec vs data functions before trying to build

    netinjection = instantiate_network(op_model.transmission, sys)

    for category in op_model.generation
        constructdevice!(op_model.model, netinjection, category.device, category.formulation, op_model.transmission, sys; args...)
    end

    if op_model.demand != nothing
        for category in op_model.demand
            constructdevice!(op_model.model, netinjection, category.device, category.formulation, op_model.transmission, sys; args...)
        end
    end 

    #=
    for category in op_model.storage
        op_model.model = constructdevice!(category.device, network_model, op_model.model, devices_netinjection, sys, category.constraints)
    end
    =#
    if op_model.services != nothing
        service_providers = Array{NamedTuple{(:device, :formulation),Tuple{DataType,DataType}}}([])
        [push!(service_providers,x) for x in vcat(op_model.generation,op_model.demand,op_model.storage) if x != nothing]
        for service in op_model.services
            op_model.model = constructservice!(op_model.model, service.service, service.formulation, service_providers, sys; args...)
        end
    end


    constructnetwork!(op_model.model, op_model.branches, netinjection, op_model.transmission, sys; args..., PTDF = op_model.ptdf)

    @objective(op_model.model, Min, op_model.model.obj_dict[:objective_function])

   return op_model

end

