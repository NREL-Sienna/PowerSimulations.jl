mutable struct PowerSimulationsModel
    base_name::String
    periods::Int64
    stages::Dict{Int64,OperationModel}
    executioncount::Dict{Int64,Int64}
    feedback_ref::Any
    date_from::Dates.DateTime
    date_to::Dates.DateTime
    simulation_folder::String
end

