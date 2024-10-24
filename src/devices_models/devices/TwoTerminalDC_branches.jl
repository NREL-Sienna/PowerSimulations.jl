#################################### Branch Variables ##################################################
get_variable_binary(
    _,
    ::Type{<:PSY.TwoTerminalHVDCLine},
    ::AbstractTwoTerminalDCLineFormulation,
) =
    false
get_variable_binary(
    ::FlowActivePowerVariable,
    ::Type{<:PSY.TwoTerminalHVDCLine},
    ::AbstractTwoTerminalDCLineFormulation,
) = false

get_variable_binary(
    ::HVDCFlowDirectionVariable,
    ::Type{<:PSY.TwoTerminalHVDCLine},
    ::AbstractTwoTerminalDCLineFormulation,
) = true

get_variable_binary(
    _,
    ::Type{<:PSY.TwoTerminalHVDCDetailedLine},
    ::HVDCTwoTerminalPhysicalLoss,
) = false
get_variable_binary(
    ::InterpolationBinarySquaredVoltageVariableFrom,
    ::Type{<:PSY.TwoTerminalHVDCDetailedLine},
    ::HVDCTwoTerminalPhysicalLoss,
) = true
get_variable_binary(
    ::InterpolationBinarySquaredVoltageVariableTo,
    ::Type{<:PSY.TwoTerminalHVDCDetailedLine},
    ::HVDCTwoTerminalPhysicalLoss,
) = true
get_variable_binary(
    ::InterpolationBinarySquaredBilinearVariableFrom,
    ::Type{<:PSY.TwoTerminalHVDCDetailedLine},
    ::HVDCTwoTerminalPhysicalLoss,
) = true
get_variable_binary(
    ::InterpolationBinarySquaredBilinearVariableTo,
    ::Type{<:PSY.TwoTerminalHVDCDetailedLine},
    ::HVDCTwoTerminalPhysicalLoss,
) = true
get_variable_binary(
    ::ConverterPowerDirection,
    ::Type{<:PSY.TwoTerminalHVDCDetailedLine},
    ::HVDCTwoTerminalPhysicalLoss,
) = true

get_variable_multiplier(::FlowActivePowerVariable, ::Type{<:PSY.TwoTerminalHVDCLine}, _) =
    NaN
get_parameter_multiplier(
    ::FixValueParameter,
    ::PSY.TwoTerminalHVDCLine,
    ::AbstractTwoTerminalDCLineFormulation,
) = 1.0

get_variable_multiplier(
    ::FlowActivePowerFromToVariable,
    ::Type{<:PSY.TwoTerminalHVDCLine},
    ::AbstractTwoTerminalDCLineFormulation,
) = -1.0

get_variable_multiplier(
    ::FlowActivePowerToFromVariable,
    ::Type{<:PSY.TwoTerminalHVDCLine},
    ::AbstractTwoTerminalDCLineFormulation,
) = -1.0

function get_variable_multiplier(
    ::HVDCLosses,
    d::PSY.TwoTerminalHVDCLine,
    ::HVDCTwoTerminalDispatch,
)
    loss = PSY.get_loss(d)
    if !isa(loss, PSY.LinearCurve)
        error(
            "HVDCTwoTerminalDispatch of branch $(PSY.get_name(d)) only accepts LinearCurve for loss models.",
        )
    end
    l1 = PSY.get_proportional_term(loss)
    l0 = PSY.get_constant_term(loss)
    if l1 == 0.0 && l0 == 0.0
        return 0.0
    else
        return -1.0
    end
end

get_variable_lower_bound(
    ::FlowActivePowerVariable,
    d::PSY.TwoTerminalHVDCLine,
    ::HVDCTwoTerminalUnbounded,
) = nothing

get_variable_upper_bound(
    ::FlowActivePowerVariable,
    d::PSY.TwoTerminalHVDCLine,
    ::HVDCTwoTerminalUnbounded,
) = nothing

get_variable_lower_bound(
    ::FlowActivePowerVariable,
    d::PSY.TwoTerminalHVDCLine,
    ::AbstractTwoTerminalDCLineFormulation,
) = nothing

get_variable_upper_bound(
    ::FlowActivePowerVariable,
    d::PSY.TwoTerminalHVDCLine,
    ::AbstractTwoTerminalDCLineFormulation,
) = nothing

### Two Terminal Dispatch ###
get_variable_lower_bound(
    ::HVDCLosses,
    d::PSY.TwoTerminalHVDCLine,
    ::HVDCTwoTerminalDispatch,
) = 0.0

