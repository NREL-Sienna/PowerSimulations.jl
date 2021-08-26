function _add_to_expression!(
    expression_array::T,
    ix::Int,
    jx::Int,
    var::JV,
    multiplier::Float64,
) where {T, JV <: JuMP.AbstractVariableRef}
    if isassigned(expression_array, ix, jx)
        JuMP.add_to_expression!(expression_array[ix, jx], multiplier, var)
    else
        expression_array[ix, jx] = multiplier * var
    end

    return
end

function _add_to_expression!(
    expression_array::T,
    ix::Int,
    jx::Int,
    var::JV,
    multiplier::Float64,
    constant::Float64,
) where {T, JV <: JuMP.AbstractVariableRef}
    if isassigned(expression_array, ix, jx)
        JuMP.add_to_expression!(expression_array[ix, jx], multiplier, var)
        JuMP.add_to_expression!(expression_array[ix, jx], constant)
    else
        expression_array[ix, jx] = multiplier * var + constant
    end

    return
end

function _add_to_expression!(
    expression_array::T,
    ix::Int,
    jx::Int,
    value::Float64,
) where {T}
    if isassigned(expression_array, ix, jx)
        expression_array[ix, jx].constant += value
    else
        expression_array[ix, jx] = zero(eltype(expression_array)) + value
    end

    return
end

function _add_to_expression!(
    expression_array::T,
    ix::Int,
    jx::Int,
    parameter::PJ.ParameterRef,
) where {T}
    if isassigned(expression_array, ix, jx)
        JuMP.add_to_expression!(expression_array[ix, jx], 1.0, parameter)
    else
        expression_array[ix, jx] = zero(eltype(expression_array)) + parameter
    end

    return
end

"""
Default implementation to add nodal expressions.

Users of this function must implement a method for [`NodalExpressionSpec`](@ref)
for their specific types.
Users may also implement custom add_to_expression! methods.
"""
function add_to_expression!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    parameter::TimeSeriesParameter,
) where {T <: PSY.Device}
    # Run the Active Power Loop.
    spec = NodalExpressionSpec(T, parameter)
    _add_to_expression!(container, devices, spec)
    return
end

function _add_to_expression!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    spec,
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
