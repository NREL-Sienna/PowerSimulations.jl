_system_expression_type(::Type{PTDFPowerModel}) = PSY.System
_system_expression_type(::Type{CopperPlatePowerModel}) = PSY.System
_system_expression_type(::Type{SecurityConstrainedPTDFPowerModel}) = PSY.System

_system_expression_type(::Type{AreaPTDFPowerModel}) = PSY.Area
_system_expression_type(::Type{SecurityConstrainedAreaPTDFPowerModel}) = PSY.Area

function _ref_index(network_model::NetworkModel{<:PM.AbstractPowerModel}, bus::PSY.ACBus)
    return get_reference_bus(network_model, bus)
end

function _ref_index(::NetworkModel{AreaPTDFPowerModel}, device_bus::PSY.ACBus)
    return PSY.get_name(PSY.get_area(device_bus))
end

_get_variable_if_exists(::PSY.MarketBidCost) = nothing
_get_variable_if_exists(cost::PSY.OperationalCost) = PSY.get_variable(cost)

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
    model::DeviceModel{D, W},
) where {
    T <: FuelConsumptionExpression,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    time_steps = get_time_steps(container)
    names = String[]
    found_quad_fuel_functions = false
    for d in devices
        op_cost = PSY.get_operation_cost(d)
        fuel_curve = _get_variable_if_exists(op_cost)
        if fuel_curve isa PSY.FuelCurve
            push!(names, PSY.get_name(d))
            if !found_quad_fuel_functions
                found_quad_fuel_functions =
                    PSY.get_value_curve(fuel_curve) isa PSY.QuadraticCurve
            end
        end
    end

    if !isempty(names)
        expr_type = found_quad_fuel_functions ? JuMP.QuadExpr : GAE
        add_expression_container!(
            container,
            T(),
            D,
            names,
            time_steps;
            expr_type = expr_type,
        )
    end
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
    @assert length(devices) == 1
    add_expression_container!(
        container,
        T(),
        D,
        PSY.get_name.(devices),
        time_steps;
        meta = get_service_name(model),
    )
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
    var1::JuMP.VariableRef,
    multiplier1::Float64,
    var2::JuMP.VariableRef,
    multiplier2::Float64,
) where {T <: JuMP.AbstractJuMPScalar}
    _add_to_jump_expression!(expression, var1, multiplier1)
    _add_to_jump_expression!(expression, var2, multiplier2)
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
    network_model::NetworkModel{X},
) where {
    T <: SystemBalanceExpressions,
    U <: TimeSeriesParameter,
    V <: PSY.Device,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    param_container = get_parameter(container, U(), V)
    multiplier = get_multiplier_array(param_container)
    network_reduction = get_network_reduction(network_model)
    for d in devices, t in get_time_steps(container)
        bus_no = PNM.get_mapped_bus_number(network_reduction, PSY.get_bus(d))
        name = PSY.get_name(d)
        _add_to_jump_expression!(
            get_expression(container, T(), PSY.ACBus)[bus_no, t],
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
    model::DeviceModel{V, W},
    network_model::NetworkModel{AreaBalancePowerModel},
) where {
    T <: SystemBalanceExpressions,
    U <: TimeSeriesParameter,
    V <: PSY.Device,
    W <: AbstractDeviceFormulation,
}
    param_container = get_parameter(container, U(), V)
    multiplier = get_multiplier_array(param_container)
    for d in devices, t in get_time_steps(container)
        bus = PSY.get_bus(d)
        area_name = PSY.get_name(PSY.get_area(bus))
        name = PSY.get_name(d)
        _add_to_jump_expression!(
            get_expression(container, T(), PSY.Area)[area_name, t],
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
    network_model::NetworkModel{X},
) where {
    T <: ActivePowerBalance,
    U <: OnStatusParameter,
    V <: PSY.ThermalGen,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    parameter = get_parameter_array(container, U(), V)
    network_reduction = get_network_reduction(network_model)
    for d in devices, t in get_time_steps(container)
        bus_no = PNM.get_mapped_bus_number(network_reduction, PSY.get_bus(d))
        name = PSY.get_name(d)
        mult = get_expression_multiplier(U(), T(), d, W())
        _add_to_jump_expression!(
            get_expression(container, T(), PSY.ACBus)[bus_no, t],
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
    network_model::NetworkModel{X},
) where {
    T <: SystemBalanceExpressions,
    U <: VariableType,
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), PSY.ACBus)
    network_reduction = get_network_reduction(network_model)
    for d in devices
        name = PSY.get_name(d)
        bus_no = PNM.get_mapped_bus_number(network_reduction, PSY.get_bus(d))
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                expression[bus_no, t],
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
    network_model::NetworkModel{AreaBalancePowerModel},
) where {
    T <: SystemBalanceExpressions,
    U <: VariableType,
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), PSY.Area)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        bus = PSY.get_bus(d)
        area_name = PSY.get_name(PSY.get_area(bus))
        _add_to_jump_expression!(
            expression[area_name, t],
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
    network_model::NetworkModel{X},
) where {
    T <: ActivePowerBalance,
    U <: HVDCLosses,
    V <: TwoTerminalHVDCTypes,
    W <: HVDCTwoTerminalDispatch,
    X <: Union{PTDFPowerModel, CopperPlatePowerModel, SecurityConstrainedPTDFPowerModel},
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), PSY.System)
    for d in devices
        name = PSY.get_name(d)
        device_bus_from = PSY.get_arc(d).from
        device_bus_to = PSY.get_arc(d).to
        ref_bus_from = get_reference_bus(network_model, device_bus_from)
        ref_bus_to = get_reference_bus(network_model, device_bus_to)
        if ref_bus_from == ref_bus_to
            for t in get_time_steps(container)
                _add_to_jump_expression!(
                    expression[ref_bus_from, t],
                    variable[name, t],
                    get_variable_multiplier(U(), d, W()),
                )
            end
        end
    end
    return