get_variable_upper_bound(
    ::FlowActivePowerFromToVariable,
    d::PSY.TwoTerminalHVDCLine,
    ::HVDCTwoTerminalDispatch,
) = PSY.get_active_power_limits_from(d).max

get_variable_lower_bound(
    ::FlowActivePowerFromToVariable,
    d::PSY.TwoTerminalHVDCLine,
    ::HVDCTwoTerminalDispatch,
) = PSY.get_active_power_limits_from(d).min

get_variable_upper_bound(
    ::FlowActivePowerToFromVariable,
    d::PSY.TwoTerminalHVDCLine,
    ::HVDCTwoTerminalDispatch,
) = PSY.get_active_power_limits_to(d).max

get_variable_lower_bound(
    ::FlowActivePowerToFromVariable,
    d::PSY.TwoTerminalHVDCLine,
    ::HVDCTwoTerminalDispatch,
) = PSY.get_active_power_limits_to(d).min

get_variable_upper_bound(
    ::HVDCActivePowerReceivedFromVariable,
    d::Union{PSY.TwoTerminalHVDCLine, PSY.TwoTerminalHVDCDetailedLine},
    ::AbstractTwoTerminalDCLineFormulation,
) = PSY.get_active_power_limits_from(d).max

get_variable_lower_bound(
    ::HVDCActivePowerReceivedFromVariable,
    d::Union{PSY.TwoTerminalHVDCLine, PSY.TwoTerminalHVDCDetailedLine},
    ::AbstractTwoTerminalDCLineFormulation,
) = PSY.get_active_power_limits_from(d).min

get_variable_upper_bound(
    ::HVDCActivePowerReceivedToVariable,
    d::Union{PSY.TwoTerminalHVDCLine, PSY.TwoTerminalHVDCDetailedLine},
    ::AbstractTwoTerminalDCLineFormulation,
) = PSY.get_active_power_limits_to(d).max

get_variable_lower_bound(
    ::HVDCActivePowerReceivedToVariable,
    d::Union{PSY.TwoTerminalHVDCLine, PSY.TwoTerminalHVDCDetailedLine},
    ::AbstractTwoTerminalDCLineFormulation,
) = PSY.get_active_power_limits_to(d).min

function get_variable_upper_bound(
    ::HVDCLosses,
    d::PSY.TwoTerminalHVDCLine,
    ::HVDCTwoTerminalDispatch,
)
    loss = PSY.get_loss(d)
    if !isa(loss, PSY.LinearCurve)
        error(
            "HVDCTwoTerminalDispatch of branch $(PSY.get_name(d)) only accepts LinearCurve for loss models.",
        )
    end
    l1 = PSY.get_proportional_term(loss)
    l0 = PSY.get_constant_term(loss)
    if l1 == 0.0 && l0 == 0.0
        return 0.0
    else
        return nothing
    end
end

get_variable_upper_bound(
    ::HVDCPiecewiseLossVariable,
    d::PSY.TwoTerminalHVDCLine,
    ::Union{HVDCTwoTerminalDispatch, HVDCTwoTerminalPiecewiseLoss},
) = 1.0

get_variable_lower_bound(
    ::HVDCPiecewiseLossVariable,
    d::PSY.TwoTerminalHVDCLine,
    ::Union{HVDCTwoTerminalDispatch, HVDCTwoTerminalPiecewiseLoss},
) = 0.0

### Two Terminal Physical Loss ###
get_variable_upper_bound(
    ::Union{DCVoltageFrom, DCVoltageTo},
    d::PSY.TwoTerminalHVDCDetailedLine,
    ::HVDCTwoTerminalPhysicalLoss,
) = PSY.get_voltage_limits(d).max

get_variable_lower_bound(
    ::Union{DCVoltageFrom, DCVoltageTo},
    d::PSY.TwoTerminalHVDCDetailedLine,
    ::HVDCTwoTerminalPhysicalLoss,
) = PSY.get_voltage_limits(d).min

get_variable_upper_bound(
    ::Union{SquaredDCVoltageFrom, SquaredDCVoltageTo},
    d::PSY.TwoTerminalHVDCDetailedLine,
    ::HVDCTwoTerminalPhysicalLoss,
) = PSY.get_voltage_limits(d).max^2

get_variable_lower_bound(
    ::Union{SquaredDCVoltageFrom, SquaredDCVoltageTo},
    d::PSY.TwoTerminalHVDCDetailedLine,
    ::HVDCTwoTerminalPhysicalLoss,
) = 0.0

