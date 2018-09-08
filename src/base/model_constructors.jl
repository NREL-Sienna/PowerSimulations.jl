function buildmodel!(sys::PowerSystems.PowerSystem, model::PowerSimulationsModel)

    #TODO: Add check model spec vs data functions before trying to build 

    PSModel = JuMP.Model()

    netinjection = instantiate_network(model.network, sys)

    for category in model.generation
        netinjection = constructdevice!(category.device, category.formulation, model.transmission, model.psmodel, netinjection, sys)
    end

#=

    for category in model.demand
        model.psmodel = constructdevice!(category.device, network_model, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    for category in model.storage
        model.psmodel = constructdevice!(category.device, network_model, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    #Get Arrary with NetInjections from TimeSeries fields
    timeseries_nets = PowerSimulations.timeseries_netinjection(sys)

    #This function hasn't been created yet
    model.psmodel = constructnetwork!(model.transmission, model.branches, model.psmodel, timeseries_nets, devices_netinjection, sys; kwargs...)

    for category in model.services
        model.psmodel = constructservice!(category.service, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    #This function hasn't been created ye
    for caterogy in model.cost
        cost = constructcost(category.device, model.psmodel, sys, category.components)
    end

    @objective(model.psmodel, Min, cost);

    model.psmodel

    =#

    return model

end
