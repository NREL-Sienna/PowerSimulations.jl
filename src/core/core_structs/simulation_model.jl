mutable struct Stage
    key::Int64
    model::OperationModel
    execution_count::Int64
end


mutable struct PowerSimulationsModel
    basename::String
    steps::Int64
    stages::Vector{Stage}
    feedback_ref::Any
    valid_timeseries::Bool
    from::Dates.DateTime #Inital Time of the first forecast
    to::Dates.DateTime #Inital Time of the last forecast
    simulation_folder::String
end

