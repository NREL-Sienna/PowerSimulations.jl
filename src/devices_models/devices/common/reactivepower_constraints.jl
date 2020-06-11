"""
Construct reactive power DeviceConstraintInputs for specific types.
"""
function make_reactive_power_constraints_inputs(
    ::Type{T},
    ::Type{U},
    ::Type{V},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.Device, U <: AbstractDeviceFormulation, V <: PM.AbstractPowerModel}
    error("make_reactive_power_constraints_inputs is not implemented for types $T / $U / $V")
end

"""
Default implementation to add activepower constraints.

Users of this function must implement a method for
[`make_reactive_power_constraints_inputs`](@ref) for their specific types.
Users may also implement custom reactivepower_constraints! methods.
"""
function reactivepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.Device, U <: AbstractDeviceFormulation}
    use_parameters = model_has_parameters(psi_container)
    use_forecasts = model_uses_forecasts(psi_container)
    @assert !(use_parameters && !use_forecasts)
    inputs = make_reactive_power_constraints_inputs(
        T,
        U,
        PM.AbstractPowerModel,
        feedforward,
        use_parameters,
        use_forecasts,
    )
    device_constraints!(psi_container, devices, model, feedforward, inputs)
end