end

#TODO Check if for SecurityConstrainedAreaPTDFPowerModel need something else
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: ActivePowerBalance,
    U <: HVDCLosses,
    V <: TwoTerminalHVDCTypes,
    W <: HVDCTwoTerminalDispatch,
    X <:
    Union{AreaPTDFPowerModel, AreaBalancePowerModel, SecurityConstrainedAreaPTDFPowerModel},
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), PSY.Area)
    for d in devices
        name = PSY.get_name(d)
        device_bus_from = PSY.get_arc(d).from
        area_name = PSY.get_name(PSY.get_area(device_bus_from))
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                expression[area_name, t],
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
    network_model::NetworkModel{Union{PTDFPowerModel, SecurityConstrainedPTDFPowerModel}},
) where {
    T <: ActivePowerBalance,
    U <: FlowActivePowerToFromVariable,
    V <: TwoTerminalHVDCTypes,
    W <: AbstractTwoTerminalDCLineFormulation,
}
    var = get_variable(container, U(), V)
    nodal_expr = get_expression(container, T(), PSY.ACBus)
    sys_expr = get_expression(container, T(), PSY.System)
    network_reduction = get_network_reduction(network_model)
    for d in devices
        bus_no_to = PNM.get_mapped_bus_number(network_reduction, PSY.get_arc(d).to)
        ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
        ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
        for t in get_time_steps(container)
            flow_variable = var[PSY.get_name(d), t]
            _add_to_jump_expression!(nodal_expr[bus_no_to, t], flow_variable, -1.0)
            if ref_bus_from != ref_bus_to
                _add_to_jump_expression!(sys_expr[ref_bus_to, t], flow_variable, -1.0)
            end
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
    V <: TwoTerminalHVDCTypes,
    W <: AbstractTwoTerminalDCLineFormulation,
    X <: AbstractPTDFModel,
}
    var = get_variable(container, U(), V)
    nodal_expr = get_expression(container, T(), PSY.ACBus)
    sys_expr = get_expression(container, T(), _system_expression_type(X))
    network_reduction = get_network_reduction(network_model)
    for d in devices
        bus_no_from =
            PNM.get_mapped_bus_number(network_reduction, PSY.get_arc(d).from)
        ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
        ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
        for t in get_time_steps(container)
            flow_variable = var[PSY.get_name(d), t]
            _add_to_jump_expression!(nodal_expr[bus_no_from, t], flow_variable, -1.0)
            if ref_bus_from != ref_bus_to
                _add_to_jump_expression!(sys_expr[ref_bus_from, t], flow_variable, -1.0)
            end
        end
    end
    return
