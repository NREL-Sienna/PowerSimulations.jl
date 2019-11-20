function build_op_problem!(op_problem::OperationsProblem{M}; kwargs...) where M<:AbstractOperationsProblem
    sys = get_system(op_problem)
    _build!(op_problem.canonical, op_problem.template, sys; kwargs...)
    return
end

function _build!(canonical::Canonical, template::OperationsTemplate, sys::PSY.System; kwargs...)
    verbose = get(kwargs, :verbose, true)
    transmission = template.transmission
    # Build Injection devices
    for device_model in values(template.devices)
        verbose && @info "Building $(device_model.device_type) with $(device_model.formulation) formulation"
        construct_device!(canonical, sys, device_model, transmission; kwargs...)
    end

    # Build Network
    verbose && @info "Building $(transmission) network formulation"
    construct_network!(canonical, sys, transmission; kwargs...)

    # Build Branches
    for branch_model in values(template.branches)
        verbose && @info "Building $(branch_model.device_type) with $(branch_model.formulation) formulation"
        construct_device!(canonical, sys, branch_model, transmission; kwargs...)
    end

    #Build Services
    construct_services!(canonical, sys, template.services; kwargs...)

    # Objective Function
    verbose && @info "Building Objective"
    JuMP.@objective(canonical.JuMPmodel, MOI.MIN_SENSE, canonical.cost_function)

    return

end
