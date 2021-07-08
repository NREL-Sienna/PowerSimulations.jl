"""
Construct active power DeviceRangeConstraintInputs for specific types.
"""
function make_active_power_constraints_inputs(
    ::Type{T},
    ::Type{U},
    ::Type{V},
    ::Union{Nothing, AbstractAffectFeedForward},
    ::Bool,
) where {T <: PSY.Device, U <: AbstractDeviceFormulation, V <: PM.AbstractPowerModel}
    error("make_active_power_constraints_inputs is not implemented for types $T / $U / $V")
end

"""
Default implementation to add active power constraints.

Users of this function must implement a method for
[`make_active_power_constraints_inputs`](@ref) for their specific types.
Users may also implement custom active_power_constraints! methods.
"""
function active_power_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::Type{V},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.Device, U <: AbstractDeviceFormulation, V <: PM.AbstractPowerModel}
    inputs = make_active_power_constraints_inputs(
        T,
        U,
        V,
        feedforward,
        built_for_simulation(container),
    )
    device_range_constraints!(container, devices, model, feedforward, inputs)
end
