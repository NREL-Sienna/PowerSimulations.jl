function  _build_canonical(::Type{T},
                            devices::Dict{Symbol, DeviceModel},
                            branches::Dict{Symbol, DeviceModel},
                            services::Dict{Symbol, ServiceModel},
                            sys::PSY.System,
                            optimizer::Union{Nothing, JuMP.OptimizerFactory},
                            verbose::Bool = true;
                            kwargs...) where {T<:PM.AbstracPowerModel}

    canonical = CanonicalModel(T, sys, optimizer; kwargs...)
    # Build Injection devices
    for (_, d) in devices
        verbose && @info "Building $(d.device) with $(d.formulation) formulation"
        _internal_device_constructor!(canonical, d, T, sys; kwargs...)
    end

    # Build Network
    verbose && @info "Building $(T) network formulation"
    _internal_network_constructor(canonical, T, sys; kwargs...)

    # Build Branches
    for mod in branches
        verbose && @info "Building $(mod[2].device) with $(mod[2].formulation) formulation"
        _internal_device_constructor!(canonical, mod[2], T, sys; kwargs...)
    end

    #Build Service
    for mod in services
        #construct_service!(canonical, mod[2].device, mod[2].formulation, T, sys, time_steps, resolution; kwargs...)
    end

    # Objective Function
    verbose && @info "Building Objective"
    JuMP.@objective(canonical.JuMPmodel, MOI.MIN_SENSE, canonical.cost_function)

    return canonical

end

function build_op_model!(op_model::OperationModel; kwargs...)

    verbose = get(kwargs, :verbose, true)
    optimizer = get(kwargs, :optimizer, nothing)

    op_model.canonical = _build_canonical(op_model.model_ref.transmission,
                                          op_model.model_ref.devices,
                                          op_model.model_ref.branches,
                                          op_model.model_ref.services,
                                          op_model.sys,
                                          optimizer,
                                          verbose;
                                          kwargs...)

    return

end
