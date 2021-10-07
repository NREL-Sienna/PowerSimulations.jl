function add_expressions!(
    container::OptimizationContainer,
    ::Type{T},
    devices::U,
    model::DeviceModel{D, W};
    meta = CONTAINER_KEY_EMPTY_META,
) where {
    T <: ExpressionType,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    add_expression_container!(container, T(), D, names, time_steps; meta = meta)
    return
end

function add_expressions!(
    container::OptimizationContainer,
    ::Type{T},
    devices::U,
    model::ServiceModel{V, W},
) where {
    T <: ExpressionType,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    V <: PSY.Reserve,
    W <: AbstractReservesFormulation,
} where {D <: PSY.Component}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    add_expression_container!(container, T(), D, names, time_steps)
    return
end

# Note: add_to_jump_expression! are legacy when more control was needed over the calls to
# add_to_expression. These might be removed post JuMP 1.0 release.
function add_to_jump_expression!(
    expression::T,
    var::JuMP.VariableRef,
    multiplier::Float64,
) where {T <: JuMP.AbstractJuMPScalar}
    JuMP.add_to_expression!(expression, multiplier, var)
    return
end

function add_to_jump_expression!(
    expression::T,
    value::Float64,
) where {T <: JuMP.AbstractJuMPScalar}
    JuMP.add_to_expression!(expression, value)
    return
end

function add_to_jump_expression!(
    expression::T,
    parameter::PJ.ParameterRef,
    multiplier::Float64,
) where {T <: JuMP.AbstractJuMPScalar}
    PJ.add_to_expression!(expression, multiplier, parameter)
    return
end

function add_to_jump_expression!(
    expression::T,
    var::Union{JuMP.VariableRef, PJ.ParameterRef},
    multiplier::Float64,
    constant::Float64,
) where {T <: JuMP.AbstractJuMPScalar}
    add_to_jump_expression!(expression, constant)
    add_to_jump_expression!(expression, var, multiplier)
    return
end

function add_to_jump_expression!(
    expression::T,
    parameter::Float64,
    multiplier::Float64,
) where {T <: JuMP.AbstractJuMPScalar}
    add_to_jump_expression!(expression, parameter * multiplier)
    return
end

"""
Default implementation to add parameters to SystemBalanceExpressions
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: SystemBalanceExpressions,
    U <: TimeSeriesParameter,
    V <: PSY.Device,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    parameter = get_parameter_array(container, U(), V)
    multiplier = get_parameter_multiplier_array(container, U(), V)
    for d in devices, t in get_time_steps(container)
        bus_number = PSY.get_number(PSY.get_bus(d))
        name = get_name(d)
        add_to_jump_expression!(
            get_expression(container, T(), X)[bus_number, t],
            parameter[name, t],
            multiplier[name, t],
        )
    end
    return
end

"""
Default implementation to add variables to SystemBalanceExpressions
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: SystemBalanceExpressions,
    U <: VariableType,
    V <: PSY.Device,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), X)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        bus_number = PSY.get_number(PSY.get_bus(d))
        add_to_jump_expression!(
            expression[bus_number, t],
            variable[name, t],
            get_variable_multiplier(U(), V, W()),
        )
    end
    return
end

"""
Default implementation to add parameters to SystemBalanceExpressions
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: SystemBalanceExpressions,
    U <: TimeSeriesParameter,
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
    X <: CopperPlatePowerModel,
}
    parameter = get_parameter_array(container, U(), V)
    multiplier = get_parameter_multiplier_array(container, U(), V)
    for d in devices, t in get_time_steps(container)
        name = get_name(d)
        add_to_jump_expression!(
            get_expression(container, T(), X)[t],
            parameter[name, t],
            multiplier[name, t],
        )
    end
    return
end

"""
Default implementation to add variables to SystemBalanceExpressions
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ActivePowerBalance,
    U <: VariableType,
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
    X <: CopperPlatePowerModel,
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), X)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        add_to_jump_expression!(
            expression[t],
            variable[name, t],
            get_variable_multiplier(U(), V, W()),
        )
    end
    return
end

