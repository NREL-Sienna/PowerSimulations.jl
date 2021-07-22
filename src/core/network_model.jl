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
Establishes the model for a particular device specified by type. Uses the keyword argument
feedforward to enable passing values between operation model at simulation time

# Arguments
-`::Type{D}`: Power System Device Type
-`::Type{B}`: Abstract Device Formulation

# Accepted Key Words
- `feedforward::Array{<:AbstractAffectFeedForward}` : use to pass parameters between models

# Example
```julia
thermal_gens = DeviceModel(ThermalStandard, ThermalBasicUnitCommitment),
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
