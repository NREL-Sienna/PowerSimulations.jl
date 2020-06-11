struct ModelRangeConstraintInputs
    constraint_name::String
    variable_name::String
    bin_variable_name::Union{Nothing, String}
    limits_func::Function
    constraint_func::Function
end

function ModelRangeConstraintInputs(;
    constraint_name,
    variable_name,
    bin_variable_name = nothing,
    limits_func,
    constraint_func,
)
    return ModelRangeConstraintInputs(
        constraint_name,
        variable_name,
        bin_variable_name,
        limits_func,
        constraint_func,
    )
end

struct ModelTimeSeriesConstraintInputs
    constraint_name::String
    variable_name::String
    bin_variable_name::Union{Nothing, String}
    parameter_name::Union{Nothing, String}
    forecast_label::Union{Nothing, String}
    multiplier_func::Union{Nothing, Function}
    constraint_func::Function
end

function ModelTimeSeriesConstraintInputs(;
    constraint_name,
    variable_name,
    bin_variable_name = nothing,
    parameter_name,
    forecast_label,
    multiplier_func,
    constraint_func,
)
    return ModelTimeSeriesConstraintInputs(
        constraint_name,
        variable_name,
        bin_variable_name,
        parameter_name,
        forecast_label,
        multiplier_func,
        constraint_func,
    )
end

struct DeviceConstraintInputs
    range_constraint_inputs::Vector{ModelRangeConstraintInputs}
    timeseries_range_constraint_inputs::Vector{ModelTimeSeriesConstraintInputs}
    custom_psi_container_func::Union{Nothing, Function}
end

function DeviceConstraintInputs(;
    range_constraint_inputs = Vector{ModelRangeConstraintInputs}(),
    timeseries_range_constraint_inputs = Vector{ModelTimeSeriesConstraintInputs}(),
    custom_psi_container_func = nothing,
)
    return DeviceConstraintInputs(
        range_constraint_inputs,
        timeseries_range_constraint_inputs,
        custom_psi_container_func,
    )
end

function device_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    inputs::DeviceConstraintInputs,
) where {T <: PSY.Device, U <: AbstractDeviceFormulation}
    model_range_constraints = inputs.range_constraint_inputs
    model_timeseries_range_constraints = inputs.timeseries_range_constraint_inputs
    custom_psi_container_func = inputs.custom_psi_container_func

    # TODO: Could be faster if we iterate over the devices first.
    for mrc in model_range_constraints
        constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
        cons_name = constraint_name(mrc.constraint_name, T)
        var_name = variable_name(mrc.variable_name, T)
        bin_var_name = isnothing(mrc.bin_variable_name) ? mrc.bin_variable_name :
            variable_name(mrc.bin_variable_name, T)
        for (i, dev) in enumerate(devices)
            dev_name = PSY.get_name(dev)
            constraint_info = DeviceRangeConstraintInfo(dev_name, mrc.limits_func(dev))
            add_device_services!(constraint_info, dev, model)
            constraint_infos[i] = constraint_info
        end

        mrc.constraint_func(
            psi_container,
            RangeConstraintInputs(constraint_infos, cons_name, var_name, bin_var_name),
        )
    end

    for tsmrc in model_timeseries_range_constraints
        constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
        for (i, dev) in enumerate(devices)
            ts_vector = get_time_series(psi_container, dev, tsmrc.forecast_label)
            constraint_info =
                DeviceTimeSeriesConstraintInfo(dev, tsmrc.multiplier_func, ts_vector)
            add_device_services!(constraint_info.range, dev, model)
            constraint_infos[i] = constraint_info
        end

        ts_inputs = TimeSeriesConstraintInputs(
            constraint_infos,
            constraint_name(tsmrc.constraint_name, T),
            variable_name(tsmrc.variable_name, T),
            isnothing(tsmrc.bin_variable_name) ? nothing :
                variable_name(tsmrc.bin_variable_name, T),
            isnothing(tsmrc.parameter_name) ? nothing :
                UpdateRef{T}(tsmrc.parameter_name, tsmrc.forecast_label),
        )
        tsmrc.constraint_func(psi_container, ts_inputs)
    end

    if !isnothing(custom_psi_container_func)
        custom_psi_container_func(psi_container, devices, U)
    end
end