end

"""
PWL implementation to add FromTo branch variables to SystemBalanceExpressions
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
    U <: HVDCActivePowerReceivedFromVariable,
    V <: TwoTerminalHVDCTypes,
    W <: HVDCTwoTerminalPiecewiseLoss,
    X <: AbstractPTDFModel,
}
    var = get_variable(container, U(), V)
    nodal_expr = get_expression(container, T(), PSY.ACBus)
    sys_expr = get_expression(container, T(), _system_expression_type(X))
    network_reduction = get_network_reduction(network_model)
    for d in devices
        bus_no_from =
            PNM.get_mapped_bus_number(network_reduction, PSY.get_arc(d).from)
        ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
        ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
        for t in get_time_steps(container)
            flow_variable = var[PSY.get_name(d), t]
            _add_to_jump_expression!(nodal_expr[bus_no_from, t], flow_variable, 1.0)
            if ref_bus_from != ref_bus_to
                _add_to_jump_expression!(sys_expr[ref_bus_from, t], flow_variable, 1.0)
            end
        end
    end
    return
end

"""
PWL implementation to add FromTo branch variables to SystemBalanceExpressions
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
    U <: HVDCActivePowerReceivedToVariable,
    V <: TwoTerminalHVDCTypes,
    W <: HVDCTwoTerminalPiecewiseLoss,
    X <: AbstractPTDFModel,
}
    var = get_variable(container, U(), V)
    nodal_expr = get_expression(container, T(), PSY.ACBus)
    sys_expr = get_expression(container, T(), _system_expression_type(X))
    network_reduction = get_network_reduction(network_model)
    for d in devices
        bus_no_to =
            PNM.get_mapped_bus_number(network_reduction, PSY.get_arc(d).to)
        ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
        ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
        for t in get_time_steps(container)
            flow_variable = var[PSY.get_name(d), t]
            _add_to_jump_expression!(nodal_expr[bus_no_to, t], flow_variable, 1.0)
            if ref_bus_from != ref_bus_to
                _add_to_jump_expression!(sys_expr[ref_bus_to, t], flow_variable, 1.0)
            end
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
    U <: FlowActivePowerToFromVariable,
    V <: TwoTerminalHVDCTypes,
    W <: AbstractTwoTerminalDCLineFormulation,
    X <: CopperPlatePowerModel,
}
    if has_subnetworks(network_model)
        var = get_variable(container, U(), V)
        sys_expr = get_expression(container, T(), PSY.System)
        for d in devices
            ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
            ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
            for t in get_time_steps(container)
                flow_variable = var[PSY.get_name(d), t]
                if ref_bus_from != ref_bus_to
                    _add_to_jump_expression!(sys_expr[ref_bus_to, t], flow_variable, 1.0)
                end
            end
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
    V <: TwoTerminalHVDCTypes,
    W <: AbstractTwoTerminalDCLineFormulation,
    X <: CopperPlatePowerModel,
}
    if has_subnetworks(network_model)
        var = get_variable(container, U(), V)
        sys_expr = get_expression(container, T(), PSY.System)
        for d in devices
            ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
            ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
            for t in get_time_steps(container)
                flow_variable = var[PSY.get_name(d), t]
                if ref_bus_from != ref_bus_to
                    _add_to_jump_expression!(sys_expr[ref_bus_to, t], flow_variable, -1.0)
                end
            end
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
    expression = get_expression(container, T(), PSY.ACBus)
    network_reduction = get_network_reduction(network_model)
    for d in devices
        name = PSY.get_name(d)
        bus_no_ = PSY.get_number(PSY.get_arc(d).from)
        bus_no = PNM.get_mapped_bus_number(network_reduction, bus_no_)
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                expression[bus_no, t],
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
    network_model::NetworkModel{X},
) where {
    T <: ActivePowerBalance,
    U <: FlowActivePowerToFromVariable,
    V <: PSY.ACBranch,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), PSY.ACBus)
    network_reduction = get_network_reduction(network_model)
    for d in devices
        name = PSY.get_name(d)
        bus_no_ = PSY.get_number(PSY.get_arc(d).to)
        bus_no = PNM.get_mapped_bus_number(network_reduction, bus_no_)
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                expression[bus_no, t],
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
    branches::IS.FlattenIteratorWrapper{PSY.ACBranch},
    branches_outages::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {
    T <: PTDFOutagesBranchFlow,
    U <: FlowActivePowerVariable,
    V <: PSY.ACBranch,
    W <: AbstractDeviceFormulation,
    X <: SecurityConstrainedPTDFPowerModel,
}
    time_steps = get_time_steps(container)

    if !isempty(branches_outages)
        container.expressions[ExpressionKey(PTDFOutagesBranchFlow, V)] =
            _make_container_array(
                get_name.(branches_outages),
                get_name.(branches),
                time_steps,
            )
    end

    expressions = get_expression(
        container,
        ExpressionKey(PTDFOutagesBranchFlow, V, IS.Optimization.CONTAINER_KEY_EMPTY_META),
    )
    lodf = get_LODF_matrix(network_model)

    variable_branches_outages = get_variable(container, U(), V)

    for branch in branches
        variable_branches = get_variable(container, U(), typeof(branch))
        branch_name = get_name(branch)

        for branch_outage in branches_outages
            #TODO HOW WE SHOULD HANDLE THE EXPRESSIONS AND CONSTRAINTS RELATED TO THE OUTAGE OF THE LINE RESPECT TO ITSELF?
            if branch_outage == branch
                continue
            end

            branch_outage_name = get_name(branch_outage)

            for t in time_steps
                _add_to_jump_expression!(
                    expressions[branch_outage_name, branch_name, t],
                    variable_branches[branch_name, t],
                    1.0,
                    variable_branches_outages[branch_outage_name, t],
                    lodf[branch_name, branch_outage_name],
                )
            end
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
    T <: SystemBalanceExpressions,
    U <: OnVariable,
    V <: PSY.ThermalGen,
    W <: Union{AbstractCompactUnitCommitment, ThermalCompactDispatch},
    X <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), PSY.ACBus)
    network_reduction = get_network_reduction(network_model)
    for d in devices
        name = PSY.get_name(d)
        bus_no_ = PSY.get_number(PSY.get_bus(d))
        bus_no = PNM.get_mapped_bus_number(network_reduction, bus_no_)
        for t in get_time_steps(container)
            if PSY.get_must_run(d)
                _add_to_jump_expression!(
                    expression[bus_no, t],
                    get_variable_multiplier(U(), d, W()),
                )
            else
                _add_to_jump_expression!(
                    expression[bus_no, t],
                    variable[name, t],
                    get_variable_multiplier(U(), d, W()),
                )
            end
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
    network_model::NetworkModel{AreaBalancePowerModel},
) where {
    T <: SystemBalanceExpressions,
    U <: OnVariable,
    V <: PSY.ThermalGen,
    W <: Union{AbstractCompactUnitCommitment, ThermalCompactDispatch},
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), PSY.ACBus)
    for d in devices
        name = PSY.get_name(d)
        bus = PSY.get_bus(d)
        area_name = PSY.get_name(PSY.get_area(bus))
        for t in get_time_steps(container)
            if PSY.get_must_run(d)
                _add_to_jump_expression!(
                    expression[area_name, t],
                    get_variable_multiplier(U(), d, W()),
                )
            else
                _add_to_jump_expression!(
                    expression[area_name, t],
                    variable[name, t],
                    get_variable_multiplier(U(), d, W()),
                )
            end
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
    X <: CopperPlatePowerModel,
}
    param_container = get_parameter(container, U(), V)
    multiplier = get_multiplier_array(param_container)
    expression = get_expression(container, T(), PSY.System)
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
    expression = get_expression(container, T(), PSY.System)
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
    expression = get_expression(container, T(), PSY.System)
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
    expression = get_expression(container, T(), PSY.System)
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
    X <: AbstractPTDFModel,
}
    param_container = get_parameter(container, U(), V)
    multiplier = get_multiplier_array(param_container)
    sys_expr = get_expression(container, T(), _system_expression_type(X))
    nodal_expr = get_expression(container, T(), PSY.ACBus)
    network_reduction = get_network_reduction(network_model)
    for d in devices
        name = PSY.get_name(d)
        device_bus = PSY.get_bus(d)
        bus_no_ = PSY.get_number(device_bus)
        bus_no = PNM.get_mapped_bus_number(network_reduction, bus_no_)
        ref_index = _ref_index(network_model, device_bus)
        param = get_parameter_column_refs(param_container, name)
        for t in get_time_steps(container)
            _add_to_jump_expression!(sys_expr[ref_index, t], param[t], multiplier[name, t])
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
    X <: AbstractPTDFModel,
}
    parameter = get_parameter_array(container, U(), V)
    sys_expr = get_expression(container, T(), PSY.System)
    nodal_expr = get_expression(container, T(), PSY.ACBus)
    network_reduction = get_network_reduction(network_model)
    for d in devices
        name = PSY.get_name(d)
        bus_no_ = PSY.get_number(PSY.get_bus(d))
        bus_no = PNM.get_mapped_bus_number(network_reduction, bus_no_)
        mult = get_expression_multiplier(U(), T(), d, W())
        device_bus = PSY.get_bus(d)
        ref_index = _ref_index(network_model, device_bus)
        for t in get_time_steps(container)
            _add_to_jump_expression!(sys_expr[ref_index, t], parameter[name, t], mult)
            _add_to_jump_expression!(nodal_expr[bus_no, t], parameter[name, t], mult)
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
    network_model::NetworkModel{X},
) where {
    T <: ActivePowerBalance,
    U <: VariableType,
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
    X <: Union{PTDFPowerModel, SecurityConstrainedPTDFPowerModel},
}
    variable = get_variable(container, U(), V)
    sys_expr = get_expression(container, T(), PSY.System)
    nodal_expr = get_expression(container, T(), PSY.ACBus)
    network_reduction = get_network_reduction(network_model)
    for d in devices
        name = PSY.get_name(d)
        device_bus = PSY.get_bus(d)
        bus_no = PNM.get_mapped_bus_number(network_reduction, device_bus)
        ref_index = _ref_index(network_model, device_bus)
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                sys_expr[ref_index, t],
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

