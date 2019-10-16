function build_op_model!(op_model::OperationModel{M}; kwargs...) where M<:AbstractOperationModel
    sys = get_system(op_model)
    _build_canonical(op_model.canonical, sys; kwargs...)
    return
end

function _build_canonical!(canonical::CanonicalModel, sys::PSY.System; kwargs...)

    verbose = get(kwargs, :verbose, true)
    transmission = get_transmission_ref(op_model)

    # Build Injection devices
    for (_, device_model) in op_model.model_ref.devices
        verbose && @info "Building $(device_model.device) with $(device_model.formulation) formulation"
        construct_device!(canonical, sys, device_model, transmission; kwargs...)
    end

    # Build Network
    verbose && @info "Building $(transmission) network formulation"
    construct_network!(canonical, sys, transmission; kwargs...)

    # Build Branches
    for (_, branch_model) in op_model.model_ref.branches
        verbose && @info "Building $(branch_model.device) with $(branch_model.formulation) formulation"
        construct_device!(canonical, sys, branch_model, transmission; kwargs...)
    end

    #Build Service
    for (_, service_model) in op_model.model_ref.services
        #construct_service!(canonical, sys, service_model, transmission; kwargs...)
    end

    # Objective Function
    verbose && @info "Building Objective"
    JuMP.@objective(op_model.canonical.JuMPmodel,
                    MOI.MIN_SENSE,
                    op_model.canonical.cost_function)

    return

end
