struct RangeConstraintInputs
    constraint_name::String
    variable_name::String
    bin_variable_name::Vector{String}
    limits_func::Function
    constraint_func::Function
    constraint_struct::Type{<:AbstractRangeConstraintInfo}
    lag_limits_func::Union{Function, Nothing}
end

function RangeConstraintInputs(;
    constraint_name,
    variable_name,
    bin_variable_name = Vector{String}(),
    limits_func,
    constraint_func,
    constraint_struct,
    lag_limits_func = nothing,
)
    return RangeConstraintInputs(
        constraint_name,
        variable_name,
        bin_variable_name,
        limits_func,
        constraint_func,
        constraint_struct,
        lag_limits_func,
    )
end

struct TimeSeriesConstraintInputs
    constraint_name::String
    variable_name::String
    bin_variable_name::Union{Nothing, String}
    parameter_name::Union{Nothing, String}
    forecast_label::Union{Nothing, String}
    multiplier_func::Union{Nothing, Function}
    constraint_func::Function
end

function TimeSeriesConstraintInputs(;
    constraint_name,
    variable_name,
    bin_variable_name = nothing,
    parameter_name,
    forecast_label,
    multiplier_func,
    constraint_func,
)
    return TimeSeriesConstraintInputs(
        constraint_name,
        variable_name,
        bin_variable_name,
        parameter_name,
        forecast_label,
        multiplier_func,
        constraint_func,
    )
end

struct DeviceRangeConstraintInputs
    range_constraint_inputs::Vector{RangeConstraintInputs}
    timeseries_range_constraint_inputs::Vector{TimeSeriesConstraintInputs}
    custom_psi_container_func::Union{Nothing, Function}
    devices_filter_func::Union{Nothing, Function}
end

"""
Construct inputs for creating range constraints.

# Arguments
`range_constraint_inputs::Vector{RangeConstraintInputs}`: May be emtpy.
`timeseries_range_constraint_inputs::Vector{TimeSeriesConstraintInputs}`: May be empty.
`custom_psi_container_func::Union{Nothing, Function}`: Optional function to add custom
 constraints to the internals of a PSIContainer. Must accept PSIContainer, devices iterable,
 and a subtype of AbstractDeviceFormulation.
`devices_filter_func::Union{Nothing, Function}`: Optional function to filter the devices on

"""
function DeviceRangeConstraintInputs(;
    range_constraint_inputs = Vector{RangeConstraintInputs}(),
    timeseries_range_constraint_inputs = Vector{TimeSeriesConstraintInputs}(),
    custom_psi_container_func = nothing,
    devices_filter_func = nothing,
)
    return DeviceRangeConstraintInputs(
        range_constraint_inputs,
        timeseries_range_constraint_inputs,
        custom_psi_container_func,
        devices_filter_func,
    )
end

function device_range_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    inputs::DeviceRangeConstraintInputs,
) where {T <: PSY.Device, U <: AbstractDeviceFormulation}
    range_constraints = inputs.range_constraint_inputs
    timeseries_range_constraints = inputs.timeseries_range_constraint_inputs
    custom_psi_container_func = inputs.custom_psi_container_func

    if !isnothing(inputs.devices_filter_func)
        devices = filter!(inputs.devices_filter_func, collect(devices))
    end

    if isnothing(feedforward)
        ff_affected_variables = Set{Symbol}()
    else
        ff_affected_variables = Set(get_affected_variables(feedforward))
    end

    for rc in range_constraints
        constraint_struct = rc.constraint_struct
        constraint_infos = Vector{constraint_struct}(undef, length(devices))
        cons_name = constraint_name(rc.constraint_name, T)
        var_name = variable_name(rc.variable_name, T)
        if var_name in ff_affected_variables
            @debug "Skip adding $var_name because it is handled by feedforward"
            continue
        end
        bin_var_name = isempty(rc.bin_variable_name) ? rc.bin_variable_name :
            [variable_name(name, T) for name in rc.bin_variable_name]
        for (i, dev) in enumerate(devices)
            dev_name = PSY.get_name(dev)
            limits = rc.limits_func(dev)
            if isnothing(limits)
                limits = (min = 0.0, max = 0.0)
                @warn "Range constraint limits of $T $dev_name are nothing. Set to" limits
            end
            if constraint_struct == DeviceRangeConstraintInfo
                constraint_info = DeviceRangeConstraintInfo(dev_name, limits)
            elseif constraint_struct == DeviceMultiStartRangeConstraintsInfo
                lag_limits = rc.lag_limits_func(dev)
                constraint_info =
                    DeviceMultiStartRangeConstraintsInfo(dev_name, limits, lag_limits)
            end
            add_device_services!(constraint_info, dev, model)
            constraint_infos[i] = constraint_info
        end

        rc.constraint_func(
            psi_container,
            RangeConstraintInputsInternal(
                constraint_infos,
                cons_name,
                var_name,
                bin_var_name,
            ),
        )
    end

    for tsrc in timeseries_range_constraints
        var_name = variable_name(tsrc.variable_name, T)
        if var_name in ff_affected_variables
            @debug "Skip adding $var_name because it is handled by feedforward"
            continue
        end
        constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
        for (i, dev) in enumerate(devices)
            ts_vector = get_time_series(psi_container, dev, tsrc.forecast_label)
            constraint_info =
                DeviceTimeSeriesConstraintInfo(dev, tsrc.multiplier_func, ts_vector)
            add_device_services!(constraint_info.range, dev, model)
            constraint_infos[i] = constraint_info
        end

        ts_inputs = TimeSeriesConstraintInputsInternal(
            constraint_infos,
            constraint_name(tsrc.constraint_name, T),
            var_name,
            isnothing(tsrc.bin_variable_name) ? nothing :
                variable_name(tsrc.bin_variable_name, T),
            isnothing(tsrc.parameter_name) ? nothing :
                UpdateRef{T}(tsrc.parameter_name, tsrc.forecast_label),
        )
        tsrc.constraint_func(psi_container, ts_inputs)
    end

    if !isnothing(custom_psi_container_func)
        custom_psi_container_func(psi_container, devices, U)
    end
end