#TODO Check if for SecurityConstrainedAreaPTDFPowerModel need something else
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
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
    X <: Union{AreaPTDFPowerModel, SecurityConstrainedAreaPTDFPowerModel},
}
    variable = get_variable(container, U(), V)
    area_expr = get_expression(container, T(), PSY.Area)
    nodal_expr = get_expression(container, T(), PSY.ACBus)
    network_reduction = get_network_reduction(network_model)
    for d in devices
        name = PSY.get_name(d)
        device_bus = PSY.get_bus(d)
        area_name = PSY.get_name(PSY.get_area(device_bus))
        bus_no = PNM.get_mapped_bus_number(network_reduction, device_bus)
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                area_expr[area_name, t],
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

#TODO Check if for SecurityConstrainedAreaPTDFPowerModel need something else
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
    X <: Union{PTDFPowerModel, SecurityConstrainedAreaPTDFPowerModel},
}
    variable = get_variable(container, U(), V)
    sys_expr = get_expression(container, T(), _system_expression_type(PTDFPowerModel))
    nodal_expr = get_expression(container, T(), PSY.ACBus)
    network_reduction = get_network_reduction(network_model)
    for d in devices
        name = PSY.get_name(d)
        bus_no = PNM.get_mapped_bus_number(network_reduction, PSY.get_bus(d))
        ref_index = _ref_index(network_model, PSY.get_bus(d))
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                sys_expr[ref_index, t],
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
    V <: PSY.ACBranch,
    W <: AbstractBranchFormulation,
    X <: PM.AbstractActivePowerModel,
}
    var = get_variable(container, U(), V)
    expression = get_expression(container, T(), PSY.ACBus)
    network_reduction = get_network_reduction(network_model)
    for d in devices
        bus_no_from =
            PNM.get_mapped_bus_number(network_reduction, PSY.get_arc(d).from)
        bus_no_to = PNM.get_mapped_bus_number(network_reduction, PSY.get_arc(d).to)
        for t in get_time_steps(container)
            flow_variable = var[PSY.get_name(d), t]
            _add_to_jump_expression!(
                expression[bus_no_from, t],
                flow_variable,
                -1.0,
            )
            _add_to_jump_expression!(
                expression[bus_no_to, t],
                flow_variable,
                1.0,
            )
        end
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{FlowActivePowerVariable},
    devices::IS.FlattenIteratorWrapper{PSY.AreaInterchange},
    ::DeviceModel{PSY.AreaInterchange, W},
    network_model::NetworkModel{U},
) where {
    T <: ActivePowerBalance,
    U <: PM.AbstractActivePowerModel,
    W <: AbstractBranchFormulation,
}
    flow_variable = get_variable(container, FlowActivePowerVariable(), PSY.AreaInterchange)
    expression = get_expression(container, T(), PSY.Area)
    for d in devices
        area_from_name = PSY.get_name(PSY.get_from_area(d))
        area_to_name = PSY.get_name(PSY.get_to_area(d))
        for t in get_time_steps(container)
            _add_to_jump_expression!(
                expression[area_from_name, t],
                flow_variable[PSY.get_name(d), t],
                -1.0,
            )
            _add_to_jump_expression!(
                expression[area_to_name, t],
                flow_variable[PSY.get_name(d), t],
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
    network_model::NetworkModel{X},
) where {
    T <: ActivePowerBalance,
    U <: FlowActivePowerVariable,
    V <: PSY.ACBranch,
    W <: AbstractBranchFormulation,
    X <: Union{PTDFPowerModel, SecurityConstrainedPTDFPowerModel},
}
    var = get_variable(container, U(), V)
    nodal_expr = get_expression(container, T(), PSY.ACBus)
    sys_expr = get_expression(container, T(), PSY.System)
    network_reduction = get_network_reduction(network_model)
    for d in devices
        bus_no_from =
            PNM.get_mapped_bus_number(network_reduction, PSY.get_arc(d).from)
        bus_no_to = PNM.get_mapped_bus_number(network_reduction, PSY.get_arc(d).to)
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
    V <: PSY.ACBranch,
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
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {T <: ActivePowerBalance, U <: PhaseShifterAngle, V <: PhaseAngleControl}
    var = get_variable(container, U(), PSY.PhaseShiftingTransformer)
    expression = get_expression(container, T(), PSY.ACBus)
    network_reduction = get_network_reduction(network_model)
    for d in devices
        bus_no_from =
            PNM.get_mapped_bus_number(network_reduction, PSY.get_arc(d).from)
        bus_no_to = PNM.get_mapped_bus_number(network_reduction, PSY.get_arc(d).to)
        for t in get_time_steps(container)
            flow_variable = var[PSY.get_name(d), t]
            _add_to_jump_expression!(
                expression[bus_no_from, t],
                flow_variable,
                -get_variable_multiplier(U(), d, V()),
            )
            _add_to_jump_expression!(
                expression[bus_no_to, t],
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
    T <: ActivePowerRangeExpressionUB,
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
    ::Type{InterfaceTotalFlow},
    ::Type{T},
    service::PSY.TransmissionInterface,
    model::ServiceModel{PSY.TransmissionInterface, U},
) where {
    T <: Union{InterfaceFlowSlackUp, InterfaceFlowSlackDown},
    U <: Union{ConstantMaxInterfaceFlow, VariableMaxInterfaceFlow},
}
    expression = get_expression(container, InterfaceTotalFlow(), PSY.TransmissionInterface)
    service_name = PSY.get_name(service)
    variable = get_variable(container, T(), PSY.TransmissionInterface, service_name)
    for t in get_time_steps(container)
        _add_to_jump_expression!(
            expression[service_name, t],
            variable[t],
            get_variable_multiplier(T(), service, U()),
        )
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{InterfaceTotalFlow},
    ::Type{FlowActivePowerVariable},
    service::PSY.TransmissionInterface,
    model::ServiceModel{PSY.TransmissionInterface, V},
) where {V <: Union{ConstantMaxInterfaceFlow, VariableMaxInterfaceFlow}}
    expression = get_expression(container, InterfaceTotalFlow(), PSY.TransmissionInterface)
    service_name = get_service_name(model)
    for (device_type, devices) in get_contributing_devices_map(model)
        variable = get_variable(container, FlowActivePowerVariable(), device_type)
        for d in devices
            name = PSY.get_name(d)
            direction = get(PSY.get_direction_mapping(service), name, 1.0)
            for t in get_time_steps(container)
                _add_to_jump_expression!(
                    expression[service_name, t],
                    variable[name, t],
                    Float64(direction),
                )
            end
        end
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
    for d in devices
        mult = get_expression_multiplier(U(), T(), d, W())
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
    for d in devices
        if PSY.get_must_run(d)
            continue
        end
        mult = get_expression_multiplier(U(), T(), d, W())
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
    W <: Union{CopperPlatePowerModel, PTDFPowerModel, SecurityConstrainedPTDFPowerModel},
}
    variable = get_variable(container, U(), PSY.System)
    expression = get_expression(container, T(), _system_expression_type(W))
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

