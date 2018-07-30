export simulatemodel

function modify_constraint(m::JuMP.Model, consname::Symbol, data::Array{Float64,2})

    !(size(m[consmane]) == size(data)) ? error("The data and the constraint are size inconsistent") : true

    for (n, c) in enumerate(IndexCartesian(), data)

        JuMP.setRHS(m[consname], data[n])

    end

    return m

end

function run_simulations(power_model::PowerSimulationsModel{T}) where T<:AbstractOperationsModel

    # CheckPowerModel(m::PowerSimulationsModel{T}) where T<:AbstractPowerSimulationType
    # AssignSolver(m::PowerSimulationsModel{T}) where T<:AbstractPowerSimulationType
    # WarmUpModel(m::PowerSimulationsModel{T}) where T<:AbstractPowerSimulationType

    for st in simulation_steps
        continue

        # SolveModel(m)

    end


end


function simulatemodel(model::PowerSimulationsModel{T}) where T<:AbstractOperationsModel



end


