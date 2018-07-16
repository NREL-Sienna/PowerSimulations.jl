function modify_constraint(m::JuMP.Model, time_series, consname::Symbol)

    return m

end

function run_simulations(power_model::PowerSimulationsModel{T}) where T<:AbstractPowerSimulationType

    # CheckPowerModel(m::PowerSimulationsModel{T}) where T<:AbstractPowerSimulationType
    # AssignSolver(m::PowerSimulationsModel{T}) where T<:AbstractPowerSimulationType
    # WarmUpModel(m::PowerSimulationsModel{T}) where T<:AbstractPowerSimulationType

    for st in simulation_steps
        continue

        # SolveModel(m)

    end


end

