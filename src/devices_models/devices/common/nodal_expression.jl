struct NodalExpressionSpec
    parameter::RightHandSideParameter
    device_type::Type{<:Union{PSY.Component, PSY.Device}}
    peak_value_function::Function
    multiplier::Float64
    expression::Symbol
end

"""
Construct NodalExpressionSpec for specific types.
"""
function NodalExpressionSpec(
    ::T,
    ::Type{U},
    use_forecasts::Bool,
) where {T <: PSY.Device, U <: TimeSeriesParameter}
    error("NodalExpressionSpec is not implemented for type $T $U")
end

"""
Default implementation to add nodal expressions.

Users of this function must implement a method for [`NodalExpressionSpec`](@ref)
for their specific types.
Users may also implement custom nodal_expression! methods.
"""
function nodal_expression!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    parameter::TimeSeriesParameter,
) where {T <: PSY.Device}
    # Run the Active Power Loop.
    use_forecast_data = model_uses_forecasts(optimization_container)
    spec = NodalExpressionSpec(T, parameter, use_forecast_data)
    _nodal_expression!(optimization_container, devices, spec)
    return
end

function _nodal_expression!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    spec::NodalExpressionSpec,
) where {T <: PSY.Device}
    parameters = model_has_parameters(optimization_container)
    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    forecast_name = get_label(spec.parameter)
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(optimization_container, d, forecast_name)
        @debug "building constraint info" get_name(d), summary(ts_vector)
        constraint_info =
            DeviceTimeSeriesConstraintInfo(d, spec.peak_value_function, ts_vector)
        constraint_infos[ix] = constraint_info
    end
    if parameters
        @debug spec.parameter_name forecast_name
        include_parameters!(
            optimization_container,
            constraint_infos,
            spec.parameter,
            T,
            spec.expression,
            spec.multiplier,
        )
        return
    else
        for constraint_info in constraint_infos
            for t in model_time_steps(optimization_container)
                add_to_expression!(
                    optimization_container.expressions[spec.expression],
                    constraint_info.bus_number,
                    t,
                    spec.multiplier *
                    constraint_info.multiplier *
                    constraint_info.timeseries[t],
                )
            end
        end
    end
end
