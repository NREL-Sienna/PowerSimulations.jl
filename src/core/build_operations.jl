function build_op_model!(op_model::OperationsProblem{M}; kwargs...) where M<:AbstractOperationsProblem
    sys = get_system(op_model)
    _build!(op_model.canonical, op_model.model_ref, sys; kwargs...)
    return
end

function _build!(canonical::Canonical, ref::FormulationTemplate, sys::PSY.System; kwargs...)

    verbose = get(kwargs, :verbose, true)
    transmission = ref.transmission

    # Build Injection devices
    for device_model in values(ref.devices)
        verbose && @info "Building $(device_model.device_type) with $(device_model.formulation) formulation"
        construct_device!(canonical, sys, device_model, transmission; kwargs...)
    end

    # Build Network
    verbose && @info "Building $(transmission) network formulation"
    construct_network!(canonical, sys, transmission; kwargs...)

    # Build Branches
    for branch_model in values(ref.branches)
        verbose && @info "Building $(branch_model.device_type) with $(branch_model.formulation) formulation"
        construct_device!(canonical, sys, branch_model, transmission; kwargs...)
    end

    #Build Service
    for service_model in values(ref.services)
        #construct_service!(canonical, sys, service_model, transmission; kwargs...)
    end

    # Objective Function
    verbose && @info "Building Objective"
    JuMP.@objective(canonical.JuMPmodel,
                    MOI.MIN_SENSE,
                    canonical.cost_function)

    return

end
