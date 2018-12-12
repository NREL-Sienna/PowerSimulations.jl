abstract type AbstractOperationsModel end

abstract type EconomicDispatch <: AbstractOperationsModel end

abstract type UnitCommitment <: AbstractOperationsModel end

abstract type CustomModel <: AbstractOperationsModel end

mutable struct PowerOperationModel{ M<:AbstractOperationsModel, T<:NetworkModel, S<:Union{Nothing,Array{NamedTuple{(:service, :formulation), Tuple{D,DataType}}}} where {D <: PowerSystems.Service}}
    psmodel::Type{M}
    generation::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}
    demand::Union{Nothing,Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}}
    storage::Union{Nothing,Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}}
    branches::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}
    transmission::Type{T}
    services::S
    system::PowerSystems.PowerSystem
    model::canonical_model
    dynamics::Bool
    ptdf::Union{Nothing,PTDFArray}
end

mutable struct PowerSimulationsModel{T<:AbstractOperationsModel, R<:Dates.Period}
    name::String
    model::PowerOperationModel{T}
    steps::Int64
    periods::Int64
    resolution::R
    date_from::DateTime
    date_to::DateTime
    lookahead_periods::Int64
    lookahead_resolution::R
    dynamic_analysis::Bool
    timeseries::Dict{Any,Any}
end

 mutable struct PowerResults
    ThermalGeneration::Union{Nothing,DataFrame}
    RenewableGEneration::Union{Nothing,DataFrame}
    HydroGeneration::Union{Nothing,DataFrame}
    Storage::Union{Nothing,DataFrame}
    Load::Union{Nothing,DataFrame}
    SolverOutput::Union{Nothing,Dict}
end
