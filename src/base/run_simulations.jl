function modify_constraint(m::JuMP.Model, time_series, consname::Symbol)

    return m

end

function run_simulations(power_model::T) where T <: PowerSimulations.SimulationModel

CheckPowerModel(m::M) where M <: PowerSimulations.AbstractPowerSimulationModel
AssignSolver(m::M) where M <: PowerSimulations.AbstractPowerSimulationModel
WarmUpModel(m::M) where M <: PowerSimulations.AbstractPowerSimulationModel

for st in simulation_steps



    SolveModel(m::M) where M <: PowerSimulations.AbstractPowerSimulationModel

end


end

