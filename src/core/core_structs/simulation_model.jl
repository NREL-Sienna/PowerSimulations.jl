mutable struct PowerSimulationsModel{T<:AbstractOperationsModel, R<:Dates.Period}
    name::String
    model::OperationModel{T}
    steps::Int64
    periods::Int64
    resolution::R
    date_from::Dates.DateTime
    date_to::Dates.DateTime
    time_steps_periods::Int64
    time_steps_resolution::R
    dynamic_analysis::Bool
    timeseries::Dict{Any,Any}
end
