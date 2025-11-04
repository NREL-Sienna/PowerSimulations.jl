## To add method of upper_bounds and lower_bounds for DCVoltage
get_variable_binary(::DCVoltage, ::Type{PSY.DCBus}, ::AbstractHVDCNetworkModel) = false
get_variable_lower_bound(::DCVoltage, d::PSY.DCBus, ::AbstractHVDCNetworkModel) =
    PSY.get_voltage_limits(d).min
get_variable_upper_bound(::DCVoltage, d::PSY.DCBus, ::AbstractHVDCNetworkModel) =
    PSY.get_voltage_limits(d).max

function add_constraints!(
    container::OptimizationContainer,
    ::Type{NodalBalanceActiveConstraint},
    sys::PSY.System,
    model::NetworkModel{V},
    hvdc_model::W,
) where {V <: PM.AbstractPowerModel, W <: TransportHVDCNetworkModel}
    dc_buses = PSY.get_components(PSY.DCBus, sys)
    if isempty(dc_buses)
        return
    end

    time_steps = get_time_steps(container)
    dc_expr = get_expression(container, ActivePowerBalance(), PSY.DCBus)
    balance_constraint = add_constraints_container!(
        container,
        NodalBalanceActiveConstraint(),
        PSY.DCBus,
        axes(dc_expr)[1],
        time_steps,
    )
    for d in dc_buses
        dc_bus_no = PSY.get_number(d)
        for t in time_steps
            balance_constraint[dc_bus_no, t] =
                JuMP.@constraint(get_jump_model(container), dc_expr[dc_bus_no, t] == 0)
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{NodalBalanceCurrentConstraint},
    sys::PSY.System,
    model::NetworkModel{V},
    hvdc_model::W,
) where {V <: PM.AbstractPowerModel, W <: VoltageDispatchHVDCNetworkModel}
    dc_buses = PSY.get_components(PSY.DCBus, sys)
    if isempty(dc_buses)
        return
    end

    time_steps = get_time_steps(container)
    dc_expr = get_expression(container, DCCurrentBalance(), PSY.DCBus)
    balance_constraint = add_constraints_container!(
        container,
        NodalBalanceCurrentConstraint(),
        PSY.DCBus,
        axes(dc_expr)[1],
        time_steps,
    )
    for d in dc_buses
        dc_bus_no = PSY.get_number(d)
        for t in time_steps
            balance_constraint[dc_bus_no, t] =
                JuMP.@constraint(get_jump_model(container), dc_expr[dc_bus_no, t] == 0)
        end
    end
    return
end
