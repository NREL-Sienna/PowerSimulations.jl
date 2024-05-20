function get_default_time_series_names(
    ::Type{PSY.AreaInterchange},
    ::Type{V},
) where {V <: AbstractBranchFormulation}
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

function get_default_attributes(
    ::Type{PSY.AreaInterchange},
    ::Type{V},
) where {V <: AbstractBranchFormulation}
    return Dict{String, Any}()
end

function add_variables!(
    container::OptimizationContainer,
    ::Type{FlowActivePowerVariable},
    model::NetworkModel{AreaBalancePowerModel},
    devices::IS.FlattenIteratorWrapper{PSY.AreaInterchange},
    formulation::AbstractBranchFormulation,
)
    time_steps = get_time_steps(container)

    variable = add_variable_container!(
        container,
        FlowActivePowerVariable(),
        PSY.AreaInterchange,
        get_name.(devices),
        time_steps,
    )

    for device in devices, t in time_steps
        device_name = get_name(device)
        variable[device_name, t] = JuMP.@variable(get_jump_model(container))
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{AreaDispatchBalanceConstraint},
    sys::PSY.System,
    model::NetworkModel{AreaBalancePowerModel},
)
    expressions = get_expression(container, ActivePowerBalance(), PSY.Area)
    area_names, time_steps = axes(expressions)

    constraints = add_constraints_container!(
        container,
        AreaDispatchBalanceConstraint(),
        PSY.Area,
        area_names,
        time_steps,
    )

    for a in area_names, t in time_steps
        constraints[a, t] =
            JuMP.@constraint(get_jump_model(container), expressions[a, t] == 0.0)
    end
    return
end

"""
Add flow constraints for area interchanges
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{FlowLimitConstraint},
    devices::IS.FlattenIteratorWrapper{PSY.AreaInterchange},
    model::DeviceModel{PSY.AreaInterchange, StaticBranch},
    ::NetworkModel{AreaBalancePowerModel},
)
    time_steps = get_time_steps(container)
    device_names = [PSY.get_name(d) for d in devices]

    con_ub = add_constraints_container!(
        container,
        FlowLimitConstraint(),
        PSY.AreaInterchange,
        device_names,
        time_steps;
        meta = "ub",
    )

    con_lb = add_constraints_container!(
        container,
        FlowLimitConstraint(),
        PSY.AreaInterchange,
        device_names,
        time_steps;
        meta = "lb",
    )

    var_array = get_variable(container, FlowActivePowerVariable(), PSY.AreaInterchange)

    for device in devices
        ci_name = PSY.get_name(device)
        to_from_limit = PSY.get_flow_limits(device).to_from
        from_to_limit = PSY.get_flow_limits(device).from_to
        for t in time_steps
            con_lb[ci_name, t] =
                JuMP.@constraint(
                    get_jump_model(container),
                    var_array[ci_name, t] >= -1.0 * from_to_limit
                )
            con_ub[ci_name, t] =
                JuMP.@constraint(
                    get_jump_model(container),
                    var_array[ci_name, t] <= to_from_limit
                )
        end
    end
    return
end
