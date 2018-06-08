export PowerSimulationModel
# export PowerResults

abstract type AbstractPowerSimulationModel
end

abstract type AbstractPowerSimulationParameters
end

"""
PowerOptimizationParameters defines the parameters required for an optimization simulation
"""
struct PowerOptimizationParameters <: AbstractPowerSimulationParameters
    periods::Int
    resolution::Int
    date_from::DateTime
    date_to::DateTime
    lookahead_periods::Int
    lookahead_resolution::Int
    reserve_products::Any
    forecast::Any # Need to define this properly
end


"""
PowerOptimizationModel defines an optimization problem using JuMP.
"""
struct PowerOptimizationModel <: AbstractPowerSimulationModel
    problem::JuMP.Model
end

"""
PowerSimulation contains the system data and the model to be solved, along with other simulation parameters.
"""
struct PowerSimulation
    system::PowerSystems.PowerSystem
    model::AbstractPowerSimulationModel
    parameters::AbstractPowerSimulationParameters
end

PowerSimulation(
                     model::AbstractPowerSimulationModel,
                     periods=1,
                     resolution=1,
                     date_from=DateTime(1970, 1, 1),
                     date_to=DateTime(1970, 1, 1, 1, 0, 0),
                     lookahead_periods=0,
                     lookahead_resolution=0,
                     reserve_products=nothing,
                     dynamic_analysis=false,
                     forecast=nothing
                    ) = PowerSimulationModel(
                                                              model,
                                                              periods,
                                                              resolution,
                                                              date_from,
                                                              date_to,
                                                              lookahead_periods,
                                                              lookahead_resolution,
                                                              reserve_products,
                                                              dynamic_analysis,
                                                              forecast
                                                             )

function PowerSimulation(system::PowerSystems.PowerSystem)
    PowerSimulation(model::AbstractPowerSimulationModel)
end

struct PowerResults
    Dispatch::TimeSeries.TimeArray
    Solveroutput::Any
end


