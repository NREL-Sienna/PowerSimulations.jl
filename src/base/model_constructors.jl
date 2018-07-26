function buildmodel!(sys::PowerSystems.PowerSystem, model::PowerSimulationsModel)

    PSModel = JuMP.Model()
    # TODO: this syntax might change with JuMP 0.19
    devices_netinjection =  Array{JuMP.GenericAffExpr{Float64,JuMP.Variable},2}(length(sys.buses), sys.time_periods)

    #Knowing the network model => create reactive power constraints or not.
    network_model = model.transmission.category

    for category in model.generation
        model.psmodel = constructdevice(category.device, network_model, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    for category in model.demand
        model.psmodel = constructdevice(category.device, network_model, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    for category in model.storage
        model.psmodel = constructdevice(category.device, network_model, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    #Get Arrary with NetInjections from TimeSeries fields
    timeseries_nets = PowerSimulations.timeseries_netinjection(sys)

    #This function hasn't been created yet
    model.psmodel = constructnetwork(model.transmission, model.branches, model.psmodel, timeseries_nets, devices_netinjection, sys; kwargs...)

    for category in model.services
        model.psmodel = constructservice(category.service, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    #This function hasn't been created ye
    for caterogy in model.cost
        cost = constructcost(category.device, model.psmodel, sys, category.components)
    end

    @objective(model.psmodel, Min, cost);

    model.psmodel

    return model

end
