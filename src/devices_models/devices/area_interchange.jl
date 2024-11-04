#! format: off
get_multiplier_value(::FromToFlowLimitParameter, d::PSY.AreaInterchange, ::AbstractBranchFormulation) = -1.0 * PSY.get_from_to_flow_limit(d)
get_multiplier_value(::ToFromFlowLimitParameter, d::PSY.AreaInterchange, ::AbstractBranchFormulation) = PSY.get_to_from_flow_limit(d)

get_parameter_multiplier(::FixValueParameter, ::PSY.AreaInterchange, ::AbstractBranchFormulation) = 1.0
get_parameter_multiplier(::LowerBoundValueParameter, ::PSY.AreaInterchange, ::AbstractBranchFormulation) = 1.0
get_parameter_multiplier(::UpperBoundValueParameter, ::PSY.AreaInterchange, ::AbstractBranchFormulation) = 1.0

get_initial_conditions_device_model(
    ::OperationModel,
    model::DeviceModel{PSY.AreaInterchange, T},
) where {T <: AbstractBranchFormulation} = DeviceModel(PSY.AreaInterchange, T)

#! format: on

function get_default_time_series_names(
    ::Type{PSY.AreaInterchange},
    ::Type{V},
) where {V <: AbstractBranchFormulation}
    return Dict{Type{<:TimeSeriesParameter}, String}(
        FromToFlowLimitParameter => "from_to_flow_limit",
        ToFromFlowLimitParameter => "to_from_flow_limit",
    )
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
) where {T <: PM.AbstractPowerModel}
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

function add_variables!(
    container::OptimizationContainer,
    ::Type{FlowActivePowerVariable},
    model::NetworkModel{CopperPlatePowerModel},
    devices::IS.FlattenIteratorWrapper{PSY.AreaInterchange},
    formulation::AbstractBranchFormulation,
)
    @warn(
        "CopperPlatePowerModel ignores AreaInterchanges. Instead use AreaBalancePowerModel."
    )
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
) where {T <: PM.AbstractActivePowerModel}
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
    if !all(PSY.has_time_series.(devices))
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
    else
        param_container_from_to =
            get_parameter(container, FromToFlowLimitParameter(), PSY.AreaInterchange)
        param_multiplier_from_to = get_parameter_multiplier_array(
            container,
            FromToFlowLimitParameter(),
            PSY.AreaInterchange,
        )
        param_container_to_from =
            get_parameter(container, ToFromFlowLimitParameter(), PSY.AreaInterchange)
        param_multiplier_to_from = get_parameter_multiplier_array(
            container,
            ToFromFlowLimitParameter(),
            PSY.AreaInterchange,
        )
        jump_model = get_jump_model(container)
        for device in devices
            name = PSY.get_name(device)
            param_from_to = get_parameter_column_refs(param_container_from_to, name)
            param_to_from = get_parameter_column_refs(param_container_to_from, name)
            for t in time_steps
                con_lb[name, t] = JuMP.@constraint(
                    jump_model,
                    var_array[name, t] >=
                    param_multiplier_from_to[name, t] * param_from_to[t]
                )
                con_ub[name, t] = JuMP.@constraint(
                    jump_model,
                    var_array[name, t] <=
                    param_multiplier_to_from[name, t] * param_to_from[t]
                )
            end
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{LineFlowBoundConstraint},
    devices::IS.FlattenIteratorWrapper{PSY.AreaInterchange},
    model::DeviceModel{PSY.AreaInterchange, <:AbstractBranchFormulation},
    network_model::NetworkModel{T},
    inter_area_branch_map::Dict{
        Tuple{PSY.Area, PSY.Area},
        Dict{DataType, Vector{<:PSY.ACBranch}},
    },
) where {T <: AbstractPTDFModel}
    @assert !isempty(inter_area_branch_map)

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
        direction_branch_map = Dict{Float64, Dict{DataType, Vector{<:PSY.ACBranch}}}()
        if haskey(inter_area_branch_map, (area_from, area_to))
            # 1 is the multiplier
            direction_branch_map[1.0] = inter_area_branch_map[(area_from, area_to)]
        end
        if haskey(inter_area_branch_map, (area_to, area_from))
            # -1 is the multiplier because the direction is reversed
            direction_branch_map[-1.0] = inter_area_branch_map[(area_to, area_from)]
        end
        if isempty(direction_branch_map)
            @warn(
                "There are no branches modeled in Area InterChange $(summary(area_interchange)) \
          LineFlowBoundConstraint not created"
            )
            continue
        end

        for t in time_steps
            sum_of_flows = JuMP.AffExpr()
            for (mult, inter_area_branches) in direction_branch_map
                for (type, branches) in inter_area_branches
                    flow_vars = get_variable(container, FlowActivePowerVariable(), type)
                    for b in branches
                        b_name = PSY.get_name(b)
                        _add_to_jump_expression!(sum_of_flows, flow_vars[b_name, t], mult)
                    end
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
