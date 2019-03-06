struct EconomicDispatch <: AbstractOperationsModel end

function EconomicDispatch(system::PSY.PowerSystem, transmission::Type{S}; optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing, kwargs...) where {S <: PM.AbstractPowerFormulation}

    devices = Dict{String, PSI.DeviceModel}("ThermalGenerators" => PSI.DeviceModel(PSY.ThermalGen, PSI.ThermalDispatch),
                                            "RenewableGenerators" => PSI.DeviceModel(PSY.RenewableGen, PSI.RenewableFullDispatch),
                                            "Loads" => PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))

    branches = Dict{String, PSI.DeviceModel}("Lines" => PSI.DeviceModel(PSY.Branch, PSI.SeriesLine))                                             
    services = Dict{String, PSI.ServiceModel}("Reserves" => PSI.ServiceModel(PSY.Reserve, PSI.AbstractReservesForm))

    op_model = PowerOperationModel(EconomicDispatch,
                                   transmission, 
                                    devices, 
                                    branches, 
                                    services,                                
                                    system,
                                    optimizer = optimizer; kwargs...)
end