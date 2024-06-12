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
    model::NetworkModel{T},
    devices::IS.FlattenIteratorWrapper{PSY.AreaInterchange},
    formulation::AbstractBranchFormulation,
) where {T <: Union{AreaBalancePowerModel, AreaPTDFPowerModel}}
    time_steps = get_time_steps(container)

    variable = add_variable_container!(
        container,
        FlowActivePowerVariable(),
        PSY.AreaInterchange,
        PSY.get_name.(devices),
        time_steps,
    )

    for device in devices, t in time_steps
        device_name = get_name(device)
        variable[device_name, t] = JuMP.@variable(
            get_jump_model(container),
            base_name = "FlowActivePowerVariable_AreaInterchange_{$(device_name), $(t)}",
        )
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{CopperPlateBalanceConstraint},
    sys::PSY.System,
    model::NetworkModel{AreaBalancePowerModel},
)
    expressions = get_expression(container, ActivePowerBalance(), PSY.Area)
    area_names, time_steps = axes(expressions)

    constraints = add_constraints_container!(
        container,
        CopperPlateBalanceConstraint(),
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
    ::NetworkModel{T},
) where {T <: Union{AreaBalancePowerModel, AreaPTDFPowerModel}}
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

function add_constraints!(
    container::OptimizationContainer,
    ::Type{LineFlowBoundConstraint},
    devices::IS.FlattenIteratorWrapper{PSY.AreaInterchange},
    model::DeviceModel{PSY.AreaInterchange, <:AbstractBranchFormulation},
    network_model::NetworkModel{AreaPTDFPowerModel},
    inter_area_branch_map,
)
    time_steps = get_time_steps(container)
    device_names = [PSY.get_name(d) for d in devices]

    con_ub = add_constraints_container!(
        container,
        LineFlowBoundConstraint(),
        PSY.AreaInterchange,
        device_names,
        time_steps;
        meta = "ub",
    )

    con_lb = add_constraints_container!(
        container,
        LineFlowBoundConstraint(),
        PSY.AreaInterchange,
        device_names,
        time_steps;
        meta = "lb",
    )

    area_ex_var = get_variable(container, FlowActivePowerVariable(), PSY.AreaInterchange)
    jm = get_jump_model(container)
    for area_interchange in devices
        inter_change_name = PSY.get_name(area_interchange)
        area_from = PSY.get_from_area(area_interchange)
        area_to = PSY.get_to_area(area_interchange)
        if haskey(inter_area_branch_map, (area_from, area_to))
            inter_area_branches = inter_area_branch_map[(area_from, area_to)]
            mult = 1.0
        elseif haskey(inter_area_branch_map, (area_to, area_from))
            inter_area_branches = inter_area_branch_map[(area_to, area_from)]
            mult = -1.0
        else
            @warn(
                "There are no branches modeled in Area InterChange $(summary(area_interchange)) \
          LineFlowBoundConstraint not created"
            )
            continue
        end

        for t in time_steps
            sum_of_flows = JuMP.AffExpr()
            for (type, branches) in inter_area_branches
                flow_vars = get_variable(container, FlowActivePowerVariable(), type)
                for b in branches
                    b_name = PSY.get_name(b)
                    _add_to_jump_expression!(sum_of_flows, flow_vars[b_name, t], mult)
                end
            end
            con_ub[inter_change_name, t] =
                JuMP.@constraint(jm, sum_of_flows <= area_ex_var[inter_change_name, t])
            con_lb[inter_change_name, t] =
                JuMP.@constraint(jm, sum_of_flows >= area_ex_var[inter_change_name, t])
        end
    end
    return
end
