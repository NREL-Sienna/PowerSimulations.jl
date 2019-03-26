
function _canonical_model_init(bus_count::Int64,
                              optimizer::Union{Nothing,JuMP.OptimizerFactory},
                              transmission::Type{S},
                              time_periods::Int64; kwargs...) where {S <: PM.AbstractPowerFormulation}

    jump_model = _pass_abstract_jump(optimizer; kwargs...)
    V = JuMP.variable_type(jump_model)
    ps_model = CanonicalModel(jump_model,
                            Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                            Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                            zero(JuMP.GenericAffExpr{Float64, JuMP.variable_type(jump_model)}),
                            Dict{Symbol, JuMPPGAEArray{V}}(:var_active => JuMPPGAEArray{V}(undef, bus_count, time_periods),
                                                                        :var_reactive => JuMPPGAEArray{V}(undef, bus_count, time_periods)),
                            Dict{Symbol,Any}(),
                            Dict{Symbol,Array{InitialCondition}}(),
                            nothing);

    return ps_model

end

function _canonical_model_init(bus_count::Int64,
                               optimizer::Union{Nothing,JuMP.OptimizerFactory},
                               transmission::Type{S},
                               time_periods::Int64; kwargs...) where {S <: PM.AbstractActivePowerFormulation}



    jump_model = _pass_abstract_jump(optimizer; kwargs...)
    V = JuMP.variable_type(jump_model)
    ps_model = CanonicalModel(jump_model,
                              Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                              Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                              zero(JuMP.GenericAffExpr{Float64, JuMP.variable_type(jump_model)}),
                              Dict{Symbol, JuMPPGAEArray{V}}(:var_active => JuMPPGAEArray{V}(undef, bus_count, time_periods)),
                              Dict{Symbol,Any}(),
                              Dict{Symbol,Array{InitialCondition}}(),
                              nothing);

    return ps_model

end

function  build_canonical_model(transmission::Type{T},
                                devices::Dict{Symbol, DeviceModel},
                                branches::Dict{Symbol, DeviceModel},
                                services::Dict{Symbol, ServiceModel},
                                system::PSY.PowerSystem,
                                optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing;
                                kwargs...) where {T <: PM.AbstractPowerFormulation}

time_range = 1:system.time_periods
bus_count = length(system.buses)

ps_model = _canonical_model_init(bus_count, optimizer, transmission, system.time_periods; kwargs...)

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