get_variable_upper_bound(
    ::Union{
        InterpolationSquaredVoltageVariableFrom,
        InterpolationSquaredVoltageVariableTo,
        InterpolationSquaredCurrentVariable,
        InterpolationSquaredBilinearVariableFrom,
        InterpolationSquaredBilinearVariableTo,
    },
    d::PSY.TwoTerminalHVDCDetailedLine,
    ::HVDCTwoTerminalPhysicalLoss,
) = 1.0

get_variable_lower_bound(
    ::Union{
        InterpolationSquaredVoltageVariableFrom,
        InterpolationSquaredVoltageVariableTo,
        InterpolationSquaredCurrentVariable,
        InterpolationSquaredBilinearVariableFrom,
        InterpolationSquaredBilinearVariableTo,
    },
    d::PSY.TwoTerminalHVDCDetailedLine,
    ::HVDCTwoTerminalPhysicalLoss,
) = 0.0

function get_default_time_series_names(
    ::Type{U},
    ::Type{V},
) where {U <: PSY.TwoTerminalHVDCLine, V <: AbstractTwoTerminalDCLineFormulation}
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

function get_default_attributes(
    ::Type{U},
    ::Type{V},
) where {U <: PSY.TwoTerminalHVDCLine, V <: AbstractTwoTerminalDCLineFormulation}
    return Dict{String, Any}()
end

get_initial_conditions_device_model(
    ::OperationModel,
    ::DeviceModel{T, U},
) where {T <: PSY.TwoTerminalHVDCLine, U <: AbstractTwoTerminalDCLineFormulation} =
    DeviceModel(T, U)

####################################### PWL Constraints #######################################################

function _get_range_segments(::PSY.TwoTerminalHVDCLine, loss::PSY.LinearCurve)
    return 1:4
end

function _get_range_segments(::PSY.TwoTerminalHVDCLine, loss::PSY.PiecewiseIncrementalCurve)
    loss_factors = PSY.get_slopes(loss)
    return 1:(2 * length(loss_factors) + 2)
end

function _get_pwl_loss_params(d::PSY.TwoTerminalHVDCLine, loss::PSY.LinearCurve)
    from_to_loss_params = Vector{Float64}(undef, 4)
    to_from_loss_params = Vector{Float64}(undef, 4)
    loss_factor = PSY.get_proportional_term(loss)
    P_send0 = PSY.get_constant_term(loss)
    P_max_ft = PSY.get_active_power_limits_from(d).max
    P_max_tf = PSY.get_active_power_limits_to(d).max
    if P_max_ft != P_max_tf
        error(
            "HVDC Line $(PSY.get_name(d)) has non-symmetrical limits for from and to, that are not supported in the HVDCTwoTerminalPiecewiseLoss formulation",
        )
    end
    P_sendS = P_max_ft
    ### Update Params Vectors ###
    from_to_loss_params[1] = -P_sendS - P_send0
    from_to_loss_params[2] = -P_send0
    from_to_loss_params[3] = 0.0
    from_to_loss_params[4] = P_sendS * (1 - loss_factor)

    to_from_loss_params[1] = P_sendS * (1 - loss_factor)
    to_from_loss_params[2] = 0.0
    to_from_loss_params[3] = -P_send0
    to_from_loss_params[4] = -P_sendS - P_send0

    return from_to_loss_params, to_from_loss_params
end

