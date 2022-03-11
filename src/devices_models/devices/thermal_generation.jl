#! format: off

requires_initialization(::AbstractThermalFormulation) = false
requires_initialization(::AbstractThermalUnitCommitment) = true
requires_initialization(::ThermalStandardDispatch) = true
requires_initialization(::ThermalBasicCompactUnitCommitment) = false
requires_initialization(::ThermalBasicUnitCommitment) = false

get_variable_multiplier(_, ::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = 1.0
get_variable_multiplier(::OnVariable, d::PSY.ThermalGen, ::Union{AbstractCompactUnitCommitment, ThermalCompactDispatch}) = PSY.get_active_power_limits(d).min
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.ThermalGen}, ::Type{<:PSY.Reserve{PSY.ReserveUp}}) = ActivePowerRangeExpressionUB
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.ThermalGen}, ::Type{<:PSY.Reserve{PSY.ReserveDown}}) = ActivePowerRangeExpressionLB

############## ActivePowerVariable, ThermalGen ####################
get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = false
get_variable_warm_start_value(::ActivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power(d)
get_variable_lower_bound(::ActivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power_limits(d).min
get_variable_lower_bound(::ActivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalUnitCommitment) = 0.0
get_variable_upper_bound(::ActivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power_limits(d).max

############## PowerAboveMinimumVariable, ThermalGen ####################
get_variable_binary(::PowerAboveMinimumVariable, ::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = false
get_variable_warm_start_value(::PowerAboveMinimumVariable, d::PSY.ThermalGen, ::AbstractCompactUnitCommitment) = max(0.0, PSY.get_active_power(d) - PSY.get_active_power_limits(d).min)
get_variable_lower_bound(::PowerAboveMinimumVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = 0.0
get_variable_upper_bound(::PowerAboveMinimumVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power_limits(d).max - PSY.get_active_power_limits(d).min

############## ReactivePowerVariable, ThermalGen ####################
get_variable_binary(::ReactivePowerVariable, ::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = false
get_variable_warm_start_value(::ReactivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_reactive_power(d)
get_variable_lower_bound(::ReactivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power_limits(d).min
get_variable_upper_bound(::ReactivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power_limits(d).max

############## OnVariable, ThermalGen ####################
get_variable_binary(::OnVariable, ::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = true
get_variable_warm_start_value(::OnVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_status(d) ? 1.0 : 0.0

############## StopVariable, ThermalGen ####################
get_variable_binary(::StopVariable, ::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = true
get_variable_lower_bound(::StopVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = 0.0
get_variable_upper_bound(::StopVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = 1.0

############## StartVariable, ThermalGen ####################
get_variable_binary(::StartVariable, d::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = true
get_variable_lower_bound(::StartVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = 0.0
get_variable_upper_bound(::StartVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = 1.0

############## ColdStartVariable, WarmStartVariable, HotStartVariable ############
get_variable_binary(::Union{ColdStartVariable, WarmStartVariable, HotStartVariable}, ::Type{PSY.ThermalMultiStart}, ::AbstractThermalFormulation) = true

########################### Parameter related set functions ################################
get_parameter_multiplier(::VariableValueParameter, d::PSY.ThermalGen, ::AbstractThermalFormulation) = 1.0
get_initial_parameter_value(::VariableValueParameter, d::PSY.ThermalGen, ::AbstractThermalFormulation) = 1.0
get_expression_multiplier(::OnStatusParameter, ::ActivePowerRangeExpressionUB, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power_limits(d).max
get_expression_multiplier(::OnStatusParameter, ::ActivePowerRangeExpressionLB, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power_limits(d).min
get_expression_multiplier(::OnStatusParameter, ::ActivePowerRangeExpressionUB, d::PSY.ThermalGen, ::AbstractCompactUnitCommitment) = PSY.get_active_power_limits(d).max - PSY.get_active_power_limits(d).min
get_expression_multiplier(::OnStatusParameter, ::ActivePowerRangeExpressionLB, d::PSY.ThermalGen, ::AbstractCompactUnitCommitment) = 0.0
get_expression_multiplier(::OnStatusParameter, ::ActivePowerRangeExpressionUB, d::PSY.ThermalGen, ::ThermalCompactDispatch) = PSY.get_active_power_limits(d).max - PSY.get_active_power_limits(d).min
get_expression_multiplier(::OnStatusParameter, ::ActivePowerRangeExpressionLB, d::PSY.ThermalGen, ::ThermalCompactDispatch) = 0.0
get_expression_multiplier(::OnStatusParameter, ::ActivePowerBalance, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power_limits(d).min

#################### Initial Conditions for models ###############
initial_condition_default(::DeviceStatus, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_status(d)
initial_condition_variable(::DeviceStatus, d::PSY.ThermalGen, ::AbstractThermalFormulation) = OnVariable()
initial_condition_default(::DevicePower, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power(d)
initial_condition_variable(::DevicePower, d::PSY.ThermalGen, ::AbstractThermalFormulation) = ActivePowerVariable()
initial_condition_default(::DeviceAboveMinPower, d::PSY.ThermalGen, ::AbstractThermalFormulation) = max(0.0, PSY.get_active_power(d) - PSY.get_active_power_limits(d).min)
initial_condition_variable(::DeviceAboveMinPower, d::PSY.ThermalGen, ::AbstractCompactUnitCommitment) = PowerAboveMinimumVariable()
initial_condition_variable(::DeviceAboveMinPower, d::PSY.ThermalGen, ::ThermalCompactDispatch) = PowerAboveMinimumVariable()
initial_condition_default(::InitialTimeDurationOn, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_status(d) ? PSY.get_time_at_status(d) : 0.0
initial_condition_variable(::InitialTimeDurationOn, d::PSY.ThermalGen, ::AbstractThermalFormulation) = OnVariable()
initial_condition_default(::InitialTimeDurationOff, d::PSY.ThermalGen, ::AbstractThermalFormulation) = !PSY.get_status(d) ? PSY.get_time_at_status(d) : 0.0
initial_condition_variable(::InitialTimeDurationOff, d::PSY.ThermalGen, ::AbstractThermalFormulation) = OnVariable()

########################Objective Function##################################################
proportional_cost(cost::PSY.OperationalCost, ::OnVariable, ::PSY.ThermalGen, ::AbstractThermalFormulation)=PSY.get_fixed(cost)
proportional_cost(cost::PSY.OperationalCost, S::OnVariable, T::PSY.ThermalGen, U::AbstractCompactUnitCommitment) = no_load_cost(cost, S, T, U)  + PSY.get_fixed(cost)
proportional_cost(cost::PSY.MarketBidCost, ::OnVariable, ::PSY.ThermalGen, ::AbstractThermalFormulation)=PSY.get_no_load(cost)
proportional_cost(cost::PSY.MarketBidCost, ::OnVariable, ::PSY.ThermalGen, ::AbstractCompactUnitCommitment)=PSY.get_no_load(cost)
proportional_cost(cost::PSY.MultiStartCost, ::OnVariable, ::PSY.ThermalMultiStart, ::ThermalMultiStartUnitCommitment)=PSY.get_fixed(cost) + PSY.get_no_load(cost)

has_multistart_variables(::PSY.ThermalGen, ::AbstractThermalFormulation)=false
has_multistart_variables(::PSY.ThermalMultiStart, ::ThermalMultiStartUnitCommitment)=true

objective_function_multiplier(::VariableType, ::AbstractThermalFormulation)=OBJECTIVE_FUNCTION_POSITIVE

shut_down_cost(cost::PSY.OperationalCost, ::PSY.ThermalGen, ::AbstractThermalFormulation)=PSY.get_shut_down(cost)

sos_status(::PSY.ThermalGen, ::AbstractThermalDispatchFormulation)=SOSStatusVariable.NO_VARIABLE
sos_status(::PSY.ThermalGen, ::AbstractThermalUnitCommitment)=SOSStatusVariable.VARIABLE
sos_status(::PSY.ThermalMultiStart, ::AbstractStandardUnitCommitment)=SOSStatusVariable.VARIABLE
sos_status(::PSY.ThermalMultiStart, ::ThermalMultiStartUnitCommitment)=SOSStatusVariable.VARIABLE

start_up_cost(cost::PSY.OperationalCost, ::PSY.ThermalGen, ::AbstractThermalFormulation)=PSY.get_start_up(cost)
start_up_cost(cost::PSY.MultiStartCost, ::PSY.ThermalGen, ::AbstractThermalFormulation)=maximum(PSY.get_start_up(cost))
start_up_cost(cost::PSY.MultiStartCost, ::PSY.ThermalMultiStart, ::ThermalMultiStartUnitCommitment)=PSY.get_start_up(cost)
start_up_cost(cost::PSY.MarketBidCost, ::PSY.ThermalGen, ::AbstractThermalFormulation)=maximum(PSY.get_start_up(cost))
start_up_cost(cost::PSY.MarketBidCost, ::PSY.ThermalMultiStart, ::ThermalMultiStartUnitCommitment)=PSY.get_start_up(cost)
# If the formulation used ignores start up costs, the model ignores that data.
start_up_cost(cost::PSY.MarketBidCost, ::PSY.ThermalMultiStart, ::AbstractThermalFormulation)=maximum(PSY.get_start_up(cost))

uses_compact_power(::PSY.ThermalGen, ::AbstractThermalFormulation)=false
uses_compact_power(::PSY.ThermalGen, ::AbstractCompactUnitCommitment )=true
uses_compact_power(::PSY.ThermalGen, ::ThermalCompactDispatch)=true

variable_cost(cost::PSY.OperationalCost, ::ActivePowerVariable, ::PSY.ThermalGen, ::AbstractThermalFormulation)=PSY.get_variable(cost)
variable_cost(cost::PSY.OperationalCost, ::PowerAboveMinimumVariable, ::PSY.ThermalGen, ::AbstractThermalFormulation)=PSY.get_variable(cost)

no_load_cost(cost::PSY.MultiStartCost, ::OnVariable, ::PSY.ThermalMultiStart, U::AbstractThermalFormulation) = PSY.get_no_load(cost)
function no_load_cost(cost::Union{PSY.ThreePartCost, PSY.TwoPartCost}, S::OnVariable, T::PSY.ThermalGen, U::AbstractThermalFormulation)
    return no_load_cost(PSY.get_variable(cost), S, T, U)
end
no_load_cost(cost::PSY.VariableCost{Vector{NTuple{2, Float64}}}, ::OnVariable, ::PSY.ThermalGen, ::AbstractThermalFormulation) = first(PSY.get_cost(cost))[1]
no_load_cost(cost::PSY.VariableCost{Float64}, ::OnVariable, ::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_cost(cost) * PSY.get_active_power_limits(d).min * PSY.get_base_power(d)
function no_load_cost(cost::PSY.VariableCost{Tuple{Float64, Float64}}, ::OnVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation)
    return (PSY.get_cost(cost)[1] * (PSY.get_active_power_limits(d).min)^2 + PSY.get_cost(cost)[2] * PSY.get_active_power_limits(d).min)* PSY.get_base_power(d)
end
    #! format: on
function get_initial_conditions_device_model(
    model::OperationModel,
    ::DeviceModel{T, D},
) where {T <: PSY.ThermalGen, D <: AbstractThermalDispatchFormulation}
    if supports_milp(get_optimization_container(model))
        return DeviceModel(T, ThermalBasicUnitCommitment)
    else
        throw(
            IS.ConflictingInputsError(
                "Model requires initialization but provided solver doesn't support mixed integer problems.",
            ),
        )
    end
end

function get_initial_conditions_device_model(
    ::OperationModel,
    ::DeviceModel{T, D},
) where {T <: PSY.ThermalGen, D <: ThermalDispatchNoMin}
    return DeviceModel(T, ThermalDispatchNoMin)
end

function get_initial_conditions_device_model(
    ::OperationModel,
    ::DeviceModel{T, D},
) where {T <: PSY.ThermalGen, D <: AbstractThermalUnitCommitment}
    return DeviceModel(T, ThermalBasicUnitCommitment)
end

function get_initial_conditions_device_model(
    ::OperationModel,
    ::DeviceModel{T, D},
) where {T <: PSY.ThermalGen, D <: AbstractCompactUnitCommitment}
    return DeviceModel(T, ThermalBasicCompactUnitCommitment)
end

function get_default_time_series_names(
    ::Type{U},
    ::Type{V},
) where {U <: PSY.ThermalGen, V <: Union{FixedOutput, AbstractThermalFormulation}}
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

function get_default_attributes(
    ::Type{U},
    ::Type{V},
) where {U <: PSY.ThermalGen, V <: Union{FixedOutput, AbstractThermalFormulation}}
    return Dict{String, Any}()
end

######## THERMAL GENERATION CONSTRAINTS ############

# active power limits of generators when there are no CommitmentVariables
"""
Min and max active power limits of generators for thermal dispatch formulations
"""
function get_min_max_limits(
    device,
    ::Type{ActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractThermalDispatchFormulation},
)
    return PSY.get_active_power_limits(device)
end

# active power limits of generators when there are CommitmentVariables
"""
Min and max active power limits of generators for thermal unit commitment formulations
"""
function get_min_max_limits(
    device,
    ::Type{ActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractThermalUnitCommitment},
)
    return PSY.get_active_power_limits(device)
end

"""
Range constraints for thermal compact dispatch
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:PowerVariableLimitsConstraint},
    U::Type{<:Union{PowerAboveMinimumVariable, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.ThermalGen, W <: ThermalCompactDispatch}
    if !has_semicontinuous_feedforward(model, PowerAboveMinimumVariable)
        add_range_constraints!(container, T, U, devices, model, X)
    end
    return
end

"""
Min and max active power limits of generators for thermal dispatch compact formulations
"""
function get_min_max_limits(
    device,
    ::Type{ActivePowerVariableLimitsConstraint},
    ::Type{ThermalCompactDispatch},
)
    return (
        min=0.0,
        max=PSY.get_active_power_limits(device).max -
            PSY.get_active_power_limits(device).min,
    )
end

"""
Min and max active power limits of generators for thermal dispatch no minimum formulations
"""
function get_min_max_limits(
    device,
    ::Type{ActivePowerVariableLimitsConstraint},
    ::Type{ThermalDispatchNoMin},
)
    return (min=0.0, max=PSY.get_active_power_limits(device).max)
end

"""
Semicontinuous range constraints for thermal dispatch formulations
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:PowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.ThermalGen, W <: AbstractThermalDispatchFormulation}
    if !has_semicontinuous_feedforward(model, U)
        add_range_constraints!(container, T, U, devices, model, X)
    end
    return
end

"""
Min and max active power limits for multi-start unit commitment formulations
"""
function get_min_max_limits(
    device,
    ::Type{ActivePowerVariableLimitsConstraint},
    ::Type{<:ThermalMultiStartUnitCommitment},
) #  -> Union{Nothing, NamedTuple{(:startup, :shutdown), Tuple{Float64, Float64}}}
    return (
        min=0.0,
        max=PSY.get_active_power_limits(device).max -
            PSY.get_active_power_limits(device).min,
    )
end

"""
Semicontinuous range constraints for unit commitment formulations
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:PowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.ThermalGen, W <: AbstractThermalUnitCommitment}
    add_semicontinuous_range_constraints!(container, T, U, devices, model, X)
    return
end

"""
Startup and shutdown active power limits for Compact Unit Commitment
"""
function get_startup_shutdown_limits(
    device,
    ::Type{ActivePowerVariableLimitsConstraint},
    ::Type{<:ThermalMultiStartUnitCommitment},
)
    return PSY.get_power_trajectory(device)
end

"""
Min and Max active power limits for Compact Unit Commitment
"""
function get_min_max_limits(
    device,
    ::Type{ActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractCompactUnitCommitment},
) #  -> Union{Nothing, NamedTuple{(:startup, :shutdown), Tuple{Float64, Float64}}}
    return (
        min=0,
        max=PSY.get_active_power_limits(device).max -
            PSY.get_active_power_limits(device).min,
    )
end

"""
Startup shutdown limits for Compact Unit Commitment
"""
function get_startup_shutdown_limits(
    device,
    ::Type{ActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractCompactUnitCommitment},
)
    return (
        startup=PSY.get_active_power_limits(device).max,
        shutdown=PSY.get_active_power_limits(device).max,
    )
end

function _get_data_for_range_ic(
    initial_conditions_power::Vector{<:InitialCondition},
    initial_conditions_status::Vector{<:InitialCondition},
)
    lenght_devices_power = length(initial_conditions_power)
    lenght_devices_status = length(initial_conditions_status)
    IS.@assert_op lenght_devices_power == lenght_devices_status
    ini_conds = Matrix{InitialCondition}(undef, lenght_devices_power, 2)
    idx = 0
    for (ix, ic) in enumerate(initial_conditions_power)
        g = get_component(ic)
        IS.@assert_op g == get_component(initial_conditions_status[ix])
        idx += 1
        ini_conds[idx, 1] = ic
        ini_conds[idx, 2] = initial_conditions_status[ix]
    end
    return ini_conds
end

"""
This function adds range constraint for the first time period. Constraint (10) from PGLIB formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:ActivePowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.ThermalMultiStart, W <: ThermalMultiStartUnitCommitment}
    time_steps = get_time_steps(container)
    constraint_type = T()
    variable_type = U()
    component_type = V
    varp = get_variable(container, variable_type, component_type)
    varstatus = get_variable(container, OnVariable(), component_type)
    varon = get_variable(container, StartVariable(), component_type)
    varoff = get_variable(container, StopVariable(), component_type)

    names = [PSY.get_name(x) for x in devices]
    con_on = add_constraints_container!(
        container,
        constraint_type,
        component_type,
        names,
        time_steps,
        meta="on",
    )
    con_off = add_constraints_container!(
        container,
        constraint_type,
        component_type,
        names,
        time_steps[1:(end - 1)],
        meta="off",
    )
    con_lb = add_constraints_container!(
        container,
        constraint_type,
        component_type,
        names,
        time_steps,
        meta="lb",
    )

    for device in devices, t in time_steps
        name = PSY.get_name(device)
        limits = get_min_max_limits(device, T, W) # depends on constraint type and formulation type
        startup_shutdown_limits = get_startup_shutdown_limits(device, T, W)
        if JuMP.has_lower_bound(varp[name, t])
            JuMP.set_lower_bound(varp[name, t], 0.0)
        end

        con_on[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            varp[name, t] <=
            (limits.max - limits.min) * varstatus[name, t] -
            max(limits.max - startup_shutdown_limits.startup, 0.0) * varon[name, t]
        )

        con_lb[name, t] = JuMP.@constraint(container.JuMPmodel, varp[name, t] >= 0.0)

        if t == length(time_steps)
            continue
        else
            con_off[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                varp[name, t] <=
                (limits.max - limits.min) * varstatus[name, t] -
                max(limits.max - startup_shutdown_limits.shutdown, 0.0) *
                varoff[name, t + 1]
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:ActivePowerVariableLimitsConstraint},
    U::Type{ActivePowerRangeExpressionLB},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.ThermalMultiStart, W <: ThermalMultiStartUnitCommitment}
    time_steps = get_time_steps(container)
    constraint_type = T()
    expression_type = U()
    component_type = V
    expression_products = get_expression(container, expression_type, component_type)
    varp = get_variable(container, PowerAboveMinimumVariable(), component_type)

    names = [PSY.get_name(x) for x in devices]
    con_lb = add_constraints_container!(
        container,
        constraint_type,
        component_type,
        names,
        time_steps,
        meta="lb",
    )

    for device in devices, t in time_steps
        name = PSY.get_name(device)
        if JuMP.has_lower_bound(varp[name, t])
            JuMP.set_lower_bound(varp[name, t], 0.0)
        end
        con_lb[name, t] =
            JuMP.@constraint(container.JuMPmodel, expression_products[name, t] >= 0)
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:ActivePowerVariableLimitsConstraint},
    U::Type{ActivePowerRangeExpressionUB},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.ThermalMultiStart, W <: ThermalMultiStartUnitCommitment}
    time_steps = get_time_steps(container)
    constraint_type = T()
    expression_type = U()
    component_type = V
    expression_products = get_expression(container, expression_type, component_type)
    varstatus = get_variable(container, OnVariable(), component_type)
    varon = get_variable(container, StartVariable(), component_type)
    varoff = get_variable(container, StopVariable(), component_type)
    varp = get_variable(container, PowerAboveMinimumVariable(), component_type)

    names = [PSY.get_name(x) for x in devices]
    con_on = add_constraints_container!(
        container,
        constraint_type,
        component_type,
        names,
        time_steps,
        meta="ubon",
    )
    con_off = add_constraints_container!(
        container,
        constraint_type,
        component_type,
        names,
        time_steps[1:(end - 1)],
        meta="uboff",
    )

    for device in devices, t in time_steps
        name = PSY.get_name(device)
        limits = get_min_max_limits(device, T, W) # depends on constraint type and formulation type
        startup_shutdown_limits = get_startup_shutdown_limits(device, T, W)
        if JuMP.has_lower_bound(varp[name, t])
            JuMP.set_lower_bound(varp[name, t], 0.0)
        end
        con_on[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_products[name, t] <=
            (limits.max - limits.min) * varstatus[name, t] -
            max(limits.max - startup_shutdown_limits.startup, 0) * varon[name, t]
        )
        if t == length(time_steps)
            continue
        else
            con_off[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                expression_products[name, t] <=
                (limits.max - limits.min) * varstatus[name, t] -
                max(limits.max - startup_shutdown_limits.shutdown, 0) * varoff[name, t + 1]
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{ActiveRangeICConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, S},
    W::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ThermalGen, S <: AbstractCompactUnitCommitment}
    initial_conditions_power = get_initial_condition(container, DeviceAboveMinPower(), T)
    initial_conditions_status = get_initial_condition(container, DeviceStatus(), T)
    ini_conds = _get_data_for_range_ic(initial_conditions_power, initial_conditions_status)

    if !isempty(ini_conds)
        varstop = get_variable(container, StopVariable(), T)
        set_name = [PSY.get_name(d) for d in devices]
        con = add_constraints_container!(container, ActiveRangeICConstraint(), T, set_name)

        for (ix, ic) in enumerate(ini_conds[:, 1])
            name = get_component_name(ic)
            device = get_component(ic)
            limits = PSY.get_active_power_limits(device)
            lag_ramp_limits = PSY.get_power_trajectory(device)
            val = max(limits.max - lag_ramp_limits.shutdown, 0)
            con[name] = JuMP.@constraint(
                container.JuMPmodel,
                val * varstop[name, 1] <=
                ini_conds[ix, 2].value * (limits.max - limits.min) - get_value(ic)
            )
        end
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end
    return
end

"""
Reactive power limits of generators for all dispatch formulations
"""
function get_min_max_limits(
    device,
    ::Type{ReactivePowerVariableLimitsConstraint},
    ::Type{<:AbstractThermalDispatchFormulation},
)
    return PSY.get_reactive_power_limits(device)
end

"""
Reactive power limits of generators when there CommitmentVariables
"""
function get_min_max_limits(
    device,
    ::Type{ReactivePowerVariableLimitsConstraint},
    ::Type{<:AbstractThermalUnitCommitment},
)
    return PSY.get_reactive_power_limits(device)
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{CommitmentConstraint},
    devices::IS.FlattenIteratorWrapper{U},
    model::DeviceModel{U, V},
    W::Type{<:PM.AbstractPowerModel},
) where {U <: PSY.ThermalGen, V <: AbstractThermalUnitCommitment}
    time_steps = get_time_steps(container)
    varstart = get_variable(container, StartVariable(), U)
    varstop = get_variable(container, StopVariable(), U)
    varon = get_variable(container, OnVariable(), U)
    names = axes(varstart, 1)
    initial_conditions = get_initial_condition(container, DeviceStatus(), U)
    constraint =
        add_constraints_container!(container, CommitmentConstraint(), U, names, time_steps)
    aux_constraint = add_constraints_container!(
        container,
        CommitmentConstraint(),
        U,
        names,
        time_steps,
        meta="aux",
    )

    for ic in initial_conditions
        name = PSY.get_name(get_component(ic))
        constraint[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            varon[name, 1] == get_value(ic) + varstart[name, 1] - varstop[name, 1]
        )
        aux_constraint[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            varstart[name, 1] + varstop[name, 1] <= 1.0
        )
    end

    for t in time_steps[2:end], ic in initial_conditions
        name = get_component_name(ic)
        constraint[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            varon[name, t] == varon[name, t - 1] + varstart[name, t] - varstop[name, t]
        )
        aux_constraint[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            varstart[name, t] + varstop[name, t] <= 1.0
        )
    end
    return
end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    formulation::AbstractThermalUnitCommitment,
) where {T <: PSY.ThermalGen}
    add_initial_condition!(container, devices, formulation, DeviceStatus())
    add_initial_condition!(container, devices, formulation, DevicePower())
    add_initial_condition!(container, devices, formulation, InitialTimeDurationOn())
    add_initial_condition!(container, devices, formulation, InitialTimeDurationOff())

    return
end

function initial_conditions!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    formulation::AbstractCompactUnitCommitment,
) where {T <: PSY.ThermalGen}
    add_initial_condition!(container, devices, formulation, DeviceStatus())
    add_initial_condition!(container, devices, formulation, DeviceAboveMinPower())
    add_initial_condition!(container, devices, formulation, InitialTimeDurationOn())
    add_initial_condition!(container, devices, formulation, InitialTimeDurationOff())

    return
end

function initial_conditions!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    formulation::Union{ThermalBasicUnitCommitment, ThermalBasicCompactUnitCommitment},
) where {T <: PSY.ThermalGen}
    add_initial_condition!(container, devices, formulation, DeviceStatus())
    return
end

function initial_conditions!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    formulation::AbstractThermalDispatchFormulation,
) where {T <: PSY.ThermalGen}
    add_initial_condition!(container, devices, formulation, DevicePower())
    return
end

function initial_conditions!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    formulation::ThermalCompactDispatch,
) where {T <: PSY.ThermalGen}
    add_initial_condition!(container, devices, formulation, DeviceAboveMinPower())
    return
end
############################ Auxiliary Variables Calculation ################################
function calculate_aux_variable_value!(
    container::OptimizationContainer,
    ::AuxVarKey{TimeDurationOn, T},
    ::PSY.System,
) where {T <: PSY.ThermalGen}
    on_variable_results = get_variable(container, OnVariable(), T)
    aux_variable_container = get_aux_variable(container, TimeDurationOn(), T)
    ini_cond = get_initial_condition(container, InitialTimeDurationOn(), T)

    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    minutes_per_period = Dates.value(Dates.Minute(resolution))

    for ix in eachindex(JuMP.axes(aux_variable_container)[1])
        IS.@assert_op JuMP.axes(aux_variable_container)[1][ix] ==
                      JuMP.axes(on_variable_results)[1][ix]
        IS.@assert_op JuMP.axes(aux_variable_container)[1][ix] ==
                      get_component_name(ini_cond[ix])
        on_var = jump_value.(on_variable_results.data[ix, :])
        ini_cond_value = get_condition(ini_cond[ix])
        aux_variable_container.data[ix, :] .= ini_cond_value
        sum_on_var = sum(on_var)
        if sum_on_var == time_steps[end] # Unit was always on
            aux_variable_container.data[ix, :] += time_steps
        elseif sum_on_var == 0.0 # Unit was always off
            aux_variable_container.data[ix, :] .= 0.0
        else
            previous_condition = ini_cond_value
            for (t, v) in enumerate(on_var)
                if v < 0.99 # Unit turn off
                    time_value = 0.0
                elseif isapprox(v, 1.0; atol=ABSOLUTE_TOLERANCE) # Unit is on
                    time_value = previous_condition + 1.0
                else
                    error("Binary condition returned $v")
                end
                previous_condition = aux_variable_container.data[ix, t] = time_value
            end
        end
    end

    return
end

function calculate_aux_variable_value!(
    container::OptimizationContainer,
    ::AuxVarKey{TimeDurationOff, T},
    ::PSY.System,
) where {T <: PSY.ThermalGen}
    on_variable_results = get_variable(container, OnVariable(), T)
    aux_variable_container = get_aux_variable(container, TimeDurationOff(), T)
    ini_cond = get_initial_condition(container, InitialTimeDurationOff(), T)

    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    minutes_per_period = Dates.value(Dates.Minute(resolution))

    for ix in eachindex(JuMP.axes(aux_variable_container)[1])
        IS.@assert_op JuMP.axes(aux_variable_container)[1][ix] ==
                      JuMP.axes(on_variable_results)[1][ix]
        IS.@assert_op JuMP.axes(aux_variable_container)[1][ix] ==
                      get_component_name(ini_cond[ix])
        on_var = jump_value.(on_variable_results.data[ix, :])
        ini_cond_value = get_condition(ini_cond[ix])
        aux_variable_container.data[ix, :] .= ini_cond_value
        sum_on_var = sum(on_var)
        if sum_on_var == time_steps[end] # Unit was always on
            aux_variable_container.data[ix, :] .= 0.0
        elseif sum_on_var == 0.0 # Unit was always off
            aux_variable_container.data[ix, :] += time_steps
        else
            previous_condition = ini_cond_value
            for (t, v) in enumerate(on_var)
                if v < 0.99 # Unit turn off
                    time_value = previous_condition + 1.0
                elseif isapprox(v, 1.0; atol=ABSOLUTE_TOLERANCE) # Unit is on
                    time_value = 0.0
                else
                    error("Binary condition returned $v")
                end
                previous_condition = aux_variable_container.data[ix, t] = time_value
            end
        end
    end

    return
end

function calculate_aux_variable_value!(
    container::OptimizationContainer,
    ::AuxVarKey{PowerOutput, T},
    system::PSY.System,
) where {T <: PSY.ThermalGen}
    devices = PSY.get_components(T, system)
    time_steps = get_time_steps(container)
    if has_container_key(container, OnVariable, T)
        on_variable_results = get_variable(container, OnVariable(), T)
    elseif has_container_key(container, OnStatusParameter, T)
        on_variable_results = get_parameter_array(container, OnStatusParameter(), T)
    else
        error(
            "$T formulation is NOT supported without a Feedforward for CommitmentDecisions,
      please consider changing your simulation setup or adding a SemiContinuousFeedforward.",
        )
    end
    p_variable_results = get_variable(container, PowerAboveMinimumVariable(), T)
    aux_variable_container = get_aux_variable(container, PowerOutput(), T)
    for d in devices, t in time_steps
        name = PSY.get_name(d)
        min = PSY.get_active_power_limits(d).min
        aux_variable_container[name, t] =
            jump_value(on_variable_results[name, t]) * min +
            jump_value(p_variable_results[name, t])
    end

    return
end
########################### Ramp/Rate of Change Constraints ################################
"""
This function gets the data for the generators for ramping constraints of thermal generators
"""
_get_initial_condition_type(
    ::Type{RampConstraint},
    ::Type{<:PSY.ThermalGen},
    ::Type{<:AbstractThermalFormulation},
) = DevicePower
_get_initial_condition_type(
    ::Type{RampConstraint},
    ::Type{<:PSY.ThermalGen},
    ::Type{<:AbstractCompactUnitCommitment},
) = DeviceAboveMinPower
_get_initial_condition_type(
    ::Type{RampConstraint},
    ::Type{<:PSY.ThermalGen},
    ::Type{ThermalCompactDispatch},
) = DeviceAboveMinPower

"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{RampConstraint},
    devices::IS.FlattenIteratorWrapper{U},
    model::DeviceModel{U, V},
    W::Type{<:PM.AbstractPowerModel},
) where {U <: PSY.ThermalGen, V <: AbstractThermalUnitCommitment}
    add_semicontinuous_ramp_constraints!(
        container,
        T,
        ActivePowerVariable,
        devices,
        model,
        W,
    )
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{RampConstraint},
    devices::IS.FlattenIteratorWrapper{U},
    model::DeviceModel{U, V},
    W::Type{<:PM.AbstractPowerModel},
) where {U <: PSY.ThermalGen, V <: AbstractCompactUnitCommitment}
    add_semicontinuous_ramp_constraints!(
        container,
        T,
        PowerAboveMinimumVariable,
        devices,
        model,
        W,
    )
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{RampConstraint},
    devices::IS.FlattenIteratorWrapper{U},
    model::DeviceModel{U, ThermalCompactDispatch},
    W::Type{<:PM.AbstractPowerModel},
) where {U <: PSY.ThermalGen}
    add_linear_ramp_constraints!(container, T, PowerAboveMinimumVariable, devices, model, W)
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{RampConstraint},
    devices::IS.FlattenIteratorWrapper{U},
    model::DeviceModel{U, V},
    W::Type{<:PM.AbstractPowerModel},
) where {U <: PSY.ThermalGen, V <: AbstractThermalDispatchFormulation}
    add_linear_ramp_constraints!(container, T, ActivePowerVariable, devices, model, W)
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{RampConstraint},
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    W::Type{<:PM.AbstractPowerModel},
)
    add_linear_ramp_constraints!(container, T, PowerAboveMinimumVariable, devices, model, W)
    return
end

########################### start up trajectory constraints ######################################

function _convert_hours_to_timesteps(
    start_times_hr::StartUpStages,
    resolution::Dates.TimePeriod,
)
    _start_times_ts = (
        round((hr * MINUTES_IN_HOUR) / Dates.value(Dates.Minute(resolution)), RoundUp) for
        hr in start_times_hr
    )
    start_times_ts = StartUpStages(_start_times_ts)
    return start_times_ts
end

@doc raw"""
Constructs contraints for different types of starts based on generator down-time

# Equations
for t in time_limits[s+1]:T

``` var_starts[name, s, t] <= sum( var_stop[name, t-i] for i in time_limits[s]:(time_limits[s+1]-1)  ```

# LaTeX

``  δ^{s}(t)  \leq \sum_{i=TS^{s}_{g}}^{TS^{s+1}_{g}} x^{stop}(t-i) ``
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{StartupTimeLimitTemperatureConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, ThermalMultiStartUnitCommitment},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ThermalMultiStart}
    resolution = get_resolution(container)
    time_steps = get_time_steps(container)
    start_vars = [
        get_variable(container, HotStartVariable(), T),
        get_variable(container, WarmStartVariable(), T),
    ]
    varstop = get_variable(container, StopVariable(), T)

    names = [PSY.get_name(d) for d in devices]

    con = [
        add_constraints_container!(
            container,
            StartupTimeLimitTemperatureConstraint(),
            T,
            names,
            time_steps;
            sparse=true,
            meta="hot",
        ),
        add_constraints_container!(
            container,
            StartupTimeLimitTemperatureConstraint(),
            T,
            names,
            time_steps;
            sparse=true,
            meta="warm",
        ),
    ]

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        startup_types = PSY.get_start_types(d)
        time_limits = _convert_hours_to_timesteps(PSY.get_start_time_limits(d), resolution)
        for ix in 1:(startup_types - 1)
            if t >= time_limits[ix + 1]
                con[ix][name, t] = JuMP.@constraint(
                    container.JuMPmodel,
                    start_vars[ix][name, t] <= sum(
                        varstop[name, t - i] for i in UnitRange{Int}(
                            Int(time_limits[ix]),
                            Int(time_limits[ix + 1] - 1),
                        )
                    )
                )
            end
        end
    end
    return
end

@doc raw"""

Constructs contraints that restricts devices to one type of start at a time

# Equations

``` sum(var_starts[name, s, t] for s in starts) = var_start[name, t]  ```

# LaTeX

``  \sum^{S_g}_{s=1} δ^{s}(t)  \eq  x^{start}(t) ``

"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{StartTypeConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, ThermalMultiStartUnitCommitment},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ThermalMultiStart}
    time_steps = get_time_steps(container)
    varstart = get_variable(container, StartVariable(), T)
    start_vars = [
        get_variable(container, HotStartVariable(), T),
        get_variable(container, WarmStartVariable(), T),
        get_variable(container, ColdStartVariable(), T),
    ]

    set_name = [PSY.get_name(d) for d in devices]
    con = add_constraints_container!(
        container,
        StartTypeConstraint(),
        T,
        set_name,
        time_steps,
    )

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        startup_types = PSY.get_start_types(d)
        con[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            varstart[name, t] == sum(start_vars[ix][name, t] for ix in 1:(startup_types))
        )
    end
    return
end

@doc raw"""
Constructs contraints that restricts devices to one type of start at a time

# Equations
ub:
``` (time_limits[st+1]-1)*δ^{s}(t) + (1 - δ^{s}(t)) * M_VALUE >= sum(1-varbin[name, i]) for i in 1:t) + initial_condition_offtime  ```
lb:
``` (time_limits[st]-1)*δ^{s}(t) =< sum(1-varbin[name, i]) for i in 1:t) + initial_condition_offtime  ```

# LaTeX

`` TS^{s+1}_{g} δ^{s}(t) + (1-δ^{s}(t)) M_VALUE   \geq  \sum^{t}_{i=1} x^{status}(i)  +  DT_{g}^{0}  \forall t in \{1, \ldots,  TS^{s+1}_{g}``

`` TS^{s}_{g} δ^{s}(t) \leq  \sum^{t}_{i=1} x^{status}(i)  +  DT_{g}^{0}  \forall t in \{1, \ldots,  TS^{s+1}_{g}``

"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{StartupInitialConditionConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, ThermalMultiStartUnitCommitment},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ThermalMultiStart}
    resolution = get_resolution(container)
    initial_conditions_offtime =
        get_initial_condition(container, InitialTimeDurationOff(), PSY.ThermalMultiStart)

    time_steps = get_time_steps(container)
    set_name = [get_component_name(ic) for ic in initial_conditions_offtime]
    varbin = get_variable(container, OnVariable(), T)
    varstarts = [
        get_variable(container, HotStartVariable(), T),
        get_variable(container, WarmStartVariable(), T),
    ]

    con_ub = add_constraints_container!(
        container,
        StartupInitialConditionConstraint(),
        T,
        set_name,
        time_steps,
        1:(MAX_START_STAGES - 1);
        sparse=true,
        meta="ub",
    )
    con_lb = add_constraints_container!(
        container,
        StartupInitialConditionConstraint(),
        T,
        set_name,
        time_steps,
        1:(MAX_START_STAGES - 1);
        sparse=true,
        meta="lb",
    )

    for t in time_steps, (ix, ic) in enumerate(initial_conditions_offtime)
        name = PSY.get_name(get_component(ic))
        startup_types = PSY.get_start_types(get_component(ic))
        time_limits = _convert_hours_to_timesteps(
            PSY.get_start_time_limits(get_component(ic)),
            resolution,
        )
        ic = initial_conditions_offtime[ix]
        for st in 1:(startup_types - 1)
            var = varstarts[st]
            if t < (time_limits[st + 1] - 1)
                con_ub[name, t, st] = JuMP.@constraint(
                    container.JuMPmodel,
                    (time_limits[st + 1] - 1) * var[name, t] +
                    (1 - var[name, t]) * M_VALUE >=
                    sum((1 - varbin[name, i]) for i in 1:t) + get_value(ic)
                )
                con_lb[name, t, st] = JuMP.@constraint(
                    container.JuMPmodel,
                    time_limits[st] * var[name, t] <=
                    sum((1 - varbin[name, i]) for i in 1:t) + get_value(ic)
                )
            end
        end
    end

    return
end

"""
This function creates constraints that keep must run devices online
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{MustRunConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, S},
    W::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ThermalGen, S <: AbstractThermalUnitCommitment}
    time_steps = get_time_steps(container)
    varon = get_variable(container, OnVariable(), T)
    names = [PSY.get_name(d) for d in devices if PSY.get_must_run(d)]
    constraint =
        add_constraints_container!(container, MustRunConstraint(), T, names, time_steps)

    for name in names, t in time_steps
        constraint[name, t] = JuMP.@constraint(container.JuMPmodel, varon[name, t] >= 1.0)
    end
    return
end

########################### time duration constraints ######################################
"""
If the fraction of hours that a generator has a duration constraint is less than
the fraction of hours that a single time_step represents then it is not binding.
"""
function _get_data_for_tdc(
    initial_conditions_on::Vector{T},
    initial_conditions_off::Vector{U},
    resolution::Dates.TimePeriod,
) where {T <: InitialCondition, U <: InitialCondition}
    steps_per_hour = 60 / Dates.value(Dates.Minute(resolution))
    fraction_of_hour = 1 / steps_per_hour
    lenght_devices_on = length(initial_conditions_on)
    lenght_devices_off = length(initial_conditions_off)
    IS.@assert_op lenght_devices_off == lenght_devices_on
    time_params = Vector{UpDown}(undef, lenght_devices_on)
    ini_conds = Matrix{InitialCondition}(undef, lenght_devices_on, 2)
    idx = 0
    for (ix, ic) in enumerate(initial_conditions_on)
        g = get_component(ic)
        IS.@assert_op g == get_component(initial_conditions_off[ix])
        time_limits = PSY.get_time_limits(g)
        name = PSY.get_name(g)
        if time_limits !== nothing
            if (time_limits.up <= fraction_of_hour) & (time_limits.down <= fraction_of_hour)
                @debug "Generator $(name) has a nonbinding time limits. Constraints Skipped"
                continue
            else
                idx += 1
            end
            ini_conds[idx, 1] = ic
            ini_conds[idx, 2] = initial_conditions_off[ix]
            up_val = round(time_limits.up * steps_per_hour, RoundUp)
            down_val = round(time_limits.down * steps_per_hour, RoundUp)
            time_params[idx] = time_params[idx] = (up=up_val, down=down_val)
        end
    end
    if idx < lenght_devices_on
        ini_conds = ini_conds[1:idx, :]
        deleteat!(time_params, (idx + 1):lenght_devices_on)
    end
    return ini_conds, time_params
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{DurationConstraint},
    ::IS.FlattenIteratorWrapper{U},
    ::DeviceModel{U, V},
    ::Type{<:PM.AbstractPowerModel},
) where {U <: PSY.ThermalGen, V <: AbstractThermalUnitCommitment}
    parameters = built_for_recurrent_solves(container)
    resolution = get_resolution(container)
    # Use getter functions that don't require creating the keys here
    initial_conditions_on = get_initial_condition(container, InitialTimeDurationOn(), U)
    initial_conditions_off = get_initial_condition(container, InitialTimeDurationOff(), U)
    ini_conds, time_params =
        _get_data_for_tdc(initial_conditions_on, initial_conditions_off, resolution)
    if !(isempty(ini_conds))
        if parameters
            device_duration_parameters!(
                container,
                time_params,
                ini_conds,
                DurationConstraint(),
                (OnVariable(), StartVariable(), StopVariable()),
                U,
            )
        else
            device_duration_retrospective!(
                container,
                time_params,
                ini_conds,
                DurationConstraint(),
                (OnVariable(), StartVariable(), StopVariable()),
                U,
            )
        end
    else
        @warn "Data doesn't contain generators with time-up/down limits, consider adjusting your formulation"
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{DurationConstraint},
    devices::IS.FlattenIteratorWrapper{U},
    model::DeviceModel{U, ThermalMultiStartUnitCommitment},
    W::Type{<:PM.AbstractPowerModel},
) where {U <: PSY.ThermalGen}
    parameters = built_for_recurrent_solves(container)
    resolution = get_resolution(container)
    initial_conditions_on = get_initial_condition(container, InitialTimeDurationOn(), U)
    initial_conditions_off = get_initial_condition(container, InitialTimeDurationOff(), U)
    ini_conds, time_params =
        _get_data_for_tdc(initial_conditions_on, initial_conditions_off, resolution)
    if !(isempty(ini_conds))
        if parameters
            device_duration_parameters!(
                container,
                time_params,
                ini_conds,
                DurationConstraint(),
                (OnVariable(), StartVariable(), StopVariable()),
                U,
            )
        else
            device_duration_compact_retrospective!(
                container,
                time_params,
                ini_conds,
                DurationConstraint(),
                (OnVariable(), StartVariable(), StopVariable()),
                U,
            )
        end
    else
        @warn "Data doesn't contain generators with time-up/down limits, consider adjusting your formulation"
    end
    return
end

########################### Objective Function Calls#############################################
# These functions are custom implementations of the cost data. In the file objective_functions.jl there are default implementations. Define these only if needed.

function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ThermalGen, U <: AbstractThermalUnitCommitment}
    add_variable_cost!(container, ActivePowerVariable(), devices, U())
    add_start_up_cost!(container, StartVariable(), devices, U())
    add_shut_down_cost!(container, StopVariable(), devices, U())
    add_proportional_cost!(container, OnVariable(), devices, U())
    return
end

function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ThermalGen, U <: AbstractCompactUnitCommitment}
    add_variable_cost!(container, PowerAboveMinimumVariable(), devices, U())
    add_start_up_cost!(container, StartVariable(), devices, U())
    add_shut_down_cost!(container, StopVariable(), devices, U())
    add_proportional_cost!(container, OnVariable(), devices, U())
    return
end

function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    ::DeviceModel{PSY.ThermalMultiStart, U},
    ::Type{<:PM.AbstractPowerModel},
) where {U <: ThermalMultiStartUnitCommitment}
    add_variable_cost!(container, PowerAboveMinimumVariable(), devices, U())
    for var_type in START_VARIABLES
        add_start_up_cost!(container, var_type(), devices, U())
    end
    add_shut_down_cost!(container, StopVariable(), devices, U())
    add_proportional_cost!(container, OnVariable(), devices, U())
    return
end

function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ThermalGen, U <: AbstractThermalDispatchFormulation}
    add_variable_cost!(container, ActivePowerVariable(), devices, U())
    return
end

function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ThermalGen, U <: ThermalCompactDispatch}
    add_variable_cost!(container, PowerAboveMinimumVariable(), devices, U())
    return
end

function objective_function!(
    ::OptimizationContainer,
    ::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    ::DeviceModel{PSY.ThermalMultiStart, ThermalDispatchNoMin},
    ::Type{<:PM.AbstractPowerModel},
)
    throw(
        IS.ConflictingInputsError(
            "ThermalDispatchNoMin cost function is not compatible with ThermalMultiStart Devices.",
        ),
    )
end
