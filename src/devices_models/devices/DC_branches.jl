#################################### Branch Variables ##################################################
get_variable_binary(_, ::Type{<:PSY.DCBranch}, ::AbstractDCLineFormulation) = false
get_variable_binary(
    ::FlowActivePowerVariable,
    ::Type{<:PSY.DCBranch},
    ::AbstractDCLineFormulation,
) = false

get_variable_binary(
    ::HVDCFlowDirectionVariable,
    ::Type{<:PSY.DCBranch},
    ::AbstractDCLineFormulation,
) = true

get_variable_multiplier(::FlowActivePowerVariable, ::Type{<:PSY.DCBranch}, _) = NaN

get_variable_multiplier(
    ::FlowActivePowerFromToVariable,
    ::Type{<:PSY.DCBranch},
    ::AbstractDCLineFormulation,
) = -1.0

get_variable_multiplier(
    ::FlowActivePowerToFromVariable,
    ::Type{<:PSY.DCBranch},
    ::AbstractDCLineFormulation,
) = 1.0

function get_variable_multiplier(::HVDCLosses, d::PSY.DCBranch, ::HVDCP2PDispatch)
    l1 = PSY.get_loss(d).l1
    l0 = PSY.get_loss(d).l0
    if l1 == 0.0 && l0 == 0.0
        return 0.0
    else
        return -1.0
    end
end

get_variable_lower_bound(::FlowActivePowerVariable, d::PSY.DCBranch, ::HVDCP2PUnbounded) =
    nothing

get_variable_upper_bound(::FlowActivePowerVariable, d::PSY.DCBranch, ::HVDCP2PUnbounded) =
    nothing

get_variable_lower_bound(
    ::FlowActivePowerVariable,
    d::PSY.DCBranch,
    ::AbstractDCLineFormulation,
) = nothing

get_variable_upper_bound(
    ::FlowActivePowerVariable,
    d::PSY.DCBranch,
    ::AbstractDCLineFormulation,
) = nothing

get_variable_lower_bound(::HVDCLosses, d::PSY.DCBranch, ::HVDCP2PDispatch) = 0.0

function get_variable_upper_bound(::HVDCLosses, d::PSY.DCBranch, ::HVDCP2PDispatch)
    l1 = PSY.get_loss(d).l1
    l0 = PSY.get_loss(d).l0
    if l1 == 0.0 && l0 == 0.0
        return 0.0
    else
        return nothing
    end
end

function get_default_time_series_names(
    ::Type{U},
    ::Type{V},
) where {U <: PSY.DCBranch, V <: AbstractDCLineFormulation}
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

function get_default_attributes(
    ::Type{U},
    ::Type{V},
) where {U <: PSY.DCBranch, V <: AbstractDCLineFormulation}
    return Dict{String, Any}()
end

get_initial_conditions_device_model(
    ::OperationModel,
    ::DeviceModel{T, U},
) where {T <: PSY.HVDCLine, U <: AbstractDCLineFormulation} = DeviceModel(T, U)

#################################### Rate Limits Constraints ##################################################
function _get_flow_bounds(d::PSY.HVDCLine)
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
    end

    if from_max >= 0.0 && to_max >= 0.0
        max_rate = min(from_max, to_max)
    elseif from_max <= 0.0 && to_max <= 0.0
        max_rate = max(from_max, to_max)
    elseif from_max <= 0.0 && to_max >= 0.0
        max_rate = from_max
    elseif from_max >= 0.0 && to_max <= 0.0
        max_rate = to_max
    end

    return min_rate, max_rate
end

add_constraints!(
    ::OptimizationContainer,
    ::Type{<:Union{FlowRateConstraintFromTo, FlowRateConstraintToFrom}},
    ::IS.FlattenIteratorWrapper{<:PSY.DCBranch},
    ::DeviceModel{<:PSY.DCBranch, HVDCP2PUnbounded},
    ::NetworkModel{<:PM.AbstractPowerModel},
) = nothing

