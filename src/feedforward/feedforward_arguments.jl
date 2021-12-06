function add_feedforward_arguments!(
    container::OptimizationContainer,
    model::DeviceModel,
    devices::IS.FlattenIteratorWrapper{V},
) where {V <: PSY.Component}
    for ff in get_feedforwards(model)
        @debug "arguments" ff V _group = LOG_GROUP_FEEDFORWARDS_CONSTRUCTION
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
        @debug "arguments" ff V _group = LOG_GROUP_FEEDFORWARDS_CONSTRUCTION
        contributing_devices = get_contributing_devices(model)
        add_feedforward_arguments!(container, model, contributing_devices, ff)
    end
    return
end

function add_feedforward_arguments!(
    container::OptimizationContainer,
    model::DeviceModel,
    devices::IS.FlattenIteratorWrapper{T},
    ff::AbstractAffectFeedforward,
) where {T <: PSY.Component}
    parameter_type = get_default_parameter_type(ff, T)
    source_key = get_optimization_container_key(ff)
    add_parameters!(container, parameter_type, source_key, model, devices)
    return
end

function add_feedforward_arguments!(
    container::OptimizationContainer,
    model::ServiceModel{SR},
    contributing_devices::Vector{T},
    ff::AbstractAffectFeedforward,
) where {T <: PSY.Component, SR <: PSY.AbstractReserve}
    parameter_type = get_default_parameter_type(ff, SR)
    source_key = get_optimization_container_key(ff)
    add_parameters!(container, parameter_type, source_key, model, contributing_devices)
    return
end

function _handle_active_power_semicontinuous_feedforward!(
    container::OptimizationContainer,
    model::DeviceModel,
    devices::IS.FlattenIteratorWrapper{T},
    source_key::VariableKey,
    parameter_type::OnStatusParameter,
) where {T <: PSY.Component}
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
    ff::SemiContinuousFeedforward,
) where {T <: PSY.Component}
    parameter_type = get_default_parameter_type(ff, T)
    source_key = get_optimization_container_key(ff)
    add_parameters!(container, parameter_type, source_key, model, devices)
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
                "SemiContinuousFeedforward not implemented for variable $(get_entry_type(var_key))",
            )
        end
    end
    return
end

function add_feedforward_arguments!(
    container::OptimizationContainer,
    model::DeviceModel,
    devices::IS.FlattenIteratorWrapper{T},
    ff::EnergyTargetFeedforward,
) where {T <: PSY.Component}
    parameter_type = get_default_parameter_type(ff, T)
    source_key = get_optimization_container_key(ff)
    add_parameters!(container, parameter_type, source_key, model, devices)
    add_variables!(container, EnergyShortageVariable, devices, get_formulation(model)())
    return
end
