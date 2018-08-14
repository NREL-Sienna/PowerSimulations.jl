export PowerSimulationsModel
export PowerResults

abstract type AbstractOperationsModel end

abstract type EconomicDispatch <: AbstractOperationsModel end

abstract type UnitCommitment <: AbstractOperationsModel end

mutable struct PowerOperationModel{T<:AbstractOperationsModel, F <: Array{<:Function}}
    psmodel::T
    generation::Array{NamedTuple{(:device, :constraints), Tuple{DataType,F}}}
    demand::Array{NamedTuple{(:device, :constraints), Tuple{DataType,F}}}
    storage::Array{NamedTuple{(:device, :constraints), Tuple{DataType,F}}}
    transmission::NamedTuple{(:device, :constraints), Tuple{DataType,F}}
    branches::Array{NamedTuple{(:device, :constraints), Tuple{DataType,F}}}
    services::Array{NamedTuple{(:device, :constraints), Tuple{DataType,F}}}
    cost::Array{NamedTuple{(:device, :component), Tuple{DataType,F}}}
    system::PowerSystems.PowerSystem
    model::JuMP.Model
    dynamics::Bool
end

mutable struct PowerSimulationsModel{T<:AbstractOperationsModel}
    name::String
    model::PowerOperationModel{T}
    periods::Int64
    resolution::Int64
    date_from::DateTime
    date_to::DateTime
    lookahead_periods::Int64
    lookahead_resolution::Int64
    dynamic_analysis::Bool
    timeseries::Any
end

 mutable struct PowerResults
    ThermalGeneration::Union{Nothing,DataFrame}
    RenewableGEneration::Union{Nothing,DataFrame}
    HydroGeneration::Union{Nothing,DataFrame}
    Storage::Union{Nothing,DataFrame}
    Load::Union{Nothing,DataFrame}
    SolverOutput::Union{Nothing,Dict}
end
