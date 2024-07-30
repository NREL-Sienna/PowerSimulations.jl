#! format: off
### Binaries ###
# Converter
get_variable_binary(::ActivePowerVariable, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = false
get_variable_binary(::ConverterPowerDirection, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = true
get_variable_binary(::ConverterCurrent, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = false
get_variable_binary(::ConverterPositiveCurrent, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = false
get_variable_binary(::ConverterNegativeCurrent, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = false
get_variable_binary(::ConverterBinaryAbsoluteValueCurrent, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = true
get_variable_binary(::SquaredConverterCurrent, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = false
get_variable_binary(::InterpolationSquaredCurrentVariable, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = false
get_variable_binary(::InterpolationBinarySquaredCurrentVariable, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = true
get_variable_binary(::SquaredDCVoltage, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = false
get_variable_binary(::InterpolationSquaredVoltageVariable, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = false
get_variable_binary(::InterpolationBinarySquaredVoltageVariable, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = true
get_variable_binary(::AuxBilinearConverterVariable, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = false
get_variable_binary(::AuxBilinearSquaredConverterVariable, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = false
get_variable_binary(::InterpolationSquaredBilinearVariable, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = false
get_variable_binary(::InterpolationBinarySquaredBilinearVariable, ::Type{PSY.InterconnectingConverter}, ::AbstractConverterFormulation) = true
# DCBuses
get_variable_binary(::DCVoltage, ::Type{PSY.DCBus}, ::AbstractBranchFormulation) = false

### Warm Start ###
get_variable_warm_start_value(::ActivePowerVariable, d::PSY.InterconnectingConverter, ::AbstractConverterFormulation) = PSY.get_active_power(d)

### Lower Bounds ###
get_variable_lower_bound(::ActivePowerVariable, d::PSY.InterconnectingConverter, ::AbstractConverterFormulation) = PSY.get_active_power_limits(d).min

### Upper Bounds ###
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
get_variable_warm_start_value(::FlowActivePowerVariable, d::PSY.TModelHVDCLine, ::AbstractBranchFormulation) = PSY.get_active_power_flow(d)
get_variable_lower_bound(::FlowActivePowerVariable, d::PSY.TModelHVDCLine, ::AbstractBranchFormulation) = _get_flow_bounds(d)[1]
get_variable_upper_bound(::FlowActivePowerVariable, d::PSY.TModelHVDCLine, ::AbstractBranchFormulation) = _get_flow_bounds(d)[2]
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
    model::DeviceModel{PSY.TModelHVDCLine, D},
) where {D <: Union{LossLessLine, DCLossyLine}}
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
    V <: PSY.TModelHVDCLine,
    W <: LossLessLine,
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
    ::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    ::IS.FlattenIteratorWrapper{V},
    devices::DeviceModel{V, W},
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
    for d in devices, t in get_time_steps(container)
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

##########################
###### Constraints #######
##########################

function add_constraints!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{ConverterCurrentBalanceConstraint},
    devices::IS.FlattenIteratorWrapper{U},
    model::DeviceModel{U, V},
    network_model::NetworkModel{X},
) where {
    U <: PSY.InterconnectingConverter,
    V <: QuadraticLossConverter,
    X <: PM.AbstractActivePowerModel,
}
    time_steps = get_time_steps(container)
    varcurrent = get_variable(container, ConverterCurrent(), U)
    var_dcvoltage = get_variable(container, DCVoltage(), PSY.DCBus)
    ipc_names = axes(varcurrent, 1)
    constraint =
        add_constraints_container!(container, ConverterCurrentBalanceConstraint(), U, ipc_names, time_steps)

    for device in devices
        name = PSY.get_name(device)
        dc_bus = PSY.get_dc_bus(device)
        dc_bus_name = PSY.get_name(dc_bus)
        from_branches = PSY.get_components(x-> x.available && (x.arc.from == dc_bus), PSY.DCBranch, sys)
        to_branches = PSY.get_components(x-> x.available && (x.arc.to == dc_bus), PSY.DCBranch, sys)
        for t in time_steps
            total_current_flow = JuMP.AffExpr()
            for br in from_branches
                r = PSY.get_r(br)
                to_bus_name = PSY.get_name(br.arc.to)
                if r <= 0.0
                    error("Series resistance of DCBranch $(PSY.get_name(br)) is non-positive. Consider updating your data")
                end
                total_current_flow += (1.0 / r) * (var_dcvoltage[dc_bus_name, t] - var_dcvoltage[to_bus_name, t])
            end
            for br in to_branches
                r = PSY.get_r(br)
                from_bus_name = PSY.get_name(br.arc.from)
                if r <= 0.0
                    error("Series resistance of DCBranch $(PSY.get_name(br)) is non-positive. Consider updating your data")
                end
                total_current_flow += (1.0 / r) * (var_dcvoltage[dc_bus_name, t] - var_dcvoltage[from_bus_name, t])
            end
            constraint[name, t] = JuMP.@constraint(
                get_jump_model(container),
                varcurrent[name, t] == total_current_flow
            )
        end        
    end
    return
end

function objective_function!(
    ::OptimizationContainer,
    ::IS.FlattenIteratorWrapper{PSY.InterconnectingConverter},
    ::DeviceModel{PSY.InterconnectingConverter, T},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: Union{LossLessConverter, QuadraticLossConverter}}
    return
end
