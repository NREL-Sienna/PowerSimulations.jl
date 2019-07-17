mutable struct SimulationRef
    raw::String
end

mutable struct Stage
    key::Int64
    model::OperationModel
    execution_count::Int64
end

mutable struct Simulation
    steps::Int64
    stages::Vector{Stage}
    feedback_ref::Any
    valid_timeseries::Bool
    daterange::NTuple{2,Dates.DateTime} #Inital Time of the first forecast and Inital Time of the last forecast
    ref::SimulationRef


    function Simulation(base_name::String,
                        steps::Int64,
                        stages::Dict{Int64, Tuple{ModelReference{T}, PSY.System, Int64}},
                        feedback_ref,
                        simulation_folder::String;
                        kwargs...) where {T<:PM.AbstractPowerFormulation}


    sim_ref = SimulationRef("init")

    dates, validation, stages_vector = build_simulation!(sim_ref,
                                                        base_name,
                                                        steps,
                                                        stages,
                                                        feedback_ref,
                                                        simulation_folder;
                                                        kwargs...)

    new(steps,
        stages_vector,
        feedback_ref,
        validation,
        dates,
        sim_ref)

    end

end
