function buildmodel!(sys::PowerSystems.PowerSystem, model::PowerSimulationsModel)

    #TODO: Add check model spec vs data functions before trying to build

    PSModel = JuMP.Model()

    netinjection = instantiate_network(model.network, sys)

    for category in model.generation
        constructdevice!(PSModel, netinjection, category.device, category.formulation, model.transmission, sys)
    end

    #=
        for category in model.demand
        model.psmodel = constructdevice!(category.device, network_model, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    for category in model.storage
        model.psmodel = constructdevice!(category.device, network_model, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    for category in model.services
        model.psmodel = constructservice!(category.service, model.psmodel, devices_netinjection, sys, category.constraints)
    end

   =#

   constructnetwork!(PSModel, netinjection, model.transmission, model.branches, sys)

   #=

    @objective(model.psmodel, Min, cost);

    model.psmodel

    =#

    return model

end
