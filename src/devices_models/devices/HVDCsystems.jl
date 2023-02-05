#! format: off
get_variable_binary(::ActivePowerVariable, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = false
get_variable_warm_start_value(::ActivePowerVariable, d::PSY.InterconnectingConverter, ::AbstractConverterFormulation) = PSY.get_active_power(d)
get_variable_lower_bound(::ActivePowerVariable, d::PSY.InterconnectingConverter, ::AbstractConverterFormulation) = PSY.get_active_power_limits(d).min
get_variable_upper_bound(::ActivePowerVariable, d::PSY.InterconnectingConverter, ::AbstractConverterFormulation) = PSY.get_active_power_limits(d).max
get_variable_multiplier(_, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = 1.0

requires_initialization(::AbstractConverterFormulation) = false
requires_initialization(::LossLessLine) = false

function get_initial_conditions_device_model(
    ::OperationModel,
    model::DeviceModel{PSY.InterconnectingConverter, <:AbstractConverterFormulation},
)
    return model
end

function get_initial_conditions_device_model(
    ::OperationModel,
    model::DeviceModel{PSY.TModelHVDCLine, LossLessLine},
)
    return model
end


function get_default_time_series_names(
    ::Type{PSY.InterconnectingConverter},
    ::Type{<:AbstractConverterFormulation},
)
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

function get_default_time_series_names(
    ::Type{PSY.TModelHVDCLine},
    ::Type{<:AbstractBranchFormulation},
)
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

function get_default_attributes(
    ::Type{PSY.InterconnectingConverter},
    ::Type{<:AbstractConverterFormulation},
)
    return Dict{String, Any}()
end

function get_default_attributes(
    ::Type{PSY.TModelHVDCLine},
    ::Type{<:AbstractBranchFormulation},
)
    return Dict{String, Any}()
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ActivePowerBalanceDC,
    U <: ActivePowerVariable,
    V <: PSY.InterconnectingConverter,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), PSY.DCBus)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        bus_number = PSY.get_number(PSY.get_dc_bus(d))
        _add_to_jump_expression!(
            expression[bus_number, t],
            variable[name, t],
            get_variable_multiplier(U(), V, W()),
        )
    end
    return
end
