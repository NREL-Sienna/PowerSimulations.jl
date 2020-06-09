
struct ActivePowerConstraintsInputs
    limits::Function
    range_constraint::Function
    multiplier::Union{Nothing, Function}
    timeseries_func::Union{Nothing, Function}
    parameter_name::Union{Nothing, String}
    constraint_name::String
    variable_name::String
    bin_variable_name::Union{Nothing, String}
    forecast_label::String

    # Force using kwargs to avoid ordering mistakes.
    function ActivePowerConstraintsInputs(;
        limits,
        range_constraint,
        multiplier,
        timeseries_func,
        parameter_name,
        constraint_name,
        variable_name,
        bin_variable_name,
        forecast_label,
    )
        return new(
            limits,
            range_constraint,
            multiplier,
            timeseries_func,
            parameter_name,
            constraint_name,
            variable_name,
            bin_variable_name,
            forecast_label,
        )
    end
end

"""
Construct ActivePowerConstraintsInputs for specific types.
"""
function ActivePowerConstraintsInputs(
    ::Type{T},
    ::Type{U},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.Device, U <: AbstractDeviceFormulation}
    error("ActivePowerConstraintsInputs is not implemented for type $T/$U")
end

"""
Default implementation to add activepower constraints.

Users of this function must implement a method for [`ActivePowerConstraintsInputs`](@ref)
for their specific types.
Users may also implement custom activepower_constraints! methods.
"""
function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.Device, U <: AbstractDeviceFormulation}
    use_parameters = model_has_parameters(psi_container)
    use_forecasts = model_uses_forecasts(psi_container)
    @assert !(use_parameters && !use_forecasts)
    inputs = ActivePowerConstraintsInputs(T, U, use_parameters, use_forecasts)

    cons_name = constraint_name(inputs.constraint_name, T)
    var_name = variable_name(inputs.variable_name, T)
    bin_var_name = isnothing(inputs.bin_variable_name) ? inputs.bin_variable_name :
        variable_name(inputs.bin_variable_name, T)
    param_ref =
        use_parameters ? UpdateRef{T}(inputs.parameter_name, inputs.forecast_label) :
        nothing
    limits_func = inputs.limits
    range_constraint_func = inputs.range_constraint
    forecast_label = inputs.forecast_label
    multiplier_func = inputs.multiplier
    timeseries_func = inputs.timeseries_func

    if !use_parameters && !use_forecasts
        constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
        for (i, dev) in enumerate(devices)
            name = PSY.get_name(dev)
            limits = limits_func(dev)
            constraint_info = DeviceRangeConstraintInfo(name, limits)
            add_device_services!(constraint_info, dev, model)
            constraint_infos[i] = constraint_info
        end

        rc_inputs =
            RangeConstraintInputs(constraint_infos, cons_name, var_name, bin_var_name)
        range_constraint_func(psi_container, rc_inputs)
        return
    end

    if !isnothing(timeseries_func)
        constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
        for (i, dev) in enumerate(devices)
            ts_vector = get_time_series(psi_container, dev, forecast_label)
            constraint_info =
                DeviceTimeSeriesConstraintInfo(dev, multiplier_func, ts_vector)
            add_device_services!(constraint_info.range, dev, model)
            constraint_infos[i] = constraint_info
        end

        ts_inputs = TimeSeriesConstraintInputs(
            constraint_infos,
            cons_name,
            var_name,
            bin_var_name,
            param_ref,
        )
        timeseries_func(psi_container, ts_inputs)
    end

    return
end
