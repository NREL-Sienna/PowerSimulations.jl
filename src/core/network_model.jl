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
- `PTDF::PSY.PTDF`: PTDF Array calculated using PowerSystems
- `duals::Vector{DataType}`: Constraint types to calculate the duals

# Example
```julia
ptdf_array = PSY.PTDF(system)
thermal_gens = NetworkModel(StandardPTDFModel, ptdf = ptdf_array),
```
"""
mutable struct NetworkModel{T <: PM.AbstractPowerModel}
    use_slacks::Bool
    PTDF::Union{Nothing, PSY.PTDF}
    duals::Vector{DataType}

    function NetworkModel(
        ::Type{T};
        use_slacks = false,
        PTDF = nothing,
        duals = Vector{DataType}(),
    ) where {T <: PM.AbstractPowerModel}
        _check_pm_formulation(T)
        new{T}(use_slacks, PTDF, duals)
    end
end

get_use_slacks(m::NetworkModel) = m.use_slacks
get_PTDF(m::NetworkModel) = m.PTDF
get_duals(m::NetworkModel) = m.duals
get_network_formulation(::NetworkModel{T}) where {T <: PM.AbstractPowerModel} = T

function add_dual!(model::NetworkModel, dual)
    dual in model.duals && error("dual = $dual is already stored")
    push!(model.duals, dual)
    @debug "Added dual" dual
end
