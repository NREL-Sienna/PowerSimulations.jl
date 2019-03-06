struct UnitCommitment <: AbstractOperationsModel end

function UnitCommitment(system::PSY.PowerSystem, transmission::Type{S}; optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing, kwargs...) where {S <: PM.AbstractPowerFormulation}

    devices = Dict{String, PSI.DeviceModel}("Generators" => PSI.DeviceModel(PSY.ThermalGen, PSI.ThermalUnitCommitment),
                                            "RenewableGenerators" => PSI.DeviceModel(PSY.RenewableGen, PSI.RenewableFullDispatch),
                                            "Loads" => PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))

    branches = Dict{String, PSI.DeviceModel}("Lines" => PSI.DeviceModel(PSY.Branch, PSI.SeriesLine))                                             
    services = Dict{String, PSI.ServiceModel}("Reserves" => PSI.ServiceModel(PSY.Reserve, PSI.AbstractReservesForm))

    op_model = PowerOperationModel(UnitCommitment,
                                   transmission, 
                                    devices, 
                                    branches, 
                                    services,                                
                                    system;
                                    optimizer = optimizer, kwargs...)
end