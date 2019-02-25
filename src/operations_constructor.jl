function buildmodel!(op_model::PowerOperationModel, sys::PSY.PowerSystem; kwargs...)

    #TODO: Add check model spec vs data functions before trying to build

    # Create Empty Canonical Model

    # Do Initial Conditions

    # Build Devices

    # Build Network. Step 1 network, Step 2 build Branches as devices

    # Build Services

    # Objective Function




    for category in op_model.generation
        construct_device!(op_model.model, netinjection, category.device,
        category.formulation, op_model.transmission, sys; kwargs...)
    end

    if op_model.demand != nothing
        for category in op_model.demand
            construct_device!(op_model.model, netinjection, category.device,
            category.formulation, op_model.transmission, sys; kwargs...)
        end
    end

    #= for category in op_model.storage
        op_model.model = construct_device!(category.device, network_model, op_model.model,
        devices_netinjection, sys, category.constraints)
    end =# if op_model.services != nothing
        service_providers = Array{NamedTuple{(:device,
        :formulation),Tuple{DataType,DataType}}}([]) [push!(service_providers,x) for x in
        vcat(op_model.generation,op_model.demand,op_model.storage) if x != nothing] for
        service in op_model.services
            op_model.model = constructservice!(op_model.model, service.service,
            service.formulation, service_providers, sys; kwargs...)
        end
    end

    constructnetwork!(op_model.model, op_model.branches, netinjection,
    op_model.transmission, sys; args..., PTDF = op_model.ptdf)

    JuMP.@objective(op_model.model, Min, op_model.model.obj_dict[:objective_function])

   return op_model

end