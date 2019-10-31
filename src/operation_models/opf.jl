struct OptimalPowerFlow<:AbstractOperationsProblem end

function OptimalPowerFlow(sys::PSY.System, transmission::Type{S}; optimizer::Union{Nothing, JuMP.OptimizerFactory}=nothing, kwargs...) where {S<:PM.AbstractPowerModel}

    devices = Dict{Symbol, DeviceModel}(:ThermalGenerators => DeviceModel(PSY.ThermalGen, ThermalDispatch),
                                            :RenewableGenerators => DeviceModel(PSY.RenewableGen, RenewableConstantPowerFactor),
                                            :Loads => DeviceModel(PSY.PowerLoad, StaticPowerLoad))

    branches = Dict{Symbol, DeviceModel}(:Lines => DeviceModel(PSY.Branch, SeriesLine))
    services = Dict{Symbol, ServiceModel}(:Reserves => ServiceModel(PSY.Reserve, AbstractReservesFormulation))

    return OperationsProblem(OptimalPowerFlow ,
                                   transmission,
                                    devices,
                                    branches,
                                    services,
                                    system,
                                    optimizer = optimizer; kwargs...)

end
