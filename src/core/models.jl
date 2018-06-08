abstract type AbstractPowerSimulationModel
end

"""
PowerOptimizationModel defines an optimization problem using JuMP.
"""
struct PowerOptimizationModel <: AbstractPowerSimulationModel
    problem::JuMP.Model
end

PowerOptimizationModel() = PowerOptimizationModel(JuMP.Model())

