#! format: off
get_variable_binary(::ActivePowerVariable, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = false
get_variable_warm_start_value(::ActivePowerVariable, d::PSY.InterconnectingConverter, ::AbstractConverterFormulation) = PSY.get_active_power(d)
get_variable_lower_bound(::ActivePowerVariable, d::PSY.InterconnectingConverter, ::AbstractConverterFormulation) = PSY.get_active_power_limits(d).min
get_variable_upper_bound(::ActivePowerVariable, d::PSY.InterconnectingConverter, ::AbstractConverterFormulation) = PSY.get_active_power_limits(d).max
get_variable_multiplier(_, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = 1.0

get_variable_binary(::FlowActivePowerVariable, ::Type{PSY.TModelHVDCLine}, ::AbstractBranchFormulation) = false
get_variable_warm_start_value(::FlowActivePowerVariable, d::PSY.TModelHVDCLine, ::AbstractBranchFormulation) = PSY.get_active_power_flow(d)
get_variable_lower_bound(::FlowActivePowerVariable, d::PSY.TModelHVDCLine, ::AbstractBranchFormulation) = -PSY.get_rate(d)
get_variable_upper_bound(::FlowActivePowerVariable, d::PSY.TModelHVDCLine, ::AbstractBranchFormulation) = PSY.get_rate(d)
get_variable_multiplier(_, ::Type{PSY.TModelHVDCLine}, ::AbstractBranchFormulation) = 1.0

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
    U <: FlowActivePowerVariable,
    V <: PSY.TModelHVDCLine,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), PSY.DCBus)
    for d in devices
        arc = PSY.get_arc(d)
        to_bus_number = PSY.get_number(PSY.get_to(arc))
        from_bus_number = PSY.get_number(PSY.get_from(arc))
        for t in get_time_steps(container)
            name = PSY.get_name(d)
            _add_to_jump_expression!(
                expression[to_bus_number, t],
                variable[name, t],
                1.0,
            )
            _add_to_jump_expression!(
                expression[from_bus_number, t],
                variable[name, t],
                -1.0,
            )
        end
    end
    return
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


# This method might need to be moved to support Meshed HVDC to the network constructor file
function add_constraints!(
    container::OptimizationContainer,
    ::Type{NodalBalanceActiveConstraint},
    devices::IS.FlattenIteratorWrapper{PSY.InterconnectingConverter},
    model::DeviceModel{PSY.InterconnectingConverter, LossLessConverter},
    ::Type{<:PM.AbstractActivePowerModel},
)
    time_steps = get_time_steps(container)
    dc_expr = get_expression(container,  ActivePowerBalanceDC(), PSY.DCBus)
    balance_constraint = add_constraints_container!(
        container,
        NodalBalanceActiveConstraint(),
        PSY.DCBus,
        axes(dc_expr)[1],
        time_steps,
    )
    for d in devices
        dc_bus_no = PSY.get_number(PSY.get_dc_bus(d))
        for t in time_steps
            balance_constraint[dc_bus_no, t] = JuMP.@constraint(
                get_jump_model(container),
                dc_expr[dc_bus_no, t] == 0
            )
        end
    end
    return
end