"""
PowerSimulation contains the system data and the model to be solved, along with other simulation parameters.
"""
struct PowerSimulation
    system::PowerSystems.PowerSystem
    model::AbstractPowerSimulationModel
    parameters::AbstractPowerSimulationParameters
end


function PowerSimulation(system::PowerSystems.PowerSystem)
    problem = PowerOptimizationModel()
    parameters = PowerOptimizationParameters()
    return PowerSimulation(system, problem, parameters)
end