function _get_pwl_loss_params(
    d::PSY.TwoTerminalHVDCLine,
    loss::PSY.PiecewiseIncrementalCurve,
)
    p_breakpoints = PSY.get_x_coords(loss)
    loss_factors = PSY.get_slopes(loss)
    len_segments = length(loss_factors)
    len_variables = 2 * len_segments + 2
    from_to_loss_params = Vector{Float64}(undef, len_variables)
    to_from_loss_params = similar(from_to_loss_params)
    P_max_ft = PSY.get_active_power_limits_from(d).max
    P_max_tf = PSY.get_active_power_limits_to(d).max
    if P_max_ft != P_max_tf
        error(
            "HVDC Line $(PSY.get_name(d)) has non-symmetrical limits for from and to, that are not supported in the HVDCTwoTerminalPiecewiseLoss formulation",
        )
    end
    if P_max_ft != last(p_breakpoints)
        error(
            "Maximum power limit $P_max_ft of HVDC Line $(PSY.get_name(d)) has different value of last breakpoint from Loss data $(last(p_breakpoints)).",
        )
    end
    ### Update Params Vectors ###
    ## Update from 1 to S
    for i in 1:len_segments
        from_to_loss_params[i] = -p_breakpoints[2 + len_segments - i] - p_breakpoints[1] # for i = 1: P_end, for i = len_segments: P_2
        to_from_loss_params[i] =
            p_breakpoints[2 + len_segments - i] * (1 - loss_factors[len_segments + 1 - i])
    end
    ## Update from S+1 and S+2
    from_to_loss_params[len_segments + 1] = -p_breakpoints[1] # P_send0
    from_to_loss_params[len_segments + 2] = 0.0
    to_from_loss_params[len_segments + 1] = 0.0
    to_from_loss_params[len_segments + 2] = -p_breakpoints[1] # P_send0
    ## Update from S+3 to 2S+2
    for i in 1:len_segments
        from_to_loss_params[2 + len_segments + i] =
            p_breakpoints[i + 1] * (1 - loss_factors[i])
        to_from_loss_params[2 + len_segments + i] = -p_breakpoints[i + 1] - p_breakpoints[1]
    end

    return from_to_loss_params, to_from_loss_params
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    ::DeviceModel{U, HVDCTwoTerminalPiecewiseLoss},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: HVDCFlowCalculationConstraint, U <: PSY.TwoTerminalHVDCLine}
    var_pwl = get_variable(container, HVDCPiecewiseLossVariable(), U)
    var_pwl_bin = get_variable(container, HVDCPiecewiseBinaryLossVariable(), U)
    names = PSY.get_name.(devices)
    time_steps = get_time_steps(container)
    flow_ft = get_variable(container, HVDCActivePowerReceivedFromVariable(), U)
    flow_tf = get_variable(container, HVDCActivePowerReceivedToVariable(), U)

    constraint_from_to =
        add_constraints_container!(container, T(), U, names, time_steps; meta = "ft")
    constraint_to_from =
        add_constraints_container!(container, T(), U, names, time_steps; meta = "tf")
    constraint_binary =
        add_constraints_container!(container, T(), U, names, time_steps; meta = "bin")
    for d in devices
        name = PSY.get_name(d)
        loss = PSY.get_loss(d)
        from_to_params, to_from_params = _get_pwl_loss_params(d, loss)
        #@show from_to_params
        #@show to_from_params
        range_segments = 1:(length(from_to_params) - 1) # 1:(2S+1)
        for t in time_steps
            ## Add Equality Constraints ##
            constraint_from_to[name, t] = JuMP.@constraint(
                get_jump_model(container),
                flow_ft[name, t] ==
                sum(
                    var_pwl_bin[name, ix, t] * from_to_params[ix] for
                    ix in range_segments
                ) + sum(
                    var_pwl[name, ix, t] * (from_to_params[ix + 1] - from_to_params[ix]) for
                    ix in range_segments
                )
            )
            constraint_to_from[name, t] = JuMP.@constraint(
                get_jump_model(container),
                flow_tf[name, t] ==
                sum(
                    var_pwl_bin[name, ix, t] * to_from_params[ix] for
                    ix in range_segments
                ) + sum(
                    var_pwl[name, ix, t] * (to_from_params[ix + 1] - to_from_params[ix]) for
                    ix in range_segments
                )
            )
            ## Add Binary Bound ###
            constraint_binary[name, t] = JuMP.@constraint(
                get_jump_model(container),
                sum(var_pwl_bin[name, ix, t] for ix in range_segments) == 1.0
            )
            ## Add Bounds for Continuous ##
            for ix in range_segments
                JuMP.@constraint(
                    get_jump_model(container),
                    var_pwl[name, ix, t] <= var_pwl_bin[name, ix, t]
                )
                if ix == div(length(range_segments) + 1, 2)
                    JuMP.fix(var_pwl[name, ix, t], 0.0; force = true)
                end
            end
        end
    end
    return
end

#################################### Rate Limits Constraints ##################################################
function _get_flow_bounds(d::PSY.TwoTerminalHVDCLine)
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
    ::IS.FlattenIteratorWrapper{<:PSY.TwoTerminalHVDCLine},
    ::DeviceModel{<:PSY.TwoTerminalHVDCLine, HVDCTwoTerminalUnbounded},
    ::NetworkModel{<:PM.AbstractPowerModel},
) = nothing

add_constraints!(
    ::OptimizationContainer,
    ::Type{FlowRateConstraint},
    ::IS.FlattenIteratorWrapper{<:PSY.TwoTerminalHVDCLine},
    ::DeviceModel{<:PSY.TwoTerminalHVDCLine, HVDCTwoTerminalUnbounded},
    ::NetworkModel{<:PM.AbstractPowerModel},
) = nothing

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    ::DeviceModel{U, HVDCTwoTerminalLossless},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: FlowRateConstraint, U <: PSY.TwoTerminalHVDCLine}
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

