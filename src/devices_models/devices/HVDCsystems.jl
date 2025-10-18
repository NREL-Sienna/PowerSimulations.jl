#! format: off
get_variable_binary(::ActivePowerVariable, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = false
get_variable_warm_start_value(::ActivePowerVariable, d::PSY.InterconnectingConverter, ::AbstractConverterFormulation) = PSY.get_active_power(d)
get_variable_lower_bound(::ActivePowerVariable, d::PSY.InterconnectingConverter, ::AbstractConverterFormulation) = PSY.get_active_power_limits(d).min
get_variable_upper_bound(::ActivePowerVariable, d::PSY.InterconnectingConverter, ::AbstractConverterFormulation) = PSY.get_active_power_limits(d).max
get_variable_multiplier(_, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = 1.0


function _get_flow_bounds(d::PSY.TModelHVDCLine)
    check_hvdc_line_limits_consistency(d)
    from_min = PSY.get_active_power_limits_from(d).min
    to_min = PSY.get_active_power_limits_to(d).min
    from_max = PSY.get_active_power_limits_from(d).max
    to_max = PSY.get_active_power_limits_to(d).max

    if from_min >= 0.0 && to_min >= 0.0
        min_rate = min(from_min, to_min)
    elseif from_min <= 0.0 && to_min <= 0.0
        min_rate = max(from_min, to_min)
    elseif from_min <= 0.0 && to_min >= 0.0
        min_rate = from_min
    elseif to_min <= 0.0 && from_min >= 0.0
        min_rate = to_min
    else
        @assert false
    end

    if from_max >= 0.0 && to_max >= 0.0
        max_rate = min(from_max, to_max)
    elseif from_max <= 0.0 && to_max <= 0.0
        max_rate = max(from_max, to_max)
    elseif from_max <= 0.0 && to_max >= 0.0
        max_rate = from_max
    elseif from_max >= 0.0 && to_max <= 0.0
        max_rate = to_max
    else
        @assert false
    end

    return min_rate, max_rate
end


get_variable_binary(::FlowActivePowerVariable, ::Type{PSY.TModelHVDCLine}, ::AbstractBranchFormulation) = false
get_variable_binary(::DCLineCurrent, ::Type{PSY.TModelHVDCLine}, ::AbstractBranchFormulation) = false
get_variable_warm_start_value(::FlowActivePowerVariable, d::PSY.TModelHVDCLine, ::AbstractBranchFormulation) = PSY.get_active_power_flow(d)
get_variable_lower_bound(::FlowActivePowerVariable, d::PSY.TModelHVDCLine, ::AbstractBranchFormulation) = _get_flow_bounds(d)[1]
get_variable_upper_bound(::FlowActivePowerVariable, d::PSY.TModelHVDCLine, ::AbstractBranchFormulation) = _get_flow_bounds(d)[2]
# This is an approximation for DC lines since the actual current limit depends on the voltage, that is a variable in the optimization problem
function get_variable_lower_bound(::DCLineCurrent, d::PSY.TModelHVDCLine, ::AbstractBranchFormulation)
    p_min_flow = _get_flow_bounds(d)[1]
    arc = PSY.get_arc(d)
    bus_from = arc.from
    bus_to = arc.to
    max_v = max(PSY.get_magnitude(bus_from), PSY.get_magnitude(bus_to))
    return p_min_flow / max_v
end
# This is an approximation for DC lines since the actual current limit depends on the voltage, that is a variable in the optimization problem
function get_variable_upper_bound(::DCLineCurrent, d::PSY.TModelHVDCLine, ::AbstractBranchFormulation)
    p_max_flow = _get_flow_bounds(d)[2]
    arc = PSY.get_arc(d)
    bus_from = arc.from
    bus_to = arc.to
    max_v = max(PSY.get_magnitude(bus_from), PSY.get_magnitude(bus_to))
    return p_max_flow / max_v
end
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

############################################
############## Expressions #################
############################################

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: Union{ActivePowerBalance, DCCurrentBalance},
    U <: Union{FlowActivePowerVariable, DCLineCurrent},
    V <: PSY.TModelHVDCLine,
    W <: Union{LossLessLine, DCLossyLine},
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
    device_model::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: ActivePowerBalance,
    U <: ActivePowerVariable,
    V <: PSY.InterconnectingConverter,
    W <: AbstractConverterFormulation,
    X <: AreaPTDFPowerModel,
}
    _add_to_expression!(
        container,
        T,
        U,
        devices,
        device_model,
        network_model
    )
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    device_model::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: ActivePowerBalance,
    U <: ActivePowerVariable,
    V <: PSY.InterconnectingConverter,
    W <: AbstractConverterFormulation,
    X <: PM.AbstractPowerModel,
}
    _add_to_expression!(
        container,
        T,
        U,
        devices,
        device_model,
        network_model,
    )
    return
end

function _add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: ActivePowerBalance,
    U <: ActivePowerVariable,
    V <: PSY.InterconnectingConverter,
    W <: AbstractConverterFormulation,
    X <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), V)
    expression_dc = get_expression(container, T(), PSY.DCBus)
    expression_ac = get_expression(container, T(), PSY.ACBus)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        bus_number_dc = PSY.get_number(PSY.get_dc_bus(d))
        bus_number_ac = PSY.get_number(PSY.get_bus(d))
        _add_to_jump_expression!(
            expression_ac[bus_number_ac, t],
            variable[name, t],
            1.0,
        )
        _add_to_jump_expression!(
            expression_dc[bus_number_dc, t],
            variable[name, t],
            -1.0,
        )
    end
    return
