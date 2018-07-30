export PowerSimulationsModel
export PowerResults

abstract type AbstractOperationsModel end

abstract type EconomicDispatch <: AbstractOperationsModel end

abstract type UnitCommitment <: AbstractOperationsModel end

mutable struct PowerOperationModel{T<:AbstractOperationsModel, F <: Array{<:Function}}
    psmodel:: T
    generation::Array{@NT(device::DataType,constraints::F)}
    demand::Array{@NT(device::DataType,constraints::F)}
    storage::Array{@NT(device::DataType,constraints::F)}
    transmission::@NT(device::DataType,constraints::F)
    branches::Array{@NT(device::DataType,constraints::F)}
    services::Array{@NT(device::DataType,constraints::F)}
    cost::Array{@NT(device::DataType,components::F)}
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
