abstract type AbstractOperationsModel end

mutable struct PowerOperationModel{M<:AbstractOperationsModel, T<:PM.AbstractPowerFormulation}
    op_model::Type{M}
    transmission::Type{T}
    system::PSY.PowerSystem
    generation::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}
    demand::Union{Nothing,Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}}
    storage::Union{Nothing,Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}}
    branches::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}
    services::Any
    canonical_model::PSI.CanonicalModel
end