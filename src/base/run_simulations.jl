function modify_constraint(m::JuMP.Model, time_series, consname::Symbol)

    return m

end

function run_simulations(power_model::PowerSimulationModel{T}) where T<:AbstractPowerSimulationType

    # CheckPowerModel(m::PowerSimulationModel{T}) where T<:AbstractPowerSimulationType
    # AssignSolver(m::PowerSimulationModel{T}) where T<:AbstractPowerSimulationType
    # WarmUpModel(m::PowerSimulationModel{T}) where T<:AbstractPowerSimulationType

    for st in simulation_steps
        continue

        # SolveModel(m) where M <: PowerSimulations.AbstractPowerSimulationModel

    end


end

