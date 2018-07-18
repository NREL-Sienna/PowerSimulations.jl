export PowerSimulationsModel
export PowerResults

abstract type AbstractPowerSimulationType end

abstract type EconomicDispatchType <: AbstractPowerSimulationType end

mutable struct PowerOperationsModel{T<:AbstractPowerSimulationType}
    generation::Array{Function}
    demand::Array{Function}
    storage::Array{Function}
    cost::Function
    transmission::Function
    system::PowerSystems.PowerSystem
    model::JuMP.Model
    dynamics::Function
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
