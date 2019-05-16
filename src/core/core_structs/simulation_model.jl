mutable struct PowerSimulationsModel{T<:AbstractOperationsModel, R<:Dates.Period}
    name::String
    model::OperationModel{T}
    steps::Int64
    periods::Int64
    resolution::R
    date_from::Dates.DateTime
    date_to::Dates.DateTime
    lookahead_periods::Int64
    lookahead_resolution::R
    dynamic_analysis::Bool
    timeseries::Dict{Any,Any}
end
