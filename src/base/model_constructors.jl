function buildmodel!(sys::PowerSystems.PowerSystem, op_model::PowerOperationModel)

    #TODO: Add check model spec vs data functions before trying to build

    netinjection = instantiate_network(op_model.transmission, sys)

    for category in op_model.generation
        constructdevice!(op_model.model, netinjection, category.device, category.formulation, op_model.transmission, sys)
    end


    for category in op_model.demand
        constructdevice!(op_model.model, netinjection, category.device, category.formulation, op_model.transmission, sys)
    end

    #=
    for category in model.storage
        model.model = constructdevice!(category.device, network_model, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    for category in model.services
        model.model = constructservice!(category.service, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    =#

    constructnetwork!(op_model.model, [(device=Branch, formulation=op_model.transmission)], netinjection, op_model.transmission, sys)

    @objective(op_model.model, Min, op_model.model.obj_dict[:objective_function])

   return op_model

end

