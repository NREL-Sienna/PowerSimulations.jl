struct NodalExpressionSpec
    forecast_label::String
    # TODO: Remove this hack when updating simulation execution. For now is needed
    # to store parameters from String.
    parameter_name::Union{String, Symbol}
    peak_value_function::Function
    multiplier::Float64
    update_ref::Type
end

"""
Construct NodalExpressionSpec for specific types.
"""
function NodalExpressionSpec(
    ::Type{T},
    ::Type{U},
    use_forecasts::Bool,
) where {T <: PSY.Device, U <: PM.AbstractPowerModel}
    error("NodalExpressionSpec is not implemented for type $T/$U")
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
    ::Type{U},
) where {T <: PSY.Device, U <: PM.AbstractPowerModel}
    nodal_expression!(optimization_container, devices, PM.AbstractActivePowerModel)
    _nodal_expression!(optimization_container, devices, U, :nodal_balance_reactive)
    return
end

function nodal_expression!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{U},
) where {T <: PSY.Device, U <: PM.AbstractActivePowerModel}
    _nodal_expression!(optimization_container, devices, U, :nodal_balance_active)
    return
end

function nodal_expression!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{CopperPlatePowerModel},
) where {T <: PSY.Device}
    _nodal_expression!(optimization_container, devices, CopperPlatePowerModel, :system_balance_active)
    return
end

function _nodal_expression!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{U},
    expression_name::Symbol,
) where {T <: PSY.Device, U <: PM.AbstractPowerModel}
    # Run the Active Power Loop.
    parameters = model_has_parameters(optimization_container)
    use_forecast_data = model_uses_forecasts(optimization_container)
    spec = NodalExpressionSpec(T, U, use_forecast_data)
    forecast_label = use_forecast_data ? spec.forecast_label : ""
    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(optimization_container, d, forecast_label)
        @debug "building constraint info" get_name(d), summary(ts_vector)
        constraint_info =
            DeviceTimeSeriesConstraintInfo(d, spec.peak_value_function, ts_vector)
        constraint_infos[ix] = constraint_info
    end
    if parameters
        @debug spec.update_ref, spec.parameter_name forecast_label
        include_parameters!(
            optimization_container,
            constraint_infos,
            UpdateRef{spec.update_ref}(spec.parameter_name, forecast_label),
            expression_name,
            spec.multiplier,
        )
        return
    else
        for constraint_info in constraint_infos
            for t in model_time_steps(optimization_container)
                ix = U == CopperPlatePowerModel ? t : (constraint_info.bus_number, t)
                add_to_expression!(
                    optimization_container.expressions[expression_name],
                    spec.multiplier *
                    constraint_info.multiplier *
                    constraint_info.timeseries[t],
                    ix...,
                )
            end
        end
    end
end
