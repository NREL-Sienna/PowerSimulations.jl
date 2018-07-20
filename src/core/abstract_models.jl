export PowerSimulationsModel
export PowerResults

abstract type AbstractPowerSimulationType end

abstract type EconomicDispatch <: AbstractPowerSimulationType end

abstract type UnitCommitment <: AbstractPowerSimulationType end

mutable struct PowerOperationsModel{T<:AbstractPowerSimulationType, F <: Array{<:Function}}
    generation::Array{@NT(device::DataType,constraints::F)}
    demand::Array{@NT(device::DataType,constraints::F)}
    storage::Array{@NT(device::DataType,constraints::F)}
    services::Array{@NT(device::DataType,constraints::F)}
    transmission::Array{@NT(device::DataType,constraints::F)}
    cost::Array{@NT(device::DataType,components::F)}
    system::PowerSystems.PowerSystem
    psmodel::JuMP.Model
    dynamics::Bool
end

mutable struct PowerSimulationsModel{T<:AbstractPowerSimulationType}
    model::PowerOperationsModel{T}
    periods::Int64
    resolution::Int64
    date_from::DateTime
    date_to::DateTime
    lookahead_periods::Int64
    lookahead_resolution::Int64
    dynamic_analysis::Bool
    forecast::Any #Need to define this properly
    #A constructor here has to return the model based on the data, the time is AbstractModel
end

 mutable struct PowerResults
    ThermalGeneration::Union{Nothing,DataFrame}
    RenewableGEneration::Union{Nothing,DataFrame}
    HydroGeneration::Union{Nothing,DataFrame}
    Storage::Union{Nothing,DataFrame}
    Load::Union{Nothing,DataFrame}
    SolverOutput::Union{Nothing,Dict}
end
