function build_op_problem!(op_problem::OperationsProblem{M}; kwargs...) where M<:AbstractOperationsProblem
    sys = get_system(op_problem)
    _build!(op_problem.psi_container, op_problem.template, sys; kwargs...)
    return
end

function _build!(psi_container::PSIContainer, template::OperationsProblemTemplate, sys::PSY.System; kwargs...)
    verbose = get(kwargs, :verbose, true)
    transmission = template.transmission

    # Order is required
    #Build Services
    construct_services!(psi_container, sys, template.services, template.devices; kwargs...)

    # Build Injection devices
    for device_model in values(template.devices)
        verbose && @info "Building $(device_model.device_type) with $(device_model.formulation) formulation"
        construct_device!(psi_container, sys, device_model, transmission; kwargs...)
    end

    # Build Network
    verbose && @info "Building $(transmission) network formulation"
    construct_network!(psi_container, sys, transmission; kwargs...)

    # Build Branches
    for branch_model in values(template.branches)
        verbose && @info "Building $(branch_model.device_type) with $(branch_model.formulation) formulation"
        construct_device!(psi_container, sys, branch_model, transmission; kwargs...)
    end

    # Objective Function
    verbose && @info "Building Objective"
    JuMP.@objective(psi_container.JuMPmodel, MOI.MIN_SENSE, psi_container.cost_function)

    return
end
