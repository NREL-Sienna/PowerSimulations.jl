function  _build_canonical(::Type{T},
                            devices::Dict{Symbol, DeviceModel},
                            branches::Dict{Symbol, DeviceModel},
                            services::Dict{Symbol, ServiceModel},
                            sys::PSY.System,
                            optimizer::Union{Nothing, JuMP.OptimizerFactory};
                            kwargs...) where {T<:PM.AbstractPowerFormulation}

    canonical = CanonicalModel(T, sys, optimizer; kwargs...)

    # Build Injection devices
    for mod in devices
        @info "Building $(mod[2].device) with $(mod[2].formulation) formulation"
        _internal_device_constructor!(canonical, mod[2].device, mod[2].formulation, T, sys; kwargs...)
    end

    # Build Network
    @info "Building $(T) network formulation"
    _internal_network_constructor(canonical, T, sys; kwargs...)

    # Build Branches
    for mod in branches
        @info "Building $(mod[2].device) with $(mod[2].formulation) formulation"
        _internal_device_constructor!(canonical, mod[2].device, mod[2].formulation, T, sys; kwargs...)
    end

    #Build Service
    for mod in services
        #construct_service!(canonical, mod[2].device, mod[2].formulation, T, sys, time_steps, resolution; kwargs...)
    end

    # Objective Function
    @info "Building Objective"
    JuMP.@objective(canonical.JuMPmodel, MOI.MIN_SENSE, canonical.cost_function)

    return canonical

end

function build_op_model!(op_model::OperationModel; kwargs...)

    optimizer = get(kwargs, :optimizer, nothing)

    op_model.canonical = _build_canonical(op_model.transmission,
                                          op_model.devices,
                                          op_model.branches,
                                          op_model.services,
                                          op_model.system,
                                          optimizer;
                                          kwargs...)

    return

end
