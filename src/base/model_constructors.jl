function buildmodel!(sys::PowerSystems.PowerSystem, model::PowerSimulationsModel)

    PSModel = JuMP.Model()
    devices_netinjection =  Array{JuMP.GenericAffExpr{Float64,JuMP.Variable},2}(length(sys.buses), sys.time_periods)

    for category in model.generation
        model.psmodel = constructdevice(category.device, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    for category in model.demand
        model.psmodel = constructdevice(category.device, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    for category in model.storage
        model.psmodel = constructdevice(category.device, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    for category in model.branches
        model.psmodel = constructdevice(category.service, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    for category in model.services
        model.psmodel = constructdevice(category.service, model.psmodel, devices_netinjection, sys, category.constraints)
    end

    #Get Arrary with NetInjections from TimeSeries fields
    timeseries_nets = PowerSimulations.timeseries_netinjection(sys)

    #This function hasn't been created yet
    model.psmodel = constructnetwork(model.transmission, model.psmodel, timeseries_nets, devices_netinjection, sys)


    #This function hasn't been created ye
    for caterogy in model.cost
        cost = constructcost(category.device, model.psmodel, sys, category.components)
    end

    @objective(model.psmodel, Min, cost);

    model.psmodel

    return model

end
