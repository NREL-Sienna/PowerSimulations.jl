function _pass_abstract_jump(optimizer::Union{Nothing,JuMP.OptimizerFactory}; kwargs...)
    
    if isa(optimizer,Nothing)
        @info("The optimization model has no optimizer attached")
    end

    if :JuMPmodel in keys(kwargs)

        return kwargs[:JuMPmodel]

    end

    return JuMP.Model(optimizer)

end

function _ps_model_init(system::PSY.PowerSystem, optimizer::Union{Nothing,JuMP.OptimizerFactory}, transmission::Type{S}, time_periods::Int64; kwargs...) where {S <: PM.AbstractPowerFormulation}

    bus_count = length(system.buses)

    jump_model = _pass_abstract_jump(optimizer; kwargs...)
    V = JuMP.variable_type(jump_model)
    ps_model = CanonicalModel(jump_model,
                            Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                            Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                            nothing,
                            Dict{Symbol, PSI.JumpAffineExpressionArray{V}}(:var_active => PSI.JumpAffineExpressionArray{V}(undef, bus_count, time_periods),
                                                                        :var_reactive => PSI.JumpAffineExpressionArray{V}(undef, bus_count, time_periods)),
                            Dict{Symbol,Any}(),
                            nothing);
    
    return ps_model

end

function _ps_model_init(system::PSY.PowerSystem, optimizer::Union{Nothing,JuMP.OptimizerFactory}, transmission::Type{S}, time_periods::Int64; kwargs...) where {S <: PM.AbstractActivePowerFormulation}

    bus_count = length(system.buses)

    jump_model = _pass_abstract_jump(optimizer; kwargs...)
    V = JuMP.variable_type(jump_model)
    ps_model = CanonicalModel(jump_model,
                              Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                              Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                              nothing,
                              Dict{Symbol, PSI.JumpAffineExpressionArray{V}}(:var_active => PSI.JumpAffineExpressionArray{V}(undef, bus_count, time_periods)),
                              Dict{Symbol,Any}(),
                              nothing);

    return ps_model

end

function build_op_model!(transmission::Type{T},
                         devices::Dict{Symbol, DeviceModel},
                         branches::Dict{Symbol, DeviceModel},
                         services::Dict{Symbol, ServiceModel},
                         system::PSY.PowerSystem,
                         optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing;
                         kwargs...) where {T <: PM.AbstractPowerFormulation}

    time_range = 1:system.time_periods
    ps_model = _ps_model_init(system, optimizer, transmission, system.time_periods; kwargs...)
    
    # Build Injection devices 
    for mod in devices
        construct_device!(ps_model, mod[2], transmission, system, time_range; kwargs...)
    end

    # Build Network
    construct_network!(ps_model, transmission, system, time_range; kwargs...)

    # Build Branches    
    for mod in branches
        construct_device!(ps_model, mod[2], transmission, system, time_range; kwargs...)
    end    

    #Build Service
    for mod in services
        construct_service!(ps_model, mod[2], transmission, system, time_range; kwargs...)
    end

    # Objective Function
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)

    return ps_model
    
end            

function build_op_model!(op_model; optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing, kwargs...)
       op_model.canonical_model = build_op_model!(op_model.transmission, 
                                                    op_model.devices,
                                                    op_model.branches,
                                                    op_model.services,
                                                    op_model.system,
                                                    optimizer;
                                                    kwargs...)
        return nothing
end  