"""
Default implementation to add parameters to SystemBalanceExpressions
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: SystemBalanceExpressions,
    U <: TimeSeriesParameter,
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
    X <: Union{PTDFPowerModel, StandardPTDFModel},
}
    parameter = get_parameter_array(container, U(), V)
    multiplier = get_parameter_multiplier_array(container, U(), V)
    sys_expr = get_expression(container, T(), PSY.System)
    nodal_expr = get_expression(container, T(), PSY.Bus)
    for d in devices, t in get_time_steps(container)
        name = get_name(d)
        bus_no = PSY.get_number(PSY.get_bus(d))
        add_to_jump_expression!(sys_expr[t], parameter[name, t], multiplier[name, t])
        add_to_jump_expression!(
            nodal_expr[bus_no, t],
            parameter[name, t],
            multiplier[name, t],
        )
    end
    return
end

"""
Default implementation to add variables to SystemBalanceExpressions
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ActivePowerBalance,
    U <: VariableType,
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
    X <: Union{PTDFPowerModel, StandardPTDFModel},
}
    variable = get_variable(container, U(), V)
    sys_expr = get_expression(container, T(), PSY.System)
    nodal_expr = get_expression(container, T(), PSY.Bus)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        bus_no = PSY.get_number(PSY.get_bus(d))
        add_to_jump_expression!(
            sys_expr[t],
            variable[name, t],
            get_variable_multiplier(U(), V, W()),
        )
        add_to_jump_expression!(
            nodal_expr[bus_no, t],
            variable[name, t],
            get_variable_multiplier(U(), V, W()),
        )
    end
    return
end

"""
Implementation of add_to_expression! for lossless branch/network models
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ActivePowerBalance,
    U <: FlowActivePowerVariable,
    V <: PSY.Branch,
    W <: AbstractBranchFormulation,
    X <: PM.AbstractActivePowerModel,
}
    var = get_variable(container, U(), V)
    expression = get_expression(container, T(), X)
    for d in devices
        for t in get_time_steps(container)
            flow_variable = var[PSY.get_name(d), t]
            add_to_jump_expression!(
                expression[PSY.get_number(PSY.get_arc(d).from), t],
                flow_variable,
                -1.0,
            )
            add_to_jump_expression!(
                expression[PSY.get_number(PSY.get_arc(d).to), t],
                flow_variable,
                1.0,
            )
        end
    end
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: Union{ActivePowerRangeExpressionUB, ActivePowerRangeExpressionLB},
    U <: VariableType,
    V <: PSY.Device,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), V)
    if !has_expression(container, T(), V)
        add_expressions!(container, T, devices, model)
    end
    expression = get_expression(container, T(), V)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        add_to_jump_expression!(expression[name, t], variable[name, t], 1.0)
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::Union{Vector{V}, IS.FlattenIteratorWrapper{V}},
    model::ServiceModel{X, W},
) where {
    T <: ActivePowerRangeExpressionUB,
    U <: VariableType,
    V <: PSY.Component,
    X <: PSY.Reserve{PSY.ReserveUp},
    W <: AbstractReservesFormulation,
}
    service_name = get_service_name(model)
    variable = get_variable(container, U(), X, service_name)
    if !has_expression(container, T(), V)
        add_expressions!(container, T, devices, model)
    end
    expression = get_expression(container, T(), V)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        add_to_jump_expression!(expression[name, t], variable[name, t], 1.0)
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::Union{Vector{V}, IS.FlattenIteratorWrapper{V}},
    model::ServiceModel{X, W},
) where {
    T <: ActivePowerRangeExpressionLB,
    U <: VariableType,
    V <: PSY.Component,
    X <: PSY.Reserve{PSY.ReserveDown},
    W <: AbstractReservesFormulation,
}
    service_name = get_service_name(model)
    variable = get_variable(container, U(), X, service_name)
    if !has_expression(container, T(), V)
        add_expressions!(container, T, devices, model)
    end
    expression = get_expression(container, T(), V)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        add_to_jump_expression!(expression[name, t], variable[name, t], -1.0)
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::U,
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {
    T <: Union{ActivePowerRangeExpressionUB, ActivePowerRangeExpressionLB},
    U <: OnStatusParameter,
    V <: PSY.Device,
    W <: AbstractDeviceFormulation,
}
    parameter_array = get_parameter_array(container, U(), V)
    if !has_expression(container, T(), V)
        add_expressions!(container, T, devices, model)
    end
    expression = get_expression(container, T(), V)
    for d in devices, mult in get_expression_multiplier(U(), T(), d, W())
        for t in get_time_steps(container)
            name = PSY.get_name(d)
            add_to_jump_expression!(
                expression[name, t],
                parameter_array[name, t],
                mult,
                -mult,
            )
        end
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{U},
    model::ServiceModel{V, W},
    devices_template::Dict{Symbol, DeviceModel},
) where {U <: VariableType, V <: PSY.Reserve, W <: AbstractReservesFormulation}
    service_name = get_service_name(model)
    variable = get_variable(container, U(), V, service_name)
    contributing_devices_map = get_contributing_devices_map(model)
    for (device_type, devices) in contributing_devices_map
        device_model = get(devices_template, Symbol(device_type), nothing)
        isnothing(device_model) && continue
        expression_type = get_expression_type_for_reserve(U(), device_type, V)
        add_to_expression!(container, expression_type, U, devices, model)
    end
    return
end
