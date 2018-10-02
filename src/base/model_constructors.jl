function buildmodel!(sys::PowerSystems.PowerSystem, op_model::PowerSimulationsModel)

    #TODO: Add check model spec vs data functions before trying to build

    op_model.psmodel = JuMP.Model()

    netinjection = instantiate_network(op_model.network, sys)

    for category in op_model.generation
        constructdevice!(op_model.psmodel, netinjection, category.device, category.formulation, op_model.transmission, sys)
    end


    for category in op_model.demand
        constructdevice!(op_model.psmodel, netinjection, category.device, category.formulation, op_model.transmission, sys)
    end

    #=
    for category in model.storage
        model.psmodel = constructdevice!(category.device, network_model, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    for category in model.services
        model.psmodel = constructservice!(category.service, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    =#

    constructnetwork!(op_model.psmodel, op_model.branches, netinjection, op_model.transmission, op_model.branches, sys)

    @objective(model.psmodel, Min, op_model.psmodel.obj_dict[:objective_function])

   return op_model

end

