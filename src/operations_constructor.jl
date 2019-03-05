function _ps_model_init(system::PSY.PowerSystem, optimizer::Union{Nothing,JuMP.OptimizerFactory}, transmission::Type{S}, time_periods::Int64) where {S <: PM.AbstractPowerFormulation}

    if isa(optimizer,Nothing)
        @info("The optimization model has no optimizer attached")
    end

    bus_count = length(system.buses)

    ps_model = CanonicalModel(JuMP.Model(optimizer),
                            Dict{String, JuMP.Containers.DenseAxisArray}(),
                            Dict{String, JuMP.Containers.DenseAxisArray}(),
                            nothing,
                            Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, bus_count, time_periods),
                                                                        "var_reactive" => PSI.JumpAffineExpressionArray(undef, bus_count, time_periods)),
                            Dict{String,Any}(),
                            nothing);

    return ps_model

end

function _ps_model_init(system::PSY.PowerSystem, optimizer::Union{Nothing,JuMP.OptimizerFactory}, transmission::Type{S}) where {S <: PM.AbstractActivePowerFormulation}

    if isa(optimizer,Nothing)
        @info("The optimization model has no optimizer attached")
    end

    bus_count = length(system.buses)

    ps_model = CanonicalModel(JuMP.Model(optimizer),
                            Dict{String, JuMP.Containers.DenseAxisArray}(),
                            Dict{String, JuMP.Containers.DenseAxisArray}(),
                            nothing,
                            Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, bus_count, time_periods)),
                            Dict{String,Any}(),
                            nothing);

        return ps_model

end

function build_op_model!(transmission::Type{T},
                         devices::Dict{String, DeviceModel},
                         branches::Dict{String, DeviceModel},
                         services::Dict{String, DataType},
                         system::PSY.PowerSystem,
                         optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing;
                         kwargs...) where {T <: PM.AbstractPowerFormulation}

    time_range = 1:system.time_periods
    ps_model = _ps_model_init(system, optimizer, transmission, system.time_periods)


    # Build Injection devices

    #for mod in devices
        #construct_device!(op_model.model, netinjection, device.device, device.formulation, op_model.transmission, sys; kwargs...)
    #end

    # Build Network

    #construct_network!(op_model.model, op_model.branches, op_model.transmission, sys, time_range)

    #=
    # Build Branches

    for device in op_model.generation
    construct_device!(op_model.model, netinjection, device.device,
    device.formulation, op_model.transmission, sys; kwargs...)
    end


    #Build Services
    for ervice in op_model.services
    constructservice!(op_model.model, service.service, service.formulation, service_providers, sys; kwargs...)
    end

    # Objective Function

    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)
    =#

end