function build_op_model!(op_model::OperationModel{M}; kwargs...) where M<:AbstractOperationModel
    sys = get_system(op_model)
    _build_canonical!(op_model.canonical, op_model.model_ref, sys; kwargs...)
    return
end

function _build_canonical!(canonical::CanonicalModel, ref::ModelReference, sys::PSY.System; kwargs...)

    verbose = get(kwargs, :verbose, true)
    transmission = ref.transmission

    # Build Injection devices
    for (_, device_model) in ref.devices
        verbose && @info "Building $(device_model.device) with $(device_model.formulation) formulation"
        construct_device!(canonical, sys, device_model, transmission; kwargs...)
    end

    # Build Network
    verbose && @info "Building $(transmission) network formulation"
    construct_network!(canonical, sys, transmission; kwargs...)

    # Build Branches
    for (_, branch_model) in ref.branches
        verbose && @info "Building $(branch_model.device) with $(branch_model.formulation) formulation"
        construct_device!(canonical, sys, branch_model, transmission; kwargs...)
    end

    #Build Service
    for mod in services
        construct_service!(canonical, mod[2].service, mod[2].formulation, devices, T, sys; kwargs...)
    end

    # Objective Function
    verbose && @info "Building Objective"
    JuMP.@objective(canonical.JuMPmodel,
                    MOI.MIN_SENSE,
                    canonical.cost_function)

    return

end