function _add_hvdc_flow_constraints!(
    container::OptimizationContainer,
    devices::Union{Vector{T}, IS.FlattenIteratorWrapper{T}},
    constraint::FlowRateConstraintFromTo,
) where {T <: PSY.TwoTerminalHVDCLine}
    _add_hvdc_flow_constraints!(
        container,
        devices,
        FlowActivePowerFromToVariable(),
        constraint,
    )
end

function _add_hvdc_flow_constraints!(
    container::OptimizationContainer,
    devices::Union{Vector{T}, IS.FlattenIteratorWrapper{T}},
    constraint::FlowRateConstraintToFrom,
) where {T <: PSY.TwoTerminalHVDCLine}
    _add_hvdc_flow_constraints!(
        container,
        devices,
        FlowActivePowerToFromVariable(),
        constraint,
    )
end

function _add_hvdc_flow_constraints!(
    container::OptimizationContainer,
    devices::Union{Vector{T}, IS.FlattenIteratorWrapper{T}},
    var::Union{
        FlowActivePowerFromToVariable,
        FlowActivePowerToFromVariable,
        HVDCActivePowerReceivedFromVariable,
        HVDCActivePowerReceivedToVariable,
    },
    constraint::Union{FlowRateConstraintFromTo, FlowRateConstraintToFrom},
) where {T <: PSY.TwoTerminalHVDCLine}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]

    variable = get_variable(container, var, T)
    constraint_ub =
        add_constraints_container!(container, constraint, T, names, time_steps; meta = "ub")
    constraint_lb =
        add_constraints_container!(container, constraint, T, names, time_steps; meta = "lb")
    for d in devices
        check_hvdc_line_limits_consistency(d)
        max_rate = get_variable_upper_bound(var, d, HVDCTwoTerminalDispatch())
        min_rate = get_variable_lower_bound(var, d, HVDCTwoTerminalDispatch())
        for t in time_steps
            constraint_ub[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                variable[PSY.get_name(d), t] <= max_rate
            )
            constraint_lb[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                min_rate <= variable[PSY.get_name(d), t]
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    devices::IS.FlattenIteratorWrapper{U},
    model::DeviceModel{U, HVDCTwoTerminalDispatch},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {
    T <: Union{FlowRateConstraintFromTo, FlowRateConstraintToFrom},
    U <: PSY.TwoTerminalHVDCLine,
}
    inter_network_branches = U[]
    for d in devices
        ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
        ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
        if ref_bus_from != ref_bus_to
            push!(inter_network_branches, d)
        end
    end
    if !isempty(inter_network_branches)
        _add_hvdc_flow_constraints!(container, devices, T())
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    devices::IS.FlattenIteratorWrapper{U},
    ::DeviceModel{U, HVDCTwoTerminalDispatch},
    ::NetworkModel{<:PM.AbstractDCPModel},
) where {
    T <: Union{FlowRateConstraintToFrom, FlowRateConstraintFromTo},
    U <: PSY.TwoTerminalHVDCLine,
}
    _add_hvdc_flow_constraints!(container, devices, T())
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    devices::IS.FlattenIteratorWrapper{U},
    ::DeviceModel{U, HVDCTwoTerminalDispatch},
    ::NetworkModel{<:AbstractPTDFModel},
) where {
    T <: Union{FlowRateConstraintToFrom, FlowRateConstraintFromTo},
    U <: PSY.TwoTerminalHVDCLine,
}
    _add_hvdc_flow_constraints!(container, devices, T())
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    devices::IS.FlattenIteratorWrapper{U},
    model::DeviceModel{U, V},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {
    T <: Union{FlowRateConstraintFromTo, FlowRateConstraintToFrom},
    U <: PSY.TwoTerminalHVDCLine,
    V <: HVDCTwoTerminalPiecewiseLoss,
}
    inter_network_branches = U[]
    for d in devices
        ref_bus_from = get_reference_bus(network_model, PSY.get_arc(d).from)
        ref_bus_to = get_reference_bus(network_model, PSY.get_arc(d).to)
        if ref_bus_from != ref_bus_to
            push!(inter_network_branches, d)
        end
    end
    if !isempty(inter_network_branches)
        if T <: FlowRateConstraintFromTo
            _add_hvdc_flow_constraints!(
                container,
                devices,
                HVDCActivePowerReceivedFromVariable(),
                T(),
            )
        else
            _add_hvdc_flow_constraints!(
                container,
                devices,
                HVDCActivePowerReceivedToVariable(),
                T(),
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    devices::IS.FlattenIteratorWrapper{U},
    ::DeviceModel{U, V},
    ::NetworkModel{<:AbstractPTDFModel},
) where {
    T <: Union{FlowRateConstraintFromTo, FlowRateConstraintToFrom},
    U <: PSY.TwoTerminalHVDCLine,
    V <: HVDCTwoTerminalPiecewiseLoss,
}
    if T <: FlowRateConstraintFromTo
        _add_hvdc_flow_constraints!(
            container,
            devices,
            HVDCActivePowerReceivedFromVariable(),
            T(),
        )
    else
        _add_hvdc_flow_constraints!(
            container,
            devices,
            HVDCActivePowerReceivedToVariable(),
            T(),
        )
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{HVDCPowerBalance},
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, <:AbstractTwoTerminalDCLineFormulation},
    ::NetworkModel{<:PM.AbstractDCPModel},
) where {T <: PSY.TwoTerminalHVDCLine}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    tf_var = get_variable(container, FlowActivePowerToFromVariable(), T)
    ft_var = get_variable(container, FlowActivePowerFromToVariable(), T)
    direction_var = get_variable(container, HVDCFlowDirectionVariable(), T)
    losses = get_variable(container, HVDCLosses(), T)

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
    constraint_loss = add_constraints_container!(
        container,
        HVDCPowerBalance(),
        T,
        names,
        time_steps;
        meta = "loss",
    )
    constraint_loss_aux1 = add_constraints_container!(
        container,
        HVDCPowerBalance(),
        T,
        names,
        time_steps;
        meta = "loss_aux1",
    )
    constraint_loss_aux2 = add_constraints_container!(
        container,
        HVDCPowerBalance(),
        T,
        names,
        time_steps;
        meta = "loss_aux2",
    )
    for d in devices
        loss = PSY.get_loss(d)
        if !isa(loss, PSY.LinearCurve)
            error(
                "HVDCTwoTerminalDispatch of branch $(PSY.get_name(d)) only accepts LinearCurve for loss models.",
            )
        end
        l1 = PSY.get_proportional_term(loss)
        l0 = PSY.get_constant_term(loss)
        name = PSY.get_name(d)
        R_min_from, R_max_from = PSY.get_active_power_limits_from(d)
        R_min_to, R_max_to = PSY.get_active_power_limits_to(d)
        for t in get_time_steps(container)
            constraint_tf_ub[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                tf_var[name, t] <= R_max_to * direction_var[name, t]
            )
            constraint_tf_lb[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                tf_var[name, t] >= R_min_to * (1 - direction_var[name, t])
            )
            constraint_ft_ub[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                ft_var[name, t] <= R_max_from * (1 - direction_var[name, t])
            )
            constraint_ft_lb[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                ft_var[name, t] >= R_min_from * direction_var[name, t]
            )
            constraint_loss[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                tf_var[name, t] + ft_var[name, t] == losses[name, t]
            )
            constraint_loss_aux1[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                losses[name, t] >=
                l1 * ft_var[name, t] + l0 - M_VALUE * direction_var[name, t]
            )
            constraint_loss_aux2[PSY.get_name(d), t] = JuMP.@constraint(
                get_jump_model(container),
                losses[name, t] >=
                l1 * tf_var[name, t] + l0 - M_VALUE * (1 - direction_var[name, t])
            )
        end
    end
    return
