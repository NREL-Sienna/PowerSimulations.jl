struct EconomicDispatch <: AbstractOperationsModel end
struct SCEconomicDispatch <: AbstractOperationsModel end

function EconomicDispatch(system::PSY.PowerSystem, transmission::Type{S}; optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing, kwargs...) where {S <: PM.AbstractPowerFormulation}

    devices = Dict{Symbol, PSI.DeviceModel}(:ThermalGenerators => PSI.DeviceModel(PSY.ThermalGen, PSI.ThermalDispatch),
                                            :RenewableGenerators => PSI.DeviceModel(PSY.RenewableGen, PSI.RenewableFullDispatch),
                                            :Loads => PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))

    branches = Dict{Symbol, PSI.DeviceModel}(:Lines => PSI.DeviceModel(PSY.Branch, PSI.SeriesLine))                                             
    services = Dict{Symbol, PSI.ServiceModel}(:Reserves => PSI.ServiceModel(PSY.Reserve, PSI.AbstractReservesForm))

    return PowerOperationModel(EconomicDispatch,
                                   transmission, 
                                    devices, 
                                    branches, 
                                    services,                                
                                    system,
                                    optimizer = optimizer; kwargs...)

end

function SCEconomicDispatch(system::PSY.PowerSystem; optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing, kwargs...)
    
    if :PTDF in keys(kwargs)

        PTDF = kwargs[:PTDF]

    else
        @info "PTDF matrix not provided. It will be constructed using PowerSystems.PTDF"
        PTDF, A = PowerSystems.buildptdf(system.branches, system.buses);
    end
    
    devices = Dict{Symbol, PSI.DeviceModel}(:ThermalGenerators => PSI.DeviceModel(PSY.ThermalGen, PSI.ThermalDispatch),
    :RenewableGenerators => PSI.DeviceModel(PSY.RenewableGen, PSI.RenewableFullDispatch),
    :Loads => PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))

    branches = Dict{Symbol, PSI.DeviceModel}(:Lines => PSI.DeviceModel(PSY.Branch, PSI.SeriesLine))                                             
    services = Dict{Symbol, PSI.ServiceModel}(:Reserves => PSI.ServiceModel(PSY.Reserve, PSI.AbstractReservesForm))

    return PowerOperationModel(EconomicDispatch,
                                    StandardPTDFForm, 
                                    devices, 
                                    branches, 
                                    services,                                
                                    system,
                                    optimizer = optimizer; PTDF = PTDF, kwargs...)

end