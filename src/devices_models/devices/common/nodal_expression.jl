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
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    parameter::TimeSeriesParameter,
) where {T <: PSY.Device}
    # Run the Active Power Loop.
    spec = NodalExpressionSpec(T, parameter)
    _nodal_expression!(container, devices, spec)
    return
end

function _nodal_expression!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    spec::NodalExpressionSpec,
) where {T <: PSY.Device}
    parameters = built_for_simulation(container)
    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    forecast_name = get_name(spec.parameter)
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(container, d, forecast_name)
        @debug "building constraint info" get_name(d), summary(ts_vector)
        constraint_info =
            DeviceTimeSeriesConstraintInfo(d, spec.peak_value_function, ts_vector)
        constraint_infos[ix] = constraint_info
    end
    if parameters
        @debug spec.parameter_name forecast_name
        include_parameters!(
            container,
            constraint_infos,
            spec.parameter,
            T,
            spec.expression,
            spec.multiplier,
        )
        return
    else
        for constraint_info in constraint_infos
            for t in get_time_steps(container)
                add_to_expression!(
                    container.expressions[spec.expression],
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
