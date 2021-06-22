struct RangeConstraintSpec
    constraint_type::ConstraintType
    variable_type::VariableType
    bin_variable_types::Vector{VariableType}
    limits_func::Function
    constraint_func::Function
    constraint_struct::Type{<:AbstractRangeConstraintInfo}
    component_type::Type{<:PSY.Component}
    lag_limits_func::Union{Function, Nothing}
end

function RangeConstraintSpec(;
    constraint_type,
    variable_type,
    bin_variable_types = Vector{VariableType}(),
    limits_func,
    constraint_func,
    constraint_struct,
    component_type,
    lag_limits_func = nothing,
)
    return RangeConstraintSpec(
        constraint_type,
        variable_type,
        bin_variable_types,
        limits_func,
        constraint_func,
        constraint_struct,
        component_type,
        lag_limits_func,
    )
end

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
    range_constraint_spec::Union{Nothing, RangeConstraintSpec}
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
    optimization_container::OptimizationContainer,
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
    use_parameters = model_has_parameters(optimization_container)
    use_forecasts = model_uses_forecasts(optimization_container)
    @assert !(use_parameters && !use_forecasts)
    spec =
        DeviceRangeConstraintSpec(T, U, V, W, X, feedforward, use_parameters, use_forecasts)
    device_range_constraints!(optimization_container, devices, model, feedforward, spec)
end

"""
Construct inputs for creating range constraints.

# Arguments
`range_constraint_spec::Vector{RangeConstraintSpec}`: May be emtpy.
`timeseries_range_constraint_spec::Vector{TimeSeriesConstraintSpec}`: May be empty.
`custom_optimization_container_func::Union{Nothing, Function}`: Optional function to add custom
 constraints to the internals of a OptimizationContainer. Must accept OptimizationContainer, devices iterable,
 and a subtype of AbstractDeviceFormulation.
`devices_filter_func::Union{Nothing, Function}`: Optional function to filter the devices on

"""
function DeviceRangeConstraintSpec(;
    range_constraint_spec = nothing,
    timeseries_range_constraint_spec = nothing,
    custom_optimization_container_func = nothing,
    devices_filter_func = nothing,
)
    return DeviceRangeConstraintSpec(
        range_constraint_spec,
        timeseries_range_constraint_spec,
        custom_optimization_container_func,
        devices_filter_func,
    )
end

function device_range_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    spec::DeviceRangeConstraintSpec,
) where {T <: PSY.Device, U <: AbstractDeviceFormulation}
    range_constraint_spec = spec.range_constraint_spec
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

    if !(range_constraint_spec === nothing)
        _apply_range_constraint_spec!(
            optimization_container,
            range_constraint_spec,
            devices,
            model,
            ff_affected_variables,
        )
    end

    if !(timeseries_range_constraint_spec === nothing)
        _apply_timeseries_range_constraint_spec!(
            optimization_container,
            timeseries_range_constraint_spec,
            devices,
            model,
            ff_affected_variables,
        )
    end

    if !(custom_optimization_container_func === nothing)
        custom_optimization_container_func(optimization_container, devices, U)
    end
end

function _apply_range_constraint_spec!(
    optimization_container,
    spec,
    devices::IS.FlattenIteratorWrapper{T},
    model,
    ff_affected_variables,
) where {T <: PSY.Device}
    constraint_struct = spec.constraint_struct
    constraint_infos = Vector{constraint_struct}(undef, length(devices))
    constraint_type = spec.constraint_type
    variable_type = spec.variable_type
    if variable_type in ff_affected_variables
        @debug "Skip adding $variable_type because it is handled by feedforward"
        return
    end
    bin_var_name = spec.bin_variable_types
    for (i, dev) in enumerate(devices)
        dev_name = PSY.get_name(dev)
        limits = spec.limits_func(dev)
        if limits === nothing
            limits = (min = 0.0, max = 0.0)
            @warn "Range constraint limits of $T $dev_name are nothing. Set to" limits
        end
        if constraint_struct == DeviceRangeConstraintInfo
            constraint_info = DeviceRangeConstraintInfo(dev_name, limits)
        elseif constraint_struct == DeviceMultiStartRangeConstraintsInfo
            lag_limits = spec.lag_limits_func(dev)
            constraint_info =
                DeviceMultiStartRangeConstraintsInfo(dev_name, limits, lag_limits)
        else
            error("Missing implementation for $constraint_struct")
        end
        add_device_services!(constraint_info, dev, model)
        constraint_infos[i] = constraint_info
    end

    spec.constraint_func(
        optimization_container,
        RangeConstraintSpecInternal(
            constraint_infos,
            constraint_type,
            variable_type,
            bin_var_name,
            T,
        ),
    )
    return
end

function _apply_timeseries_range_constraint_spec!(
    optimization_container,
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
    forecast_label = get_label(spec.parameter)
    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (i, dev) in enumerate(devices)
        ts_vector = get_time_series(optimization_container, dev, forecast_label)
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
    spec.constraint_func(optimization_container, ts_inputs)
    return
end
