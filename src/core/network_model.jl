function _check_pm_formulation(::Type{T}) where {T <: PM.AbstractPowerModel}
    if !isconcretetype(T)
        throw(
            ArgumentError(
                "The device model must contain only concrete types, $(T) is an Abstract Type",
            ),
        )
    end
end

"""
Establishes the model for a particular device specified by type.

# Arguments

-`::Type{T}`: PowerModels AbstractPowerModel

# Accepted Key Words

  - `use_slacks::Bool`: Adds slacks to the network modelings
  - `PTDF::PTDF`: PTDF Array calculated using PowerSystems
  - `duals::Vector{DataType}`: Constraint types to calculate the duals

# Example

ptdf_array = PTDF(system)
thermal_gens = NetworkModel(StandardPTDFModel, ptdf = ptdf_array),
"""
mutable struct NetworkModel{T <: PM.AbstractPowerModel}
    use_slacks::Bool
    PTDF_matrix::Union{Nothing, PNM.PowerNetworkMatrix}
    duals::Vector{DataType}

    function NetworkModel(
        ::Type{T};
        use_slacks=false,
        PTDF_matrix=nothing,
        duals=Vector{DataType}(),
    ) where {T <: PM.AbstractPowerModel}
        _check_pm_formulation(T)
        new{T}(use_slacks, PTDF_matrix, duals)
    end
end

get_use_slacks(m::NetworkModel) = m.use_slacks
get_PTDF_matrix(m::NetworkModel) = m.PTDF_matrix
get_duals(m::NetworkModel) = m.duals
get_network_formulation(::NetworkModel{T}) where {T <: PM.AbstractPowerModel} = T

function add_dual!(model::NetworkModel, dual)
    dual in model.duals && error("dual = $dual is already stored")
    push!(model.duals, dual)
    @debug "Added dual" dual _group = LOG_GROUP_NETWORK_CONSTRUCTION
end
