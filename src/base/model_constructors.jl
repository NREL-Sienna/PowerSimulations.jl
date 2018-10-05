function buildmodel!(op_model::PowerOperationModel)

    #TODO: Add check model spec vs data functions before trying to build

    netinjection = instantiate_network(op_model.transmission, op_model.system)

    for category in op_model.generation
        constructdevice!(op_model.model, netinjection, category.device, category.formulation, op_model.transmission, op_model.system)
    end


    for category in op_model.demand
        constructdevice!(op_model.model, netinjection, category.device, category.formulation, op_model.transmission, op_model.system)
    end

    #=
    for category in model.storage
        op_model.model = constructdevice!(category.device, network_model, op_model.model, devices_netinjection, op_model.system, category.constraints)
    end
    =#
    if op_model.services != nothing
        for category in op_model.services
            op_model.model = constructservice!(op_model.model, category, op_model.system)
        end
    end


    constructnetwork!(op_model.model, [(device=Branch, formulation=op_model.transmission)], netinjection, op_model.transmission, op_model.system)

    @objective(op_model.model, Min, op_model.model.obj_dict[:objective_function])

   return op_model

end

