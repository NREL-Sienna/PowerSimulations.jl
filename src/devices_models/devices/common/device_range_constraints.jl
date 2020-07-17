struct RangeConstraintSpec
    constraint_name::Symbol
    variable_name::Symbol
    bin_variable_names::Vector{Symbol}
    limits_func::Function
    constraint_func::Function
    constraint_struct::Type{<:AbstractRangeConstraintInfo}
    lag_limits_func::Union{Function, Nothing}
end

function RangeConstraintSpec(;
    constraint_name,
    variable_name,
    bin_variable_names = Vector{Symbol}(),
    limits_func,
    constraint_func,
    constraint_struct,
    lag_limits_func = nothing,
)
    return RangeConstraintSpec(
        constraint_name,
        variable_name,
        bin_variable_names,
        limits_func,
        constraint_func,
        constraint_struct,
        lag_limits_func,
    )
end

struct TimeSeriesConstraintSpec
    constraint_name::Symbol
    variable_name::Symbol
    bin_variable_name::Union{Nothing, Symbol}
    parameter_name::Union{Nothing, String}
    forecast_label::Union{Nothing, String}
    multiplier_func::Union{Nothing, Function}
    constraint_func::Function
end

function TimeSeriesConstraintSpec(;
    constraint_name,
    variable_name,
    bin_variable_name = nothing,
    parameter_name,
    forecast_label,
    multiplier_func,
    constraint_func,
)
    return TimeSeriesConstraintSpec(
        constraint_name,
        variable_name,
        bin_variable_name,
        parameter_name,
        forecast_label,
        multiplier_func,
        constraint_func,
    )
end

struct DeviceRangeConstraintSpec
    range_constraint_spec::Union{Nothing, RangeConstraintSpec}
    timeseries_range_constraint_spec::Union{Nothing, TimeSeriesConstraintSpec}
    custom_psi_container_func::Union{Nothing, Function}
    devices_filter_func::Union{Nothing, Function}
end

"""
Default implementation to add range constraints.

Users of this function must implement a method for
[`DeviceRangeConstraintSpec`](@ref) for their specific types.
Users may also implement custom active_power_constraints! methods.
"""
function add_constraints!(
    ::Type{T},
    ::Type{U},
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    T <: RangeConstraint,
    U <: VariableType,
    V <: PSY.Device,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    use_parameters = model_has_parameters(psi_container)
    use_forecasts = model_uses_forecasts(psi_container)
    @assert !(use_parameters && !use_forecasts)
    spec =
        DeviceRangeConstraintSpec(T, U, V, W, X, feedforward, use_parameters, use_forecasts)
    device_range_constraints!(psi_container, devices, model, feedforward, spec)
end

"""
Construct inputs for creating range constraints.

# Arguments
`range_constraint_spec::Vector{RangeConstraintSpec}`: May be emtpy.
`timeseries_range_constraint_spec::Vector{TimeSeriesConstraintSpec}`: May be empty.
`custom_psi_container_func::Union{Nothing, Function}`: Optional function to add custom
 constraints to the internals of a PSIContainer. Must accept PSIContainer, devices iterable,
 and a subtype of AbstractDeviceFormulation.
`devices_filter_func::Union{Nothing, Function}`: Optional function to filter the devices on

"""
function DeviceRangeConstraintSpec(;
    range_constraint_spec = nothing,
    timeseries_range_constraint_spec = nothing,
    custom_psi_container_func = nothing,
    devices_filter_func = nothing,
)
    return DeviceRangeConstraintSpec(
        range_constraint_spec,
        timeseries_range_constraint_spec,
        custom_psi_container_func,
        devices_filter_func,
    )
end

function device_range_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    spec::DeviceRangeConstraintSpec,
) where {T <: PSY.Device, U <: AbstractDeviceFormulation}
    range_constraint_spec = spec.range_constraint_spec
    timeseries_range_constraint_spec = spec.timeseries_range_constraint_spec
    custom_psi_container_func = spec.custom_psi_container_func

    if !isnothing(spec.devices_filter_func)
        devices = filter!(spec.devices_filter_func, collect(devices))
    end

    if isnothing(feedforward)
        ff_affected_variables = Set{Symbol}()
    else
        ff_affected_variables = Set(get_affected_variables(feedforward))
    end

    if !isnothing(range_constraint_spec)
        _apply_range_constraint_spec(
            range_constraint_spec,
            psi_container,
            devices,
            model,
            ff_affected_variables,
        )
    end

    if !isnothing(timeseries_range_constraint_spec)
        _apply_timeseries_range_constraint_spec(
            timeseries_range_constraint_spec,
            psi_container,
            devices,
            model,
            ff_affected_variables,
        )
    end

    if !isnothing(custom_psi_container_func)
        custom_psi_container_func(psi_container, devices, U)
    end
end

function _apply_range_constraint_spec(
    spec,
    psi_container,
    devices::IS.FlattenIteratorWrapper{T},
    model,
    ff_affected_variables,
) where {T <: PSY.Device}
    constraint_struct = spec.constraint_struct
    constraint_infos = Vector{constraint_struct}(undef, length(devices))
    constraint_name = spec.constraint_name
    variable_name = spec.variable_name
    if variable_name in ff_affected_variables
        @debug "Skip adding $variable_name because it is handled by feedforward"
        return
    end
    bin_var_name = spec.bin_variable_names
    for (i, dev) in enumerate(devices)
        dev_name = PSY.get_name(dev)
        limits = spec.limits_func(dev)
        if isnothing(limits)
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
        psi_container,
        RangeConstraintSpecInternal(
            constraint_infos,
            constraint_name,
            variable_name,
            bin_var_name,
        ),
    )
    return
end

function _apply_timeseries_range_constraint_spec(
    spec,
    psi_container,
    devices::IS.FlattenIteratorWrapper{T},
    model,
    ff_affected_variables,
) where {T <: PSY.Device}
    variable_name = spec.variable_name
    if variable_name in ff_affected_variables
        @debug "Skip adding $variable_name because it is handled by feedforward"
        return
    end
    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (i, dev) in enumerate(devices)
        ts_vector = get_time_series(psi_container, dev, spec.forecast_label)
        constraint_info =
            DeviceTimeSeriesConstraintInfo(dev, spec.multiplier_func, ts_vector)
        add_device_services!(constraint_info.range, dev, model)
        constraint_infos[i] = constraint_info
    end

    ts_inputs = TimeSeriesConstraintSpecInternal(
        constraint_infos,
        spec.constraint_name,
        variable_name,
        spec.bin_variable_name,
        isnothing(spec.parameter_name) ? nothing :
            UpdateRef{T}(spec.parameter_name, spec.forecast_label),
    )
    spec.constraint_func(psi_container, ts_inputs)
    return
end