end

##### Two Terminal Physical Loss ####

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    devices::IS.FlattenIteratorWrapper{U},
    ::DeviceModel{U, V},
    ::NetworkModel{<:AbstractPTDFModel},
) where {
    T <: ConverterPowerCalculationConstraint,
    U <: PSY.TwoTerminalHVDCDetailedLine,
    V <: HVDCTwoTerminalPhysicalLoss,
}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    # power vars #
    from_power_var = get_variable(container, HVDCActivePowerReceivedFromVariable(), U)
    to_power_var = get_variable(container, HVDCActivePowerReceivedToVariable(), U)
    # voltage vars #
    from_voltage_var = get_variable(container, DCVoltageFrom(), U)
    to_voltage_var = get_variable(container, DCVoltageTo(), U)
    from_voltage_sq_var = get_variable(container, SquaredDCVoltageFrom(), U)
    to_voltage_sq_var = get_variable(container, SquaredDCVoltageTo(), U)
    # current vars #
    current_var = get_variable(container, ConverterCurrent(), U) # From direction
    current_sq_var = get_variable(container, SquaredConverterCurrent(), U) # From direction
    # bilinear vars #
    from_bilinear_var = get_variable(container, AuxBilinearConverterVariableFrom(), U)
    from_bilinear_sq_var =
        get_variable(container, AuxBilinearSquaredConverterVariableFrom(), U)
    to_bilinear_var = get_variable(container, AuxBilinearConverterVariableTo(), U)
    to_bilinear_sq_var = get_variable(container, AuxBilinearSquaredConverterVariableTo(), U)

    constraint_from_calc = add_constraints_container!(
        container,
        T(),
        U,
        names,
        time_steps;
        meta = "from_calc",
    )
    constraint_from_aux = add_constraints_container!(
        container,
        T(),
        U,
        names,
        time_steps;
        meta = "from_aux",
    )
    constraint_to_calc = add_constraints_container!(
        container,
        T(),
        U,
        names,
        time_steps;
        meta = "to_calc",
    )
    constraint_to_aux = add_constraints_container!(
        container,
        T(),
        U,
        names,
        time_steps;
        meta = "to_aux",
    )

    for d in devices
        name = PSY.get_name(d)
        for t in get_time_steps(container)
            constraint_from_calc[name, t] = JuMP.@constraint(
                get_jump_model(container),
                from_power_var[name, t] ==
                0.5 * (
                    from_bilinear_sq_var[name, t] - from_voltage_sq_var[name, t] -
                    current_sq_var[name, t]
                )
            )
            constraint_to_calc[name, t] = JuMP.@constraint(
                get_jump_model(container),
                to_power_var[name, t] ==
                0.5 * (
                    to_bilinear_sq_var[name, t] - to_voltage_sq_var[name, t] -
                    current_sq_var[name, t]
                )
            )
            constraint_from_aux[name, t] = JuMP.@constraint(
                get_jump_model(container),
                from_bilinear_var[name, t] ==
                from_voltage_var[name, t] + current_var[name, t]
            )
            constraint_to_aux[name, t] = JuMP.@constraint(
                get_jump_model(container),
                to_bilinear_var[name, t] == to_voltage_var[name, t] - current_var[name, t] # change current sign
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    devices::IS.FlattenIteratorWrapper{U},
    ::DeviceModel{U, V},
    ::NetworkModel{<:AbstractPTDFModel},
) where {
    T <: ConverterDirectionConstraint,
    U <: PSY.TwoTerminalHVDCDetailedLine,
    V <: HVDCTwoTerminalPhysicalLoss,
}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    JuMPmodel = get_jump_model(container)
    # power vars #
    from_power_var = get_variable(container, HVDCActivePowerReceivedFromVariable(), U)
    to_power_var = get_variable(container, HVDCActivePowerReceivedToVariable(), U)
    # current vars #
    current_var = get_variable(container, ConverterCurrent(), U) # From direction
    direction_var = get_variable(container, ConverterPowerDirection(), U)

    constraint_from_power_ub = add_constraints_container!(
        container,
        T(),
        U,
        names,
        time_steps;
        meta = "from_power_ub",
    )
    constraint_from_power_lb = add_constraints_container!(
        container,
        T(),
        U,
        names,
        time_steps;
        meta = "from_power_lb",
    )
    constraint_current_ub = add_constraints_container!(
        container,
        T(),
        U,
        names,
        time_steps;
        meta = "current_ub",
    )
    constraint_current_lb = add_constraints_container!(
        container,
        T(),
        U,
        names,
        time_steps;
        meta = "current_lb",
    )
    constraint_to_power_ub = add_constraints_container!(
        container,
        T(),
        U,
        names,
        time_steps;
        meta = "to_power_ub",
    )
    constraint_to_power_lb = add_constraints_container!(
        container,
        T(),
        U,
        names,
        time_steps;
        meta = "to_power_lb",
    )
    for d in devices
        name = PSY.get_name(d)
        I_max = PSY.get_max_dc_current(d)
        I_neg = -I_max
        P_min_from, P_max_from = PSY.get_active_power_limits_from(d)
        P_min_to, P_max_to = PSY.get_active_power_limits_to(d)
        for t in time_steps
            constraint_from_power_ub[name, t] = JuMP.@constraint(
                JuMPmodel,
                from_power_var[name, t] <= P_max_from * direction_var[name, t]
            )
            constraint_from_power_lb[name, t] = JuMP.@constraint(
                JuMPmodel,
                from_power_var[name, t] >= P_min_from * (1.0 - direction_var[name, t])
            )
            constraint_current_ub[name, t] = JuMP.@constraint(
                JuMPmodel,
                current_var[name, t] <= I_max * direction_var[name, t]
            )
            constraint_current_lb[name, t] = JuMP.@constraint(
                JuMPmodel,
                current_var[name, t] >= I_neg * (1.0 - direction_var[name, t])
            )
            constraint_to_power_ub[name, t] = JuMP.@constraint(
                JuMPmodel,
                to_power_var[name, t] <= P_max_to * (1.0 - direction_var[name, t])
            )
            constraint_to_power_lb[name, t] = JuMP.@constraint(
                JuMPmodel,
                to_power_var[name, t] >= P_min_to * direction_var[name, t]
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    devices::IS.FlattenIteratorWrapper{U},
    ::DeviceModel{U, V},
    ::NetworkModel{<:AbstractPTDFModel},
) where {
    T <: ConverterMcCormickEnvelopes,
    U <: PSY.TwoTerminalHVDCDetailedLine,
    V <: HVDCTwoTerminalPhysicalLoss,
}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    JuMPmodel = get_jump_model(container)
    # power vars #
    from_power_var = get_variable(container, HVDCActivePowerReceivedFromVariable(), U)
    to_power_var = get_variable(container, HVDCActivePowerReceivedToVariable(), U)
    # current vars #
    current_var = get_variable(container, ConverterCurrent(), U) # From direction
    # voltage vars #
    from_voltage_var = get_variable(container, DCVoltageFrom(), U)
    to_voltage_var = get_variable(container, DCVoltageTo(), U)

    from_constraint1_under =
        add_constraints_container!(
            container,
            ConverterMcCormickEnvelopes(),
            U,
            names,
            time_steps;
            meta = "from_under_1",
        )
    from_constraint2_under =
        add_constraints_container!(
            container,
            ConverterMcCormickEnvelopes(),
            U,
            names,
            time_steps;
            meta = "from_under_2",
        )
    from_constraint1_over =
        add_constraints_container!(
            container,
            ConverterMcCormickEnvelopes(),
            U,
            names,
            time_steps;
            meta = "from_over_1",
        )
    from_constraint2_over =
        add_constraints_container!(
            container,
            ConverterMcCormickEnvelopes(),
            U,
            names,
            time_steps;
            meta = "from_over_2",
        )
    to_constraint1_under =
        add_constraints_container!(
            container,
            ConverterMcCormickEnvelopes(),
            U,
            names,
            time_steps;
            meta = "to_under_1",
        )
    to_constraint2_under =
        add_constraints_container!(
            container,
            ConverterMcCormickEnvelopes(),
            U,
            names,
            time_steps;
            meta = "to_under_2",
        )
    to_constraint1_over =
        add_constraints_container!(
            container,
            ConverterMcCormickEnvelopes(),
            U,
            names,
            time_steps;
            meta = "to_over_1",
        )
    to_constraint2_over =
        add_constraints_container!(
            container,
            ConverterMcCormickEnvelopes(),
            U,
            names,
            time_steps;
            meta = "to_over_2",
        )

    for d in devices
        name = PSY.get_name(d)
        V_min, V_max = PSY.get_voltage_limits(d)
        I_max = PSY.get_max_dc_current(d)
        I_neg = -I_max
        for t in time_steps
            from_constraint1_under[name, t] = JuMP.@constraint(
                JuMPmodel,
                from_power_var[name, t] >=
                V_min * current_var[name, t] + from_voltage_var[name, t] * I_neg -
                I_neg * V_min
            )
            from_constraint2_under[name, t] = JuMP.@constraint(
                JuMPmodel,
                from_power_var[name, t] >=
                V_max * current_var[name, t] + from_voltage_var[name, t] * I_max -
                I_max * V_max
            )
            from_constraint1_over[name, t] = JuMP.@constraint(
                JuMPmodel,
                from_power_var[name, t] <=
                V_max * current_var[name, t] + from_voltage_var[name, t] * I_neg -
                I_neg * V_max
            )
            from_constraint2_over[name, t] = JuMP.@constraint(
                JuMPmodel,
                from_power_var[name, t] <=
                V_min * current_var[name, t] + from_voltage_var[name, t] * I_max -
                I_max * V_min
            )
            to_constraint1_under[name, t] = JuMP.@constraint(
                JuMPmodel,
                to_power_var[name, t] >=
                V_min * (-current_var[name, t]) + to_voltage_var[name, t] * I_neg -
                I_neg * V_min
            )
            to_constraint2_under[name, t] = JuMP.@constraint(
                JuMPmodel,
                to_power_var[name, t] >=
                V_max * (-current_var[name, t]) + to_voltage_var[name, t] * I_max -
                I_max * V_max
            )
            to_constraint1_over[name, t] = JuMP.@constraint(
                JuMPmodel,
                to_power_var[name, t] <=
                V_max * (-current_var[name, t]) + to_voltage_var[name, t] * I_neg -
                I_neg * V_max
            )
            to_constraint2_over[name, t] = JuMP.@constraint(
                JuMPmodel,
                to_power_var[name, t] <=
                V_min * (-current_var[name, t]) + to_voltage_var[name, t] * I_max -
                I_max * V_min
            )
        end
    end
    return
end