#TODO Check if for SecurityConstrainedAreaPTDFPowerModel need something else
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    sys::PSY.System,
    network_model::NetworkModel{
        Union{AreaPTDFPowerModel, SecurityConstrainedAreaPTDFPowerModel},
    },
) where {
    T <: ActivePowerBalance,
    U <: Union{SystemBalanceSlackUp, SystemBalanceSlackDown},
}
    variable =
        get_variable(container, U(), _system_expression_type(AreaPTDFPowerModel))
    expression =
        get_expression(container, T(), _system_expression_type(AreaPTDFPowerModel))
    areas = get_available_components(network_model, PSY.Area, sys)
    for t in get_time_steps(container), n in PSY.get_name.(areas)
        _add_to_jump_expression!(
            expression[n, t],
            variable[n, t],
            get_variable_multiplier(U(), PSY.Area, AreaPTDFPowerModel()),
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
    W <: AreaBalancePowerModel,
}
    variable = get_variable(container, U(), PSY.Area)
    expression = get_expression(container, T(), PSY.Area)
    @assert_op length(axes(variable, 1)) == length(axes(expression, 1))
    for t in get_time_steps(container), n in axes(expression, 1)
        _add_to_jump_expression!(
            expression[n, t],
            variable[n, t],
            get_variable_multiplier(U(), PSY.Area, W),
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
    variable = get_variable(container, U(), PSY.ACBus)
    expression = get_expression(container, T(), PSY.ACBus)
    @assert_op length(axes(variable, 1)) == length(axes(expression, 1))
    # We uses axis here to avoid double addition of the slacks to the aggregated buses
    for t in get_time_steps(container), n in axes(expression, 1)
        _add_to_jump_expression!(
            expression[n, t],
            variable[n, t],
            get_variable_multiplier(U(), PSY.ACBus, W),
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
    variable = get_variable(container, U(), PSY.ACBus, "P")
    expression = get_expression(container, T(), PSY.ACBus)
    # We uses axis here to avoid double addition of the slacks to the aggregated buses
    for t in get_time_steps(container), n in axes(expression, 1)
        _add_to_jump_expression!(
            expression[n, t],
            variable[n, t],
            get_variable_multiplier(U(), PSY.ACBus, W),
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
    variable = get_variable(container, U(), PSY.ACBus, "Q")
    expression = get_expression(container, T(), PSY.ACBus)
    # We uses axis here to avoid double addition of the slacks to the aggregated buses
    for t in get_time_steps(container), n in axes(expression, 1)
        _add_to_jump_expression!(
            expression[n, t],
            variable[n, t],
            get_variable_multiplier(U(), PSY.ACBus, W),
        )
    end
    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{S},
    cost_expression::Union{JuMP.AbstractJuMPScalar, Float64},
    component::T,
    time_period::Int,
) where {S <: Union{CostExpressions, FuelConsumptionExpression}, T <: PSY.Component}
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
    ::Type{S},
    cost_expression::JuMP.AbstractJuMPScalar,
    component::T,
    time_period::Int,
) where {S <: CostExpressions, T <: PSY.ReserveDemandCurve}
    if has_container_key(container, S, T, PSY.get_name(component))
        device_cost_expression = get_expression(container, S(), T, PSY.get_name(component))
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
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {
    T <: FuelConsumptionExpression,
    U <: ActivePowerVariable,
    V <: PSY.ThermalGen,
    W <: AbstractDeviceFormulation,
}
    variable = get_variable(container, U(), V)
    time_steps = get_time_steps(container)
    base_power = get_base_power(container)
    resolution = get_resolution(container)
    dt = Dates.value(resolution) / MILLISECONDS_IN_HOUR
    for d in devices
        op_cost = PSY.get_operation_cost(d)
        var_cost = _get_variable_if_exists(op_cost)
        if !(var_cost isa PSY.FuelCurve)
            continue
        end
        expression = get_expression(container, T(), V)
        name = PSY.get_name(d)
        device_base_power = PSY.get_base_power(d)
        value_curve = PSY.get_value_curve(var_cost)
        if value_curve isa PSY.LinearCurve
            power_units = PSY.get_power_units(var_cost)
            proportional_term = PSY.get_proportional_term(value_curve)
            prop_term_per_unit = get_proportional_cost_per_system_unit(
                proportional_term,
                power_units,
                base_power,
                device_base_power,
            )
            for t in time_steps
                JuMP.add_to_expression!(
                    expression[name, t],
                    prop_term_per_unit * dt,
                    variable[name, t],
                )
            end
        elseif value_curve isa PSY.QuadraticCurve
            power_units = PSY.get_power_units(var_cost)
            proportional_term = PSY.get_proportional_term(value_curve)
            quadratic_term = PSY.get_quadratic_term(value_curve)
            prop_term_per_unit = get_proportional_cost_per_system_unit(
                proportional_term,
                power_units,
                base_power,
                device_base_power,
            )
            quad_term_per_unit = get_quadratic_cost_per_system_unit(
                quadratic_term,
                power_units,
                base_power,
                device_base_power,
            )
            for t in time_steps
                fuel_expr =
                    (
                        variable[name, t] .^ 2 * quad_term_per_unit +
                        variable[name, t] * prop_term_per_unit
                    ) * dt
                JuMP.add_to_expression!(
                    expression[name, t],
                    fuel_expr,
                )
            end
        end
    end
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {
    T <: FuelConsumptionExpression,
    U <: PowerAboveMinimumVariable,
    V <: PSY.ThermalGen,
    W <: AbstractDeviceFormulation,
}
    variable = get_variable(container, U(), V)
    time_steps = get_time_steps(container)
    base_power = get_base_power(container)
    resolution = get_resolution(container)
    dt = Dates.value(resolution) / MILLISECONDS_IN_HOUR
    for d in devices
        op_cost = PSY.get_operation_cost(d)
        var_cost = _get_variable_if_exists(op_cost)
        if !(var_cost isa PSY.FuelCurve)
            continue
        end
        expression = get_expression(container, T(), V)
        name = PSY.get_name(d)
        device_base_power = PSY.get_base_power(d)
        value_curve = PSY.get_value_curve(var_cost)
        P_min = PSY.get_active_power_limits(d).min
        if value_curve isa PSY.LinearCurve
            power_units = PSY.get_power_units(var_cost)
            proportional_term = PSY.get_proportional_term(value_curve)
            prop_term_per_unit = get_proportional_cost_per_system_unit(
                proportional_term,
                power_units,
                base_power,
                device_base_power,
            )
            for t in time_steps
                sos_status = _get_sos_value(container, W, d)
                if sos_status == SOSStatusVariable.NO_VARIABLE
                    JuMP.add_to_expression!(
                        expression[name, t],
                        P_min * prop_term_per_unit * dt,
                    )
                elseif sos_status == SOSStatusVariable.PARAMETER
                    param = get_default_on_parameter(d)
                    bin = get_parameter(container, param, V).parameter_array[name, t]
                    JuMP.add_to_expression!(
                        expression[name, t],
                        P_min * prop_term_per_unit * dt,
                        bin,
                    )
                elseif sos_status == SOSStatusVariable.VARIABLE
                    var = get_default_on_variable(d)
                    bin = get_variable(container, var, V)[name, t]
                    JuMP.add_to_expression!(
                        expression[name, t],
                        P_min * prop_term_per_unit * dt,
                        bin,
                    )
                else
                    @assert false
                end
                JuMP.add_to_expression!(
                    expression[name, t],
                    prop_term_per_unit * dt,
                    variable[name, t],
                )
            end
        elseif value_curve isa PSY.QuadraticCurve
            error("Quadratic Curves are not accepted with Compact Formulation: $W")
        end
    end
end
