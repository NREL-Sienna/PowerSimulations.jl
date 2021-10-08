function add_feedforward_arguments!(
    container::OptimizationContainer,
    model::DeviceModel,
    devices::IS.FlattenIteratorWrapper{V},
) where {V <: PSY.Component}
    for ff in get_feedforwards(model)
        @debug "arguments" ff V
        add_feedforward_arguments!(container, model, devices, ff)
    end
    return
end

function add_feedforward_arguments!(
    container::OptimizationContainer,
    model::ServiceModel,
    service::V,
) where {V <: PSY.AbstractReserve}
    for ff in get_feedforwards(model)
        @debug "arguments" ff V
        contributing_devices = get_contributing_devices(model)
        add_feedforward_arguments!(container, model, contributing_devices, ff)
    end
    return
end

function add_feedforward_arguments!(
    container::OptimizationContainer,
    model::DeviceModel,
    devices::IS.FlattenIteratorWrapper{T},
    ff::AbstractAffectFeedForward,
) where {T <: PSY.Component}
    parameter_type = get_default_parameter_type(ff, T)
    for var_key in get_affected_values(ff)
        add_parameters!(container, parameter_type, var_key, model, devices)
    end
    return
end

function add_feedforward_arguments!(
    container::OptimizationContainer,
    model::ServiceModel{SR},
    devices::Vector{T},
    ff::AbstractAffectFeedForward,
) where {T <: PSY.Component, SR <: PSY.AbstractReserve}
    parameter_type = get_default_parameter_type(ff, SR)
    for var_key in get_affected_values(ff)
        add_parameters!(container, parameter_type, var_key, model, devices)
    end
    return
end

function _handle_active_power_semicontinuous_feedforward!(
    container::OptimizationContainer,
    model::DeviceModel,
    devices::IS.FlattenIteratorWrapper{T},
    var_key::VariableKey,
    parameter_type::OnStatusParameter,
) where {T <: PSY.Component}
    add_parameters!(container, parameter_type, var_key, model, devices)
    add_to_expression!(
        container,
        ActivePowerRangeExpressionLB,
        parameter_type,
        devices,
        model,
    )
    add_to_expression!(
        container,
        ActivePowerRangeExpressionUB,
        parameter_type,
        devices,
        model,
    )
    return
end

function add_feedforward_arguments!(
    container::OptimizationContainer,
    model::DeviceModel,
    devices::IS.FlattenIteratorWrapper{T},
    ff::SemiContinuousFeedForward,
) where {T <: PSY.Component}
    parameter_type = get_default_parameter_type(ff, T)
    for var_key in get_affected_values(ff)
        if get_entry_type(var_key) == ActivePowerVariable ||
           get_entry_type(var_key) == PowerAboveMinimumVariable
            _handle_active_power_semicontinuous_feedforward!(
                container,
                model,
                devices,
                var_key,
                parameter_type,
            )
        else
            error(
                "SemiContinuousFeedForward not implemented for variable $(get_entry_type(var_key))",
            )
        end
    end
    return
end
