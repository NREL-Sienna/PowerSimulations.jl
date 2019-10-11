function build_op_model!(op_model::OperationModel{M}; kwargs...) where M<:AbstractOperationModel

    verbose = get(kwargs, :verbose, true)
    transmission = get_transmission_ref(op_model)

    #Build Service
    for mod in services
        verbose && @info "Building $(mod[2].service) with $(mod[2].formulation) formulation"
        construct_service!(canonical, mod[2], T, sys; kwargs...)
    end

    # Build Injection devices
    for (_, device_model) in op_model.model_ref.devices
        verbose && @info "Building $(device_model.device) with $(device_model.formulation) formulation"
        construct_device!(op_model, device_model, transmission; kwargs...)
    end

    # Build Network
    verbose && @info "Building $(transmission) network formulation"
    construct_network!(op_model, transmission; kwargs...)

    # Build Branches
    for (_, branch_model) in op_model.model_ref.branches
        verbose && @info "Building $(branch_model.device) with $(branch_model.formulation) formulation"
        construct_device!(op_model, branch_model, transmission; kwargs...)
    end

    # Objective Function
    verbose && @info "Building Objective"
    JuMP.@objective(op_model.canonical.JuMPmodel,
                    MOI.MIN_SENSE,
                    op_model.canonical.cost_function)

    return

end