end


function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    network_model::NetworkModel{AreaPTDFPowerModel},
) where {
    T <: ActivePowerBalance,
    U <: ActivePowerVariable,
    V <: PSY.InterconnectingConverter,
    W <: AbstractConverterFormulation,
}
    error("AreaPTDFPowerModel doesn't support InterconnectingConverter")
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    network_model::NetworkModel{PTDFPowerModel},
) where {
    T <: ActivePowerBalance,
    U <: ActivePowerVariable,
    V <: PSY.InterconnectingConverter,
    W <: AbstractConverterFormulation,
}
    variable = get_variable(container, U(), V)
    expression_dc = get_expression(container, T(), PSY.DCBus)
    expression_ac = get_expression(container, T(), PSY.ACBus)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        bus_number_dc = PSY.get_number(PSY.get_dc_bus(d))
        bus_number_ac = PSY.get_number(PSY.get_bus(d))
        _add_to_jump_expression!(
            expression_ac[bus_number_ac, t],
            variable[name, t],
            1.0,
        )
        _add_to_jump_expression!(
            expression_dc[bus_number_dc, t],
            variable[name, t],
            -1.0,
        )
    end
    return
end

function add_to_expression!(
    ::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    network_model::NetworkModel{AreaBalancePowerModel},
) where {
    T <: ActivePowerBalance,
    U <: ActivePowerVariable,
    V <: PSY.InterconnectingConverter,
    W <: AbstractConverterFormulation,
}
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {
    T <: ActivePowerBalance,
    U <: ActivePowerVariable,
    V <: PSY.InterconnectingConverter,
    W <: AbstractConverterFormulation,
}

    variable = get_variable(container, U(), V)
    expression_dc = get_expression(container, T(), PSY.DCBus)
    sys_expr = get_expression(container, T(), PSY.System)
    for d in devices
        name = PSY.get_name(d)
        device_bus = PSY.get_bus(d)
        ref_bus = get_reference_bus(network_model, device_bus)
        bus_number_dc = PSY.get_number(PSY.get_dc_bus(d))
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                sys_expr[ref_bus, t],
                variable[name, t],
                get_variable_multiplier(U(), V, W()),
            )
            _add_to_jump_expression!(
                expression_dc[bus_number_dc, t],
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
    network_model::NetworkModel{X},
) where {
    T <: ActivePowerBalance,
    U <: ActivePowerVariable,
    V <: PSY.InterconnectingConverter,
    W <: AbstractConverterFormulation,
    X <: PTDFPowerModel
}
    variable = get_variable(container, U(), V)
    expression_dc = get_expression(container, T(), PSY.DCBus)
    expression_ac = get_expression(container, T(), PSY.ACBus)
    sys_expr = get_expression(container, T(), PSY.System)
    for d in devices
        name = PSY.get_name(d)
        device_bus = PSY.get_bus(d)
        bus_number_ac = PSY.get_number(device_bus)
        ref_bus = get_reference_bus(network_model, device_bus)
        bus_number_dc = PSY.get_number(PSY.get_dc_bus(d))
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                sys_expr[ref_bus, t],
                variable[name, t],
                get_variable_multiplier(U(), V, W()),
            )
            _add_to_jump_expression!(
                expression_ac[bus_number_ac, t],
                variable[name, t],
                get_variable_multiplier(U(), V, W()),
            )
            _add_to_jump_expression!(
                expression_dc[bus_number_dc, t],
                variable[name, t],
                -1.0,
        )
        end
    end

    return
end

############################################
############## Constraints #################
############################################

function add_constraints!(
        container::OptimizationContainer,
        ::Type{DCLineCurrentConstraint},
        devices::IS.FlattenIteratorWrapper{T},
        model::DeviceModel{T, U},
        network_model::NetworkModel{V},
    ) where {T <: PSY.TModelHVDCLine, U <: DCLossyLine, V <: PM.AbstractPowerModel}
    variable = get_variable(container, DCLineCurrent(), T)
    dc_voltage = get_variable(container, DCVoltage(), PSY.DCBus)
    time_steps = get_time_steps(container)
    constraints = add_constraints_container!(
        container,
        DCLineCurrentConstraint(),
        T,
        PSY.get_name.(devices),
        time_steps,
    )

    for d in devices
        arc = PSY.get_arc(d)
        from_bus_name = PSY.get_name(arc.from)
        to_bus_name = PSY.get_name(arc.to)
        name = PSY.get_name(d)
        r = PSY.get_r(d)
        if iszero(r)
            for t in time_steps
                constraints[name, t] = JuMP.@constraint(
                    get_jump_model(container),
                    dc_voltage[from_bus_name, t] == dc_voltage[to_bus_name, t]
                )
            end
        else
            for t in get_time_steps(container)
                constraints[name, t] = JuMP.@constraint(
                    get_jump_model(container),
                    variable[name, t] == (dc_voltage[from_bus_name, t] - dc_voltage[to_bus_name, t]) / r
                )
            end
        end
    end
    return
end

############################################
########### Objective Function #############
############################################

function objective_function!(
    ::OptimizationContainer,
    ::IS.FlattenIteratorWrapper{PSY.InterconnectingConverter},
    ::DeviceModel{PSY.InterconnectingConverter, LossLessConverter},
    ::Type{<:PM.AbstractPowerModel},
)
    return
end
