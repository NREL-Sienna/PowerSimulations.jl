struct TimeSeriesConstraintSpec
    constraint_type::ConstraintType
    variable_type::VariableType
    bin_variable_type::Union{Nothing, VariableType}
    parameter::TimeSeriesParameter
    multiplier_func::Union{Nothing, Function}
    constraint_func::Function
    component_type::Type{<:PSY.Component}
end

function TimeSeriesConstraintSpec(;
    constraint_type,
    variable_type,
    bin_variable_type = nothing,
    parameter,
    multiplier_func,
    constraint_func,
    component_type,
)
    return TimeSeriesConstraintSpec(
        constraint_type,
        variable_type,
        bin_variable_type,
        parameter,
        multiplier_func,
        constraint_func,
        component_type,
    )
end

struct DeviceRangeConstraintSpec
    timeseries_range_constraint_spec::Union{Nothing, TimeSeriesConstraintSpec}
    custom_optimization_container_func::Union{Nothing, Function}
    devices_filter_func::Union{Nothing, Function}
end

"""
Default implementation to add range constraints.

Users of this function must implement a method for
[`DeviceRangeConstraintSpec`](@ref) for their specific types.
Users may also implement custom active_power_constraints! methods.
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    T <: ConstraintType,
    U <: VariableType,
    V <: PSY.Device,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    use_parameters = built_for_simulation(container)
    spec = DeviceRangeConstraintSpec(T, U, V, W, X, feedforward, use_parameters)
    device_range_constraints!(container, devices, model, feedforward, spec)
end

function device_range_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    spec::DeviceRangeConstraintSpec,
) where {T <: PSY.Device, U <: AbstractDeviceFormulation}
    timeseries_range_constraint_spec = spec.timeseries_range_constraint_spec
    custom_optimization_container_func = spec.custom_optimization_container_func

    if !(spec.devices_filter_func === nothing)
        devices = filter!(spec.devices_filter_func, collect(devices))
    end

    if feedforward === nothing
        ff_affected_variables = Set{Symbol}()
    else
        ff_affected_variables = Set(get_affected_variables(feedforward))
    end

    if !(timeseries_range_constraint_spec === nothing)
        _apply_timeseries_range_constraint_spec!(
            container,
            timeseries_range_constraint_spec,
            devices,
            model,
            ff_affected_variables,
        )
    end

    if !(custom_optimization_container_func === nothing)
        custom_optimization_container_func(container, devices, U)
    end
end

"""
Construct inputs for creating range constraints.

# Arguments
`timeseries_range_constraint_spec::Vector{TimeSeriesConstraintSpec}`: May be empty.
`custom_optimization_container_func::Union{Nothing, Function}`: Optional function to add custom
 constraints to the internals of a OptimizationContainer. Must accept OptimizationContainer, devices iterable,
 and a subtype of AbstractDeviceFormulation.
`devices_filter_func::Union{Nothing, Function}`: Optional function to filter the devices on

"""
function DeviceRangeConstraintSpec(;
    timeseries_range_constraint_spec = nothing,
    custom_optimization_container_func = nothing,
    devices_filter_func = nothing,
)
    return DeviceRangeConstraintSpec(
        timeseries_range_constraint_spec,
        custom_optimization_container_func,
        devices_filter_func,
    )
end

function _apply_timeseries_range_constraint_spec!(
    container,
    spec,
    devices::IS.FlattenIteratorWrapper{T},
    model,
    ff_affected_variables,
) where {T <: PSY.Device}
    variable_type = spec.variable_type
    if variable_type in ff_affected_variables
        @debug "Skip adding $variable_type because it is handled by feedforward"
        return
    end
    forecast_name = get_name(spec.parameter)
    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (i, dev) in enumerate(devices)
        ts_vector = get_time_series(container, dev, forecast_name)
        constraint_info =
            DeviceTimeSeriesConstraintInfo(dev, spec.multiplier_func, ts_vector)
        add_device_services!(constraint_info.range, dev, model)
        constraint_infos[i] = constraint_info
    end

    ts_inputs = TimeSeriesConstraintSpecInternal(
        constraint_infos,
        spec.constraint_type,
        variable_type,
        spec.bin_variable_type,
        spec.parameter,
        T,
    )
    spec.constraint_func(container, ts_inputs)
    return
end
