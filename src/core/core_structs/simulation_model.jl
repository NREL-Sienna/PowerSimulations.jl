mutable struct PowerSimulationsModel
    basename::String
    periods::Int64
    stages::Dict{Int64, OperationModel}
    executioncount::Dict{Int64, Int64}
    feedback_ref::Any
    datefrom::Dates.DateTime
    dateto::Dates.DateTime
    simulation_folder::String
end