add_constraints!(
    ::OptimizationContainer,
    ::Type{FlowRateConstraint},
    ::IS.FlattenIteratorWrapper{<:PSY.DCBranch},
    ::DeviceModel{<:PSY.DCBranch, HVDCP2PUnbounded},
    ::NetworkModel{<:PM.AbstractPowerModel},
) = nothing

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    ::DeviceModel{U, HVDCP2PLossless},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: FlowRateConstraint, U <: PSY.DCBranch}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]

    var = get_variable(container, FlowActivePowerVariable(), U)
    constraint_ub =
        add_constraints_container!(container, T(), U, names, time_steps; meta = "ub")
    constraint_lb =
        add_constraints_container!(container, T(), U, names, time_steps; meta = "lb")
    for d in devices
        min_rate, max_rate = _get_flow_bounds(d)
        for t in time_steps
            constraint_ub[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                var[PSY.get_name(d), t] <= max_rate
            )
            constraint_lb[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                min_rate <= var[PSY.get_name(d), t]
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{FlowRateConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, HVDCP2PLossless},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {T <: PSY.DCBranch}
    inter_network_branches = T[]
    for d in devices
        ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
        ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
        if ref_bus_from != ref_bus_to
            push!(inter_network_branches, d)
        end
    end
    if !isempty(inter_network_branches)
        add_constraints!(
            container,
            FlowRateConstraint,
            inter_network_branches,
            model,
            network_model,
        )
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    devices::IS.FlattenIteratorWrapper{U},
    ::DeviceModel{U, HVDCP2PDispatch},
    ::NetworkModel{<:PM.AbstractDCPModel},
) where {T <: FlowRateConstraintFromTo, U <: PSY.DCBranch}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]

    var = get_variable(container, FlowActivePowerFromToVariable(), U)
    constraint_ub =
        add_constraints_container!(container, T(), U, names, time_steps; meta = "ub")
    constraint_lb =
        add_constraints_container!(container, T(), U, names, time_steps; meta = "lb")
    for d in devices
        min_rate, max_rate = PSY.get_active_power_limits_from(d)
        for t in time_steps
            constraint_ub[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                var[PSY.get_name(d), t] <= max_rate
            )
            constraint_lb[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                min_rate <= var[PSY.get_name(d), t]
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    devices::IS.FlattenIteratorWrapper{U},
    ::DeviceModel{U, HVDCP2PDispatch},
    ::NetworkModel{<:PM.AbstractDCPModel},
) where {T <: FlowRateConstraintToFrom, U <: PSY.DCBranch}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]

    var = get_variable(container, FlowActivePowerToFromVariable(), U)
    constraint_ub =
        add_constraints_container!(container, T(), U, names, time_steps; meta = "ub")
    constraint_lb =
        add_constraints_container!(container, T(), U, names, time_steps; meta = "lb")
    for d in devices
        min_rate, max_rate = PSY.get_active_power_limits_to(d)
        for t in time_steps
            constraint_ub[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                var[PSY.get_name(d), t] <= max_rate
            )
            constraint_lb[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                min_rate <= var[PSY.get_name(d), t]
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    devices::IS.FlattenIteratorWrapper{U},
    ::DeviceModel{U, HVDCP2PDispatch},
    ::NetworkModel{<:PM.AbstractDCPModel},
) where {T <: HVDCDirection, U <: PSY.DCBranch}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]

    tf_var = get_variable(container, FlowActivePowerToFromVariable(), U)
    ft_var = get_variable(container, FlowActivePowerFromToVariable(), U)
    direction_var = get_variable(container, HVDCFlowDirectionVariable(), U)

    constraint_ft_ub =
        add_constraints_container!(container, T(), U, names, time_steps; meta = "ft_ub")
    constraint_tf_ub =
        add_constraints_container!(container, T(), U, names, time_steps; meta = "tf_ub")
    constraint_ft_lb =
        add_constraints_container!(container, T(), U, names, time_steps; meta = "ft_lb")
    constraint_tf_lb =
        add_constraints_container!(container, T(), U, names, time_steps; meta = "tf_lb")
    for d in devices
        min_rate_to, max_rate_to = PSY.get_active_power_limits_to(d)
        min_rate_from, max_rate_from = PSY.get_active_power_limits_to(d)
        name = PSY.get_name(d)
        for t in time_steps
            constraint_tf_ub[name, t] = JuMP.@constraint(
                get_jump_model(container),
                tf_var[name, t] <= max_rate_to * (1 - direction_var[name, t])
            )
            constraint_ft_ub[name, t] = JuMP.@constraint(
                get_jump_model(container),
                ft_var[name, t] <= max_rate_from * (1 - direction_var[name, t])
            )
            constraint_tf_lb[name, t] = JuMP.@constraint(
                get_jump_model(container),
                direction_var[name, t] * min_rate_to <= tf_var[name, t]
            )
            constraint_ft_lb[name, t] = JuMP.@constraint(
                get_jump_model(container),
                direction_var[name, t] * min_rate_from <= tf_var[name, t]
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{HVDCPowerBalance},
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, <:AbstractDCLineFormulation},
    ::NetworkModel{<:PM.AbstractDCPModel},
) where {T <: PSY.DCBranch}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    tf_var = get_variable(container, FlowActivePowerToFromVariable(), T)
    ft_var = get_variable(container, FlowActivePowerFromToVariable(), T)
    direction_var = get_variable(container, HVDCFlowDirectionVariable(), T)

    constraint_ft_ub = add_constraints_container!(
        container,
        HVDCPowerBalance(),
        T,
        names,
        time_steps;
        meta = "ft_ub",
    )
    constraint_tf_ub = add_constraints_container!(
        container,
        HVDCPowerBalance(),
        T,
        names,
        time_steps;
        meta = "tf_ub",
    )
    constraint_ft_lb = add_constraints_container!(
        container,
        HVDCPowerBalance(),
        T,
        names,
        time_steps;
        meta = "tf_lb",
    )
    constraint_tf_lb = add_constraints_container!(
        container,
        HVDCPowerBalance(),
        T,
        names,
        time_steps;
        meta = "ft_lb",
    )
    for d in devices
        l1 = PSY.get_loss(d).l1
        l0 = PSY.get_loss(d).l0
        name = PSY.get_name(d)
        for t in get_time_steps(container)
            if l1 == 0.0 && l0 == 0.0
                constraint_tf_ub[PSY.get_name(d), t] = JuMP.@constraint(
                    get_jump_model(container),
                    tf_var[name, t] - ft_var[name, t] == 0.0
                )
                constraint_ft_ub[PSY.get_name(d), t] = JuMP.@constraint(
                    get_jump_model(container),
                    ft_var[name, t] - tf_var[name, t] == 0.0
                )
            else
                constraint_tf_ub[PSY.get_name(d), t] = JuMP.@constraint(
                    get_jump_model(container),
                    tf_var[name, t] - ft_var[name, t] <= l1 * tf_var[name, t] - l0
                )
                constraint_ft_ub[PSY.get_name(d), t] = JuMP.@constraint(
                    get_jump_model(container),
                    ft_var[name, t] - tf_var[name, t] >= l1 * ft_var[name, t] + l0
                )
            end
            constraint_tf_lb[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                ft_var[name, t] - tf_var[name, t] >=
                -M_VALUE * (1 - direction_var[name, t])
            )
            constraint_ft_lb[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                tf_var[name, t] - ft_var[name, t] >= -M_VALUE * (direction_var[name, t])
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{HVDCLossesAbsoluteValue},
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, <:AbstractDCLineFormulation},
    ::NetworkModel{<:PM.AbstractDCPModel},
) where {T <: PSY.DCBranch}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    losses = get_variable(container, HVDCLosses(), T)
    tf_var = get_variable(container, FlowActivePowerToFromVariable(), T)
    ft_var = get_variable(container, FlowActivePowerFromToVariable(), T)
    constraint_tf = add_constraints_container!(
        container,
        HVDCLossesAbsoluteValue(),
        T,
        names,
        time_steps;
        meta = "tf",
    )
    constraint_ft = add_constraints_container!(
        container,
        HVDCLossesAbsoluteValue(),
        T,
        names,
        time_steps;
        meta = "ft",
    )
    for d in devices
        name = PSY.get_name(d)
        for t in get_time_steps(container)
            constraint_tf[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                tf_var[name, t] - ft_var[name, t] <= losses[name, t]
            )
            constraint_ft[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                -tf_var[name, t] + ft_var[name, t] <= losses[name, t]
            )
        end
    end
    return
end
