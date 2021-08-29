"""
Construct reactive power DeviceRangeConstraintInputs for specific types.
"""
function make_reactive_power_constraints_inputs(
    ::Type{T},
    ::Type{U},
    ::Type{V},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
) where {T <: PSY.Device, U <: AbstractDeviceFormulation, V <: PM.AbstractPowerModel}
    error(
        "make_reactive_power_constraints_inputs is not implemented for types $T / $U / $V",
    )
end

"""
Default implementation to add active_power constraints.

Users of this function must implement a method for
[`make_reactive_power_constraints_inputs`](@ref) for their specific types.
Users may also implement custom reactive_power_constraints! methods.
"""
function reactive_power_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.Device, U <: AbstractDeviceFormulation}
    use_parameters = built_for_recurrent_solves(container)
    # TODO: this function does not define use_forecasts
    @assert !(use_parameters && !use_forecasts)
    inputs = make_reactive_power_constraints_inputs(
        T,
        U,
        PM.AbstractPowerModel,
        feedforward,
        use_parameters,
    )
    device_range_constraints!(container, devices, model, feedforward, inputs)
end
