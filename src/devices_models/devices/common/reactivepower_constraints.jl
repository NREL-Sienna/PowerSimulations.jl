"""
Construct reactive power DeviceRangeConstraintInputs for specific types.
"""
function make_reactive_power_constraints_inputs(
    ::Type{T},
    ::Type{U},
    ::Type{V},
    use_parameters::Bool,
) where {T <: PSY.Device, U <: AbstractDeviceFormulation, V <: PM.AbstractPowerModel}
    error(
        "make_reactive_power_constraints_inputs is not implemented for types $T / $U / $V",
    )
end

"""
Default implementation to add reactive_power constraints.

Users of this function must implement a method for
[`make_reactive_power_constraints_inputs`](@ref) for their specific types.
Users may also implement custom reactive_power_constraints! methods.
"""
function reactive_power_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.Device, U <: AbstractDeviceFormulation}
    use_parameters = built_for_recurrent_solves(container)
    inputs =
        make_reactive_power_constraints_inputs(T, U, PM.AbstractPowerModel, use_parameters)
    device_range_constraints!(container, devices, model, feedforward, inputs)
end
