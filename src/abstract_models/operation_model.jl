abstract type AbstractOperationsModel end

mutable struct PowerOperationModel{M <: AbstractOperationsModel,
                                   T <: PM.AbstractPowerFormulation}
    op_model::Type{M}
    transmission::Type{T}
    devices::Dict{String, DeviceModel}
    branches::Dict{String, DeviceModel}
    services::Dict{String, DataType}
    system::PSY.PowerSystem
    canonical_model::PSI.CanonicalModel


    function PowerOperationModel(op_model::Type{M},
                                transmission::Type{T},
                                devices::Dict{String, DeviceModel},
                                branches::Dict{String, DeviceModel},
                                services::Dict{String, DataType},
                                system::PSY.PowerSystem,
                                optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing;
                                kwargs...) where {M <: AbstractOperationsModel,
                                                  T <: PM.AbstractPowerFormulation}

        if isa(optimizer,Nothing)
            @info("The optimization model has no optimizer attached")
        end

        bus_count = length(system.buses)

        ps_model = CanonicalModel(JuMP.Model(optimizer),
                                Dict{String, JuMP.Containers.DenseAxisArray}(),
                                Dict{String, JuMP.Containers.DenseAxisArray}(),
                                nothing,
                                Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, bus_count, system.time_periods),
                                                                            "var_reactive" => PSI.JumpAffineExpressionArray(undef, bus_count, system.time_periods)),
                                Dict{String,Any}(),
                                nothing);

        new{M, T}(op_model,
                transmission,
                devices,
                branches,
                services,
                system,
                ps_model)


    end

    function PowerOperationModel(op_model::Type{M},
                                transmission::Type{T},
                                devices::Dict{String, DeviceModel},
                                branches::Dict{String, DeviceModel},
                                services::Dict{String, DataType},
                                system::PSY.PowerSystem,
                                optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing;
                                kwargs...) where {M <: AbstractOperationsModel,
                                                  T <: PM.AbstractActivePowerFormulation}

        if isa(optimizer,Nothing)
            @info("The optimization model has no optimizer attached")
        end

        bus_count = length(system.buses)

        ps_model = CanonicalModel(JuMP.Model(optimizer),
                                Dict{String, JuMP.Containers.DenseAxisArray}(),
                                Dict{String, JuMP.Containers.DenseAxisArray}(),
                                nothing,
                                Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, bus_count, system.time_periods)),
                                Dict{String,Any}(),
                                nothing);

        new{M, T}(op_model,
                transmission,
                devices,
                branches,
                services,
                system,
                ps_model)

    end

    function PowerOperationModel(op_model::Type{M},
                                transmission::Type{StandardPTDFModel},
                                devices::Dict{String, DeviceModel},
                                branches::Dict{String, DeviceModel},
                                services::Dict{String, DataType},
                                system::PSY.PowerSystem,
                                optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing;
                                kwargs...) where {M <: AbstractOperationsModel}

        if isa(optimizer,Nothing)
            @info("The optimization model has no optimizer attached")
        end

        bus_count = length(system.buses)


        ps_model = CanonicalModel(JuMP.Model(optimizer),
            Dict{String, JuMP.Containers.DenseAxisArray}(),
            Dict{String, JuMP.Containers.DenseAxisArray}(),
            nothing,
            Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, bus_count, system.time_periods)),
            Dict{String,Any}(),
            nothing);

            new{M, StandardPTDFModel}(op_model,
                                            transmission,
                                            devices,
                                            branches,
                                            services,
                                            system,
                                            ps_model)

    end

    function PowerOperationModel(op_model::Type{M},
                                transmission::Type{CopperPlatePowerModel},
                                devices::Dict{String, DeviceModel},
                                branches::Dict{String, DeviceModel},
                                services::Dict{String, DataType},
                                system::PSY.PowerSystem,
                                optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing;
                                kwargs...) where {M <: AbstractOperationsModel}

        if isa(optimizer,Nothing)
            @info("The optimization model has no optimizer attached")
        end

        bus_count = length(system.buses)


        ps_model = CanonicalModel(JuMP.Model(optimizer),
                                Dict{String, JuMP.Containers.DenseAxisArray}(),
                                Dict{String, JuMP.Containers.DenseAxisArray}(),
                                nothing,
                                Dict{String, PSI.JumpAffineExpressionArray}("var_active" => PSI.JumpAffineExpressionArray(undef, bus_count, system.time_periods)),
                                Dict{String,Any}(),
                                nothing);

        new{M, CopperPlatePowerModel}(op_model,
                                            transmission,
                                            devices,
                                            branches,
                                            services,
                                            system,
                                            ps_model)

    end


end

##### JuMP methods overloading
JuMP.Model(optimizer::Nothing; kwargs...) = JuMP.Model(kwargs...)