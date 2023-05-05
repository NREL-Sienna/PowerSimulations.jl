function add_expressions!(
    container::OptimizationContainer,
    ::Type{T},
    devices::U,
    model::DeviceModel{D, W},
) where {
    T <: ExpressionType,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    add_expression_container!(container, T(), D, names, time_steps)
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

# Note: add_to_jump_expression! are used to control depending on the parameter type used
# on the simulation.
function _add_to_jump_expression!(
    expression::T,
    var::JuMP.VariableRef,
    multiplier::Float64,
) where {T <: JuMP.AbstractJuMPScalar}
    JuMP.add_to_expression!(expression, multiplier, var)
    return
end

function _add_to_jump_expression!(
    expression::T,
    value::Float64,
) where {T <: JuMP.AbstractJuMPScalar}
    JuMP.add_to_expression!(expression, value)
    return
end

function _add_to_jump_expression!(
    expression::T,
    var::JuMP.VariableRef,
    multiplier::Float64,
    constant::Float64,
) where {T <: JuMP.AbstractJuMPScalar}
    _add_to_jump_expression!(expression, constant)
    _add_to_jump_expression!(expression, var, multiplier)
    return
end

function _add_to_jump_expression!(
    expression::T,
    parameter::Float64,
    multiplier::Float64,
) where {T <: JuMP.AbstractJuMPScalar}
    _add_to_jump_expression!(expression, parameter * multiplier)
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
    model::DeviceModel{V, W},
    ::NetworkModel{X},
) where {
    T <: SystemBalanceExpressions,
    U <: TimeSeriesParameter,
    V <: PSY.Device,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    param_container = get_parameter(container, U(), V)
    multiplier = get_multiplier_array(param_container)
    for d in devices, t in get_time_steps(container)
        bus_number = PSY.get_number(PSY.get_bus(d))
        name = PSY.get_name(d)
        _add_to_jump_expression!(
            get_expression(container, T(), X)[bus_number, t],
            get_parameter_column_refs(param_container, name)[t],
            multiplier[name, t],
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
    ::NetworkModel{X},
) where {
    T <: ActivePowerBalance,
    U <: OnStatusParameter,
    V <: PSY.ThermalGen,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    parameter = get_parameter_array(container, U(), V)

    for d in devices, t in get_time_steps(container)
        bus_number = PSY.get_number(PSY.get_bus(d))
        name = PSY.get_name(d)
        mult = get_expression_multiplier(U(), T(), d, W())
        _add_to_jump_expression!(
            get_expression(container, T(), X)[bus_number, t],
            parameter[name, t],
            mult,
        )
    end
    return
end

"""
Default implementation to add device variables to SystemBalanceExpressions
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::NetworkModel{X},
) where {
    T <: SystemBalanceExpressions,
    U <: VariableType,
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), X)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        bus_number = PSY.get_number(PSY.get_bus(d))
        _add_to_jump_expression!(
            expression[bus_number, t],
            variable[name, t],
            get_variable_multiplier(U(), V, W()),
        )
    end
    return
end

"""
Default implementation to add branch variables to SystemBalanceExpressions
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    network_model::NetworkModel{StandardPTDFModel},
) where {T <: ActivePowerBalance, U <: HVDCLosses, V <: PSY.HVDCLine, W <: HVDCP2PDispatch}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), PSY.System)
    for d in devices
        name = PSY.get_name(d)
        device_bus_from = PSY.get_arc(d).from
        ref_bus_from = get_reference_bus(network_model, device_bus_from)
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                expression[ref_bus_from, t],
                variable[name, t],
                get_variable_multiplier(U(), d, W()),
            )
        end
    end
    return
end

"""
Default implementation to add branch variables to SystemBalanceExpressions
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: ActivePowerBalance,
    U <: FlowActivePowerFromToVariable,
    V <: PSY.Branch,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), X)
    for d in devices
        name = PSY.get_name(d)
        bus_number = PSY.get_number(PSY.get_arc(d).from)
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                expression[bus_number, t],
                variable[name, t],
                get_variable_multiplier(U(), V, W()),
            )
        end
    end
    return
end

"""
Default implementation to add branch variables to SystemBalanceExpressions
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::NetworkModel{X},
) where {
    T <: ActivePowerBalance,
    U <: FlowActivePowerToFromVariable,
    V <: PSY.Branch,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), X)
    for d in devices
        name = PSY.get_name(d)
        bus_number = PSY.get_number(PSY.get_arc(d).to)
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                expression[bus_number, t],
                variable[name, t],
                get_variable_multiplier(U(), V, W()),
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
    ::NetworkModel{X},
) where {
    T <: SystemBalanceExpressions,
    U <: OnVariable,
    V <: PSY.ThermalGen,
    W <: Union{AbstractCompactUnitCommitment, ThermalCompactDispatch},
    X <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), X)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        bus_number = PSY.get_number(PSY.get_bus(d))
        _add_to_jump_expression!(
            expression[bus_number, t],
            variable[name, t],
            get_variable_multiplier(U(), d, W()),
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
    device_model::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: SystemBalanceExpressions,
    U <: TimeSeriesParameter,
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
    X <: CopperPlatePowerModel,
}
    param_container = get_parameter(container, U(), V)
    multiplier = get_multiplier_array(param_container)
    expression = get_expression(container, T(), X)
    for d in devices
        device_bus = PSY.get_bus(d)
        ref_bus = get_reference_bus(network_model, device_bus)
        name = PSY.get_name(d)
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                expression[ref_bus, t],
                get_parameter_column_refs(param_container, name)[t],
                multiplier[name, t],
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
    U <: OnStatusParameter,
    V <: PSY.ThermalGen,
    W <: AbstractDeviceFormulation,
    X <: CopperPlatePowerModel,
}
    parameter = get_parameter_array(container, U(), V)
    expression = get_expression(container, T(), X)
    for d in devices
        name = PSY.get_name(d)
        device_bus = PSY.get_bus(d)
        ref_bus = get_reference_bus(network_model, device_bus)
        for t in get_time_steps(container)
            mult = get_expression_multiplier(U(), T(), d, W())
            _add_to_jump_expression!(expression[ref_bus, t], parameter[name, t], mult)
        end
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
    device_model::DeviceModel{V, W},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {
    T <: ActivePowerBalance,
    U <: VariableType,
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), CopperPlatePowerModel)
    for d in devices
        device_bus = PSY.get_bus(d)
        ref_bus = get_reference_bus(network_model, device_bus)
        name = PSY.get_name(d)
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                expression[ref_bus, t],
                variable[name, t],
                get_variable_multiplier(U(), V, W()),
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
    network_model::NetworkModel{CopperPlatePowerModel},
) where {
    T <: ActivePowerBalance,
    U <: OnVariable,
    V <: PSY.ThermalGen,
    W <: Union{AbstractCompactUnitCommitment, ThermalCompactDispatch},
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), CopperPlatePowerModel)
    for d in devices
        name = PSY.get_name(d)
        device_bus = PSY.get_bus(d)
        ref_bus = get_reference_bus(network_model, device_bus)
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                expression[ref_bus, t],
                variable[name, t],
                get_variable_multiplier(U(), d, W()),
            )
        end
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
    device_model::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: SystemBalanceExpressions,
    U <: TimeSeriesParameter,
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
    X <: Union{PTDFPowerModel, StandardPTDFModel},
}
    param_container = get_parameter(container, U(), V)
    multiplier = get_multiplier_array(param_container)
    sys_expr = get_expression(container, T(), PSY.System)
    nodal_expr = get_expression(container, T(), PSY.Bus)
    for d in devices
        name = PSY.get_name(d)
        device_bus = PSY.get_bus(d)
        bus_no = PSY.get_number(device_bus)
        ref_bus = get_reference_bus(network_model, device_bus)
        param = get_parameter_column_refs(param_container, name)
        for t in get_time_steps(container)
            _add_to_jump_expression!(sys_expr[ref_bus, t], param[t], multiplier[name, t])
            _add_to_jump_expression!(nodal_expr[bus_no, t], param[t], multiplier[name, t])
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
    U <: OnStatusParameter,
    V <: PSY.ThermalGen,
    W <: AbstractDeviceFormulation,
    X <: Union{PTDFPowerModel, StandardPTDFModel},
}
    parameter = get_parameter_array(container, U(), V)
    sys_expr = get_expression(container, T(), PSY.System)
    nodal_expr = get_expression(container, T(), PSY.Bus)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        bus_no = PSY.get_number(PSY.get_bus(d))
        mult = get_expression_multiplier(U(), T(), d, W())
        device_bus = PSY.get_bus(d)
        ref_bus = get_reference_bus(network_model, device_bus)
        _add_to_jump_expression!(sys_expr[ref_bus, t], parameter[name, t], mult)
        _add_to_jump_expression!(nodal_expr[bus_no, t], parameter[name, t], mult)
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
    device_model::DeviceModel{V, W},
    network_model::NetworkModel{X},
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
    for d in devices
        name = PSY.get_name(d)
        device_bus = PSY.get_bus(d)
        bus_no = PSY.get_number(device_bus)
        ref_bus = get_reference_bus(network_model, device_bus)
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                sys_expr[ref_bus, t],
                variable[name, t],
                get_variable_multiplier(U(), V, W()),
            )
            _add_to_jump_expression!(
                nodal_expr[bus_no, t],
                variable[name, t],
                get_variable_multiplier(U(), V, W()),
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
    U <: OnVariable,
    V <: PSY.ThermalGen,
    W <: Union{AbstractCompactUnitCommitment, ThermalCompactDispatch},
    X <: Union{PTDFPowerModel, StandardPTDFModel},
}
    variable = get_variable(container, U(), V)
    sys_expr = get_expression(container, T(), PSY.System)
    nodal_expr = get_expression(container, T(), PSY.Bus)
    for d in devices
        name = PSY.get_name(d)
        device_bus = PSY.get_bus(d)
        bus_no = PSY.get_number(device_bus)
        ref_bus = get_reference_bus(network_model, device_bus)
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                sys_expr[ref_bus, t],
                variable[name, t],
                get_variable_multiplier(U(), d, W()),
            )
            _add_to_jump_expression!(
                nodal_expr[bus_no, t],
                variable[name, t],
                get_variable_multiplier(U(), d, W()),
            )
        end
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
    network_model::NetworkModel{X},
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
            _add_to_jump_expression!(
                expression[PSY.get_number(PSY.get_arc(d).from), t],
                flow_variable,
                -1.0,
            )
            _add_to_jump_expression!(
                expression[PSY.get_number(PSY.get_arc(d).to), t],
                flow_variable,
                1.0,
            )
        end
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
    network_model::NetworkModel{StandardPTDFModel},
) where {
    T <: ActivePowerBalance,
    U <: FlowActivePowerVariable,
    V <: PSY.Branch,
    W <: AbstractBranchFormulation,
}
    var = get_variable(container, U(), V)
    nodal_expr = get_expression(container, T(), StandardPTDFModel)
    var = get_variable(container, U(), V)
    sys_expr = get_expression(container, T(), PSY.System)
    for d in devices
        bus_no_from = PSY.get_number(PSY.get_arc(d).from)
        bus_no_to = PSY.get_number(PSY.get_arc(d).to)
        ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
        ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
        for t in get_time_steps(container)
            flow_variable = var[PSY.get_name(d), t]
            _add_to_jump_expression!(nodal_expr[bus_no_from, t], flow_variable, -1.0)
            _add_to_jump_expression!(nodal_expr[bus_no_to, t], flow_variable, 1.0)
            if ref_bus_from != ref_bus_to
                _add_to_jump_expression!(sys_expr[ref_bus_from, t], flow_variable, -1.0)
                _add_to_jump_expression!(sys_expr[ref_bus_to, t], flow_variable, 1.0)
            end
        end
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
    network_model::NetworkModel{CopperPlatePowerModel},
) where {
    T <: ActivePowerBalance,
    U <: FlowActivePowerVariable,
    V <: PSY.Branch,
    W <: AbstractBranchFormulation,
}
    inter_network_branches = V[]
    for d in devices
        ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
        ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
        if ref_bus_from != ref_bus_to
            push!(inter_network_branches, d)
        end
    end
    if !isempty(inter_network_branches)
        var = get_variable(container, U(), V)
        sys_expr = get_expression(container, T(), PSY.System)
        for d in devices
            ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
            ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
            if ref_bus_from == ref_bus_to
                continue
            end
            for t in get_time_steps(container)
                flow_variable = var[PSY.get_name(d), t]
                _add_to_jump_expression!(sys_expr[ref_bus_from, t], flow_variable, -1.0)
                _add_to_jump_expression!(sys_expr[ref_bus_to, t], flow_variable, 1.0)
            end
        end
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
    devices::IS.FlattenIteratorWrapper{PSY.PhaseShiftingTransformer},
    ::DeviceModel{PSY.PhaseShiftingTransformer, V},
    network_model::NetworkModel{StandardPTDFModel},
) where {T <: ActivePowerBalance, U <: PhaseShifterAngle, V <: PhaseAngleControl}
    var = get_variable(container, U(), PSY.PhaseShiftingTransformer)
    expression = get_expression(container, T(), PSY.Bus)
    for d in devices
        for t in get_time_steps(container)
            flow_variable = var[PSY.get_name(d), t]
            _add_to_jump_expression!(
                expression[PSY.get_number(PSY.get_arc(d).from), t],
                flow_variable,
                -get_variable_multiplier(U(), d, V()),
            )
            _add_to_jump_expression!(
                expression[PSY.get_number(PSY.get_arc(d).to), t],
                flow_variable,
                get_variable_multiplier(U(), d, V()),
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
    model::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: Union{ActivePowerRangeExpressionUB, ActivePowerRangeExpressionLB},
    U <: VariableType,
    V <: PSY.Device,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), V)
    if !has_container_key(container, T, V)
        add_expressions!(container, T, devices, model)
    end
    expression = get_expression(container, T(), V)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        _add_to_jump_expression!(expression[name, t], variable[name, t], 1.0)
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
    T <: Union{ActivePowerRangeExpressionUB, ReserveRangeExpressionUB},
    U <: VariableType,
    V <: PSY.Component,
    X <: PSY.Reserve{PSY.ReserveUp},
    W <: AbstractReservesFormulation,
}
    service_name = get_service_name(model)
    variable = get_variable(container, U(), X, service_name)
    if !has_container_key(container, T, V)
        add_expressions!(container, T, devices, model)
    end
    expression = get_expression(container, T(), V)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        _add_to_jump_expression!(expression[name, t], variable[name, t], 1.0)
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
    T <: Union{ActivePowerRangeExpressionLB, ReserveRangeExpressionLB},
    U <: VariableType,
    V <: PSY.Component,
    X <: PSY.Reserve{PSY.ReserveDown},
    W <: AbstractReservesFormulation,
}
    service_name = get_service_name(model)
    variable = get_variable(container, U(), X, service_name)
    if !has_container_key(container, T, V)
        add_expressions!(container, T, devices, model)
    end
    expression = get_expression(container, T(), V)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        _add_to_jump_expression!(expression[name, t], variable[name, t], -1.0)
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
    if !has_container_key(container, T, V)
        add_expressions!(container, T, devices, model)
    end
    expression = get_expression(container, T(), V)
    for d in devices, mult in get_expression_multiplier(U(), T(), d, W())
        for t in get_time_steps(container)
            name = PSY.get_name(d)
            _add_to_jump_expression!(
                expression[name, t],
                parameter_array[name, t],
                -mult,
                mult,
            )
        end
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
    V <: PSY.ThermalGen,
    W <: AbstractThermalDispatchFormulation,
}
    parameter_array = get_parameter_array(container, U(), V)
    if !has_container_key(container, T, V)
        add_expressions!(container, T, devices, model)
    end
    expression = get_expression(container, T(), V)
    for d in devices, mult in get_expression_multiplier(U(), T(), d, W())
        for t in get_time_steps(container)
            name = PSY.get_name(d)
            _add_to_jump_expression!(expression[name, t], parameter_array[name, t], -mult)
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
    contributing_devices_map = get_contributing_devices_map(model)
    for (device_type, devices) in contributing_devices_map
        device_model = get(devices_template, Symbol(device_type), nothing)
        device_model === nothing && continue
        expression_type = get_expression_type_for_reserve(U(), device_type, V)
        add_to_expression!(container, expression_type, U, devices, model)
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    ::PSY.System,
    network_model::NetworkModel{W},
) where {
    T <: ActivePowerBalance,
    U <: Union{SystemBalanceSlackUp, SystemBalanceSlackDown},
    W <: Union{CopperPlatePowerModel, StandardPTDFModel},
}
    variable = get_variable(container, U(), PSY.System)
    expression = get_expression(container, T(), PSY.System)
    reference_buses = get_reference_buses(network_model)
    for t in get_time_steps(container), n in reference_buses
        _add_to_jump_expression!(
            expression[n, t],
            variable[n, t],
            get_variable_multiplier(U(), PSY.System, W()),
        )
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    sys::PSY.System,
    ::NetworkModel{W},
) where {
    T <: ActivePowerBalance,
    U <: Union{SystemBalanceSlackUp, SystemBalanceSlackDown},
    W <: PM.AbstractActivePowerModel,
}
    variable = get_variable(container, U(), PSY.Bus)
    expression = get_expression(container, T(), PSY.Bus)
    @assert_op length(axes(variable, 1)) == length(axes(expression, 1))
    for t in get_time_steps(container), n in axes(variable, 1)
        _add_to_jump_expression!(
            expression[n, t],
            variable[n, t],
            get_variable_multiplier(U(), PSY.Bus, W),
        )
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    sys::PSY.System,
    ::NetworkModel{W},
) where {
    T <: ActivePowerBalance,
    U <: Union{SystemBalanceSlackUp, SystemBalanceSlackDown},
    W <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), PSY.Bus, "P")
    expression = get_expression(container, T(), PSY.Bus)
    bus_numbers = PSY.get_number.(PSY.get_components(PSY.Bus, sys))
    for t in get_time_steps(container), n in bus_numbers
        _add_to_jump_expression!(
            expression[n, t],
            variable[n, t],
            get_variable_multiplier(U(), PSY.Bus, W),
        )
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    sys::PSY.System,
    ::NetworkModel{W},
) where {
    T <: ReactivePowerBalance,
    U <: Union{SystemBalanceSlackUp, SystemBalanceSlackDown},
    W <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), PSY.Bus, "Q")
    expression = get_expression(container, T(), PSY.Bus)
    bus_numbers = PSY.get_number.(PSY.get_components(PSY.Bus, sys))
    for t in get_time_steps(container), n in bus_numbers
        _add_to_jump_expression!(
            expression[n, t],
            variable[n, t],
            get_variable_multiplier(U(), PSY.Bus, W),
        )
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{S},
    cost_expression::JuMP.AbstractJuMPScalar,
    component::T,
    time_period::Int,
) where {S <: CostExpressions, T <: PSY.Component}
    if has_container_key(container, S, T)
        device_cost_expression = get_expression(container, S(), T)
        component_name = PSY.get_name(component)
        JuMP.add_to_expression!(
            device_cost_expression[component_name, time_period],
            cost_expression,
        )
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    areas::IS.FlattenIteratorWrapper{V},
    model::ServiceModel{PSY.AGC, W},
) where {
    T <: Union{EmergencyUp, EmergencyDown},
    U <:
    Union{AdditionalDeltaActivePowerUpVariable, AdditionalDeltaActivePowerDownVariable},
    V <: PSY.Area,
    W <: AbstractServiceFormulation,
}
    names = PSY.get_name.(areas)
    time_steps = get_time_steps(container)
    if !has_container_key(container, T, V)
        expression = add_expression_container!(container, T(), V, names, time_steps)
    end
    expression = get_expression(container, T(), V)
    variable = get_variable(container, U(), V)
    for n in names, t in time_steps
        _add_to_jump_expression!(expression[n, t], variable[n, t], 1.0)
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    services::IS.FlattenIteratorWrapper{V},
    model::ServiceModel{V, W},
) where {
    T <: RawACE,
    U <: SteadyStateFrequencyDeviation,
    V <: PSY.AGC,
    W <: AbstractServiceFormulation,
}
    names = [PSY.get_name(PSY.get_area(s)) for s in services]
    time_steps = get_time_steps(container)
    if !has_container_key(container, T, V)
        expression = add_expression_container!(container, T(), PSY.Area, names, time_steps)
    end
    expression = get_expression(container, T(), PSY.Area)
    variable = get_variable(container, U(), PSY.Area)
    for s in services, t in time_steps
        name = PSY.get_name(PSY.get_area(s))
        _add_to_jump_expression!(
            expression[name, t],
            variable[t],
            get_variable_multiplier(U(), s, W()),
        )
    end
    return
end
