#! format: off

########################### Thermal Generation Models ######################################

abstract type AbstractThermalFormulation <: AbstractDeviceFormulation end
abstract type AbstractThermalDispatchFormulation <: AbstractThermalFormulation end
abstract type AbstractThermalUnitCommitment <: AbstractThermalFormulation end

abstract type AbstractStandardUnitCommitment <: AbstractThermalUnitCommitment end
abstract type AbstractCompactUnitCommitment <: AbstractThermalUnitCommitment end

struct ThermalBasicUnitCommitment <: AbstractStandardUnitCommitment end
struct ThermalStandardUnitCommitment <: AbstractStandardUnitCommitment end
struct ThermalDispatch <: AbstractThermalDispatchFormulation end
struct ThermalRampLimited <: AbstractThermalDispatchFormulation end
struct ThermalDispatchNoMin <: AbstractThermalDispatchFormulation end

struct ThermalMultiStartUnitCommitment <: AbstractCompactUnitCommitment end
struct ThermalCompactUnitCommitment <: AbstractCompactUnitCommitment end
struct ThermalCompactDispatch <: AbstractThermalDispatchFormulation end

requires_initialization(::AbstractThermalFormulation) = false
requires_initialization(::AbstractThermalUnitCommitment) = true
requires_initialization(::ThermalRampLimited) = true

get_variable_multiplier(_, ::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = 1.0
get_variable_multiplier(::OnVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power_limits(d).min
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.ThermalGen}, ::Type{<:PSY.Reserve{PSY.ReserveUp}}) = ActivePowerRangeExpressionUB
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.ThermalGen}, ::Type{<:PSY.Reserve{PSY.ReserveDown}}) = ActivePowerRangeExpressionLB

############## ActivePowerVariable, ThermalGen ####################
get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = false
get_variable_binary(::PowerAboveMinimumVariable, ::Type{<:PSY.ThermalGen}, ::AbstractThermalFormulation) = false
get_variable_warm_start_value(::ActivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power(d)
get_variable_warm_start_value(::PowerAboveMinimumVariable, d::PSY.ThermalGen, ::AbstractCompactUnitCommitment) = max(0.0, PSY.get_active_power(d) - PSY.get_active_power_limits(d).min)

get_variable_lower_bound(::ActivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power_limits(d).min
get_variable_lower_bound(::ActivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalUnitCommitment) = 0.0
get_variable_lower_bound(::PowerAboveMinimumVariable, d::PSY.ThermalGen, ::AbstractCompactUnitCommitment) = 0.0
get_variable_upper_bound(::ActivePowerVariable, d::PSY.ThermalGen, ::AbstractThermalFormulation) = PSY.get_active_power_limits(d).max
get_variable_upper_bound(::PowerAboveMinimumVariable, d::PSY.ThermalGen, ::AbstractCompactUnitCommitment) = PSY.get_active_power_limits(d).max - PSY.get_active_power_limits(d).min

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

#! format: on
#################### Initial Conditions for models ###############
initial_condition_default(::DeviceStatus, d::PSY.ThermalGen, ::AbstractThermalFormulation) =
    PSY.get_status(d)
initial_condition_variable(
    ::DeviceStatus,
    d::PSY.ThermalGen,
    ::AbstractThermalFormulation,
) = OnVariable()

initial_condition_default(::DevicePower, d::PSY.ThermalGen, ::AbstractThermalFormulation) =
    PSY.get_active_power(d)
initial_condition_variable(::DevicePower, d::PSY.ThermalGen, ::AbstractThermalFormulation) =
    ActivePowerVariable()
initial_condition_default(
    ::DeviceAboveMinPower,
    d::PSY.ThermalGen,
    ::AbstractThermalFormulation,
) = max(0.0, PSY.get_active_power(d) - PSY.get_active_power_limits(d).min)
initial_condition_variable(
    ::DeviceAboveMinPower,
    d::PSY.ThermalGen,
    ::AbstractCompactUnitCommitment,
) = PowerAboveMinimumVariable()
initial_condition_variable(
    ::DeviceAboveMinPower,
    d::PSY.ThermalGen,
    ::ThermalCompactDispatch,
) = PowerAboveMinimumVariable()

initial_condition_default(
    ::InitialTimeDurationOn,
    d::PSY.ThermalGen,
    ::AbstractThermalFormulation,
) = PSY.get_status(d) ? PSY.get_time_at_status(d) : 0.0
initial_condition_variable(
    ::InitialTimeDurationOn,
    d::PSY.ThermalGen,
    ::AbstractThermalFormulation,
) = OnVariable()

initial_condition_default(
    ::InitialTimeDurationOff,
    d::PSY.ThermalGen,
    ::AbstractThermalFormulation,
) = !PSY.get_status(d) ? PSY.get_time_at_status(d) : 0.0
initial_condition_variable(
    ::InitialTimeDurationOff,
    d::PSY.ThermalGen,
    ::AbstractThermalFormulation,
) = OnVariable()

function get_initial_conditions_device_model(
    model::DeviceModel{T, D},
) where {T <: PSY.ThermalGen, D <: AbstractThermalDispatchFormulation}
    return DeviceModel(T, ThermalDispatch)
end

function get_initial_conditions_device_model(
    model::DeviceModel{T, D},
) where {T <: PSY.ThermalGen, D <: AbstractThermalUnitCommitment}
    return DeviceModel(T, ThermalBasicUnitCommitment)
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
    PSY.get_active_power_limits(device)
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
    PSY.get_active_power_limits(device)
end

"""
Range constraints for thermal compact dispatch
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:PowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.ThermalGen, W <: ThermalCompactDispatch}
    add_range_constraints!(container, T, U, devices, model, X)
end

"""
Min and max active power limits of generators for thermal dispatch compact formulations
"""
function get_min_max_limits(
    device,
    ::Type{PowerAboveMinimumVariable},
    ::Type{<:ThermalCompactDispatch},
)
    (
        min = 0.0,
        max = PSY.get_active_power_limits(device).max -
              PSY.get_active_power_limits(device).min,
    )
end

"""
Min and max active power limits of generators for thermal dispatch no minimum formulations
"""
function get_min_max_limits(
    device,
    ::Type{ActivePowerVariableLimitsConstraint},
    ::Type{<:ThermalDispatchNoMin},
) #  -> Union{Nothing, NamedTuple{(:startup, :shutdown), Tuple{Float64, Float64}}}
    (min = 0.0, max = PSY.get_active_power_limits(device).max)
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
    add_range_constraints!(container, T, U, devices, model, X)
end

"""
Min and max active power limits for multi-start unit commitment formulations
"""
function get_min_max_limits(
    device,
    ::Type{ActivePowerVariableLimitsConstraint},
    ::Type{<:ThermalMultiStartUnitCommitment},
) #  -> Union{Nothing, NamedTuple{(:startup, :shutdown), Tuple{Float64, Float64}}}
    (
        min = 0.0,
        max = PSY.get_active_power_limits(device).max -
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
end

"""
Startup and shutdown active power limits for Compact Unit Commitment
"""
function get_startup_shutdown_limits(
    device,
    ::Type{ActivePowerVariableLimitsConstraint},
    ::Type{<:ThermalMultiStartUnitCommitment},
)
    PSY.get_power_trajectory(device)
end

"""
Min and Max active power limits for Compact Unit Commitment
"""
function get_min_max_limits(
    device,
    ::Type{ActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractCompactUnitCommitment},
) #  -> Union{Nothing, NamedTuple{(:startup, :shutdown), Tuple{Float64, Float64}}}
    (
        min = 0,
        max = PSY.get_active_power_limits(device).max -
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
    (
        startup = PSY.get_active_power_limits(device).max,
        shutdown = PSY.get_active_power_limits(device).max,
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
    con_on = add_cons_container!(
        container,
        constraint_type,
        component_type,
        names,
        time_steps,
        meta = "on",
    )
    con_off = add_cons_container!(
        container,
        constraint_type,
        component_type,
        names,
        time_steps,
        meta = "off",
        sparse = true,
    )
    con_lb = add_cons_container!(
        container,
        constraint_type,
        component_type,
        names,
        time_steps,
        meta = "lb",
    )

    for device in devices, t in time_steps
        name = PSY.get_name(device)
        limits = get_min_max_limits(device, T, W) # depends on constraint type and formulation type
        startup_shutdown_limits = get_startup_shutdown_limits(device, T, W)
        if JuMP.has_lower_bound(varp[name, t])
            JuMP.set_lower_bound(varp[name, t], 0.0)
        end
        expression_products = JuMP.AffExpr(0.0, varp[name, t] => 1.0)
        con_on[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_products <=
            (limits.max - limits.min) * varstatus[name, t] -
            max(limits.max - startup_shutdown_limits.startup, 0.0) * varon[name, t]
        )

        exp_lb = JuMP.AffExpr(0.0, varp[name, t] => 1.0)
        con_lb[name, t] = JuMP.@constraint(container.JuMPmodel, exp_lb >= 0.0)

        if t == length(time_steps)
            continue
        else
            con_off[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                expression_products <=
                (limits.max - limits.min) * varstatus[name, t] -
                max(limits.max - startup_shutdown_limits.shutdown, 0.0) *
                varoff[name, t + 1]
            )
        end
    end
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
    varstatus = get_variable(container, OnVariable(), component_type)
    varon = get_variable(container, StartVariable(), component_type)
    varoff = get_variable(container, StopVariable(), component_type)

    names = [PSY.get_name(x) for x in devices]
    con_lb = add_cons_container!(
        container,
        constraint_type,
        component_type,
        names,
        time_steps,
        meta = "lb",
    )

    for device in devices, t in time_steps
        name = PSY.get_name(device)
        limits = get_min_max_limits(device, T, W) # depends on constraint type and formulation type
        startup_shutdown_limits = get_startup_shutdown_limits(device, T, W)
        if JuMP.has_lower_bound(varp[name, t])
            JuMP.set_lower_bound(varp[name, t], 0.0)
        end
        con_lb[name, t] = JuMP.@constraint(container.JuMPmodel, expression_products >= 0)
    end
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

    names = [PSY.get_name(x) for x in devices]
    con_on = add_cons_container!(
        container,
        constraint_type,
        component_type,
        names,
        time_steps,
        meta = "on",
    )
    con_off = add_cons_container!(
        container,
        constraint_type,
        component_type,
        names,
        time_steps,
        meta = "off",
        sparse = true,
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
            expression_products <=
            (limits.max - limits.min) * varstatus[name, t] -
            max(limits.max - startup_shutdown_limits.startup, 0) * varon[name, t]
        )
        if t == length(time_steps)
            continue
        else
            con_off[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                expression_products <=
                (limits.max - limits.min) * varstatus[name, t] -
                max(limits.max - startup_shutdown_limits.shutdown, 0) * varoff[name, t + 1]
            )
        end
    end
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
        con = add_cons_container!(container, ActiveRangeICConstraint(), T, set_name)

        for (ix, ic) in enumerate(ini_conds[:, 1])
            name = get_component_name(ic)
            device = get_component(ic)
            limits = PSY.get_active_power_limits(device)
            lag_ramp_limits = PSY.get_power_trajectory(device)
            val = max(limits.max - lag_ramp_limits.shutdown, 0)
            # TODO: How to do the following?
            # add_device_services!(range_data, d, model)
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
    PSY.get_reactive_power_limits(device)
end

"""
Reactive power limits of generators when there CommitmentVariables
"""
function get_min_max_limits(
    device,
    ::Type{ReactivePowerVariableLimitsConstraint},
    ::Type{<:AbstractThermalUnitCommitment},
)
    PSY.get_reactive_power_limits(device)
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
        add_cons_container!(container, CommitmentConstraint(), U, names, time_steps)
    aux_constraint = add_cons_container!(
        container,
        CommitmentConstraint(),
        U,
        names,
        time_steps,
        meta = "aux",
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
    formulation::ThermalBasicUnitCommitment,
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
    key::AuxVarKey{TimeDurationOn, T},
    ::PSY.System,
) where {T <: PSY.ThermalGen}
    on_var_results = get_variable(container, OnVariable(), T)
    aux_var_container = get_aux_variable(container, TimeDurationOn(), T)
    ini_cond = get_initial_condition(container, InitialTimeDurationOn(), T)

    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    minutes_per_period = Dates.value(Dates.Minute(resolution))

    for ix in eachindex(JuMP.axes(aux_var_container)[1])
        @assert JuMP.axes(aux_var_container)[1][ix] == JuMP.axes(on_var_results)[1][ix]
        @assert JuMP.axes(aux_var_container)[1][ix] == get_component_name(ini_cond[ix])
        on_var = JuMP.value.(on_var_results.data[ix, :])
        ini_cond_value = get_condition(ini_cond[ix])
        aux_var_container.data[ix, :] .= ini_cond_value
        sum_on_var = sum(on_var)
        if sum_on_var == time_steps[end] # Unit was always on
            aux_var_container.data[ix, :] += time_steps * minutes_per_period
        elseif sum_on_var == 0.0 # Unit was always off
            aux_var_container.data[ix, :] .= 0.0
        else
            previous_condition = ini_cond_value
            for (t, v) in enumerate(on_var)
                if v < 0.99 # Unit turn off
                    time_value = 0.0
                elseif isapprox(v, 1.0; atol = ABSOLUTE_TOLERANCE) # Unit is on
                    time_value = previous_condition + 1.0
                else
                    error("Binary condition returned $v")
                end
                previous_condition = aux_var_container.data[ix, t] = time_value
            end
        end
    end

    return
end

function calculate_aux_variable_value!(
    container::OptimizationContainer,
    key::AuxVarKey{TimeDurationOff, T},
    ::PSY.System,
) where {T <: PSY.ThermalGen}
    on_var_results = get_variable(container, OnVariable(), T)
    aux_var_container = get_aux_variable(container, TimeDurationOff(), T)
    ini_cond = get_initial_condition(container, InitialTimeDurationOff(), T)

    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    minutes_per_period = Dates.value(Dates.Minute(resolution))

    for ix in eachindex(JuMP.axes(aux_var_container)[1])
        @assert JuMP.axes(aux_var_container)[1][ix] == JuMP.axes(on_var_results)[1][ix]
        @assert JuMP.axes(aux_var_container)[1][ix] == get_component_name(ini_cond[ix])
        on_var = JuMP.value.(on_var_results.data[ix, :])
        ini_cond_value = get_condition(ini_cond[ix])
        aux_var_container.data[ix, :] .= ini_cond_value
        sum_on_var = sum(on_var)
        if sum_on_var == time_steps[end] # Unit was always on
            aux_var_container.data[ix, :] .= 0.0
        elseif sum_on_var == 0.0 # Unit was always off
            aux_var_container.data[ix, :] += time_steps * minutes_per_period
        else
            previous_condition = ini_cond_value
            for (t, v) in enumerate(on_var)
                if v < 0.99 # Unit turn off
                    time_value = previous_condition + 1.0
                elseif isapprox(v, 1.0; atol = ABSOLUTE_TOLERANCE) # Unit is on
                    time_value = 0.0
                else
                    error("Binary condition returned $v")
                end
                previous_condition = aux_var_container.data[ix, t] = time_value
            end
        end
    end

    return
end

function calculate_aux_variable_value!(
    container::OptimizationContainer,
    key::AuxVarKey{PowerOutput, T},
    system::PSY.System,
) where {T <: PSY.ThermalGen}
    devices = PSY.get_components(T, system)
    time_steps = get_time_steps(container)
    on_var_results = get_variable(container, OnVariable(), T)
    p_var_results = get_variable(container, PowerAboveMinimumVariable(), T)
    aux_var_container = get_aux_variable(container, PowerOutput(), T)
    for d in devices, t in time_steps
        name = PSY.get_name(d)
        min = PSY.get_active_power_limits(d).min
        aux_var_container[name, t] =
            JuMP.value(on_var_results[name, t]) * min + JuMP.value(p_var_results[name, t])
    end

    return
end
########################### Ramp/Rate of Change Constraints ################################
"""
This function gets the data for the generators for ramping constraints of thermal generators
"""
_get_initial_condition_type(
    ::Type{<:PSY.ThermalGen},
    ::Type{<:AbstractThermalFormulation},
) = DevicePower
_get_initial_condition_type(
    ::Type{<:PSY.ThermalGen},
    ::Type{<:AbstractCompactUnitCommitment},
) = DeviceAboveMinPower
_get_initial_condition_type(::Type{<:PSY.ThermalGen}, ::Type{ThermalCompactDispatch}) =
    DeviceAboveMinPower

function _get_data_for_rocc(
    container::OptimizationContainer,
    ::DeviceModel{T, V},
) where {T <: PSY.ThermalGen, V <: AbstractThermalFormulation}
    resolution = get_resolution(container)
    if resolution > Dates.Minute(1)
        minutes_per_period = Dates.value(Dates.Minute(resolution))
    else
        @warn("Not all formulations support under 1-minute resolutions. Exercise caution.")
        minutes_per_period = Dates.value(Dates.Second(resolution)) / 60
    end

    IC = _get_initial_condition_type(T, V)
    initial_conditions_power = get_initial_condition(container, IC(), T)
    lenght_devices_power = length(initial_conditions_power)
    data = Vector{DeviceRampConstraintInfo}(undef, lenght_devices_power)
    idx = 0
    for ic in initial_conditions_power
        g = get_component(ic)
        name = PSY.get_name(g)
        ramp_limits = PSY.get_ramp_limits(g)
        if !(ramp_limits === nothing)
            p_lims = PSY.get_active_power_limits(g)
            max_rate = abs(p_lims.min - p_lims.max) / minutes_per_period
            if (ramp_limits.up >= max_rate) & (ramp_limits.down >= max_rate)
                @debug "Generator $(name) has a nonbinding ramp limits. Constraints Skipped"
                continue
            else
                idx += 1
            end
            ramp = (
                up = ramp_limits.up * minutes_per_period,
                down = ramp_limits.down * minutes_per_period,
            )
            data[idx] = DeviceRampConstraintInfo(name, p_lims, ic, ramp)
        end
    end
    if idx < lenght_devices_power
        deleteat!(data, (idx + 1):lenght_devices_power)
    end
    return data
end

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
    data = _get_data_for_rocc(container, model)
    if !isempty(data)
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        for r in data
            add_device_services!(r, get_component(r.ic_power), model)
        end
        device_mixedinteger_rateofchange!(
            container,
            data,
            RampConstraint(),
            (ActivePowerVariable(), StartVariable(), StopVariable()),
            U,
        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{RampConstraint},
    devices::IS.FlattenIteratorWrapper{U},
    model::DeviceModel{U, V},
    W::Type{<:PM.AbstractPowerModel},
) where {U <: PSY.ThermalGen, V <: AbstractCompactUnitCommitment}
    data = _get_data_for_rocc(container, model)
    if !isempty(data)
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        for r in data
            add_device_services!(r, get_component(r.ic_power), model)
        end
        device_mixedinteger_rateofchange!(
            container,
            data,
            RampConstraint(),
            (PowerAboveMinimumVariable(), StartVariable(), StopVariable()),
            U,
        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{RampConstraint},
    devices::IS.FlattenIteratorWrapper{U},
    model::DeviceModel{U, ThermalCompactDispatch},
    W::Type{<:PM.AbstractPowerModel},
) where {U <: PSY.ThermalGen}
    data = _get_data_for_rocc(container, model)
    if !isempty(data)
        for r in data
            add_device_services!(r, get_component(r.ic_power), model)
        end
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        device_linear_rateofchange!(
            container,
            data,
            RampConstraint(),
            PowerAboveMinimumVariable(),
            U,
        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{RampConstraint},
    devices::IS.FlattenIteratorWrapper{U},
    model::DeviceModel{U, V},
    W::Type{<:PM.AbstractPowerModel},
) where {U <: PSY.ThermalGen, V <: AbstractThermalDispatchFormulation}
    data = _get_data_for_rocc(container, model)
    if !isempty(data)
        for r in data
            add_device_services!(r, get_component(r.ic_power), model)
        end
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        device_linear_rateofchange!(
            container,
            data,
            RampConstraint(),
            ActivePowerVariable(),
            U,
        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{RampConstraint},
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    model::DeviceModel{PSY.ThermalMultiStart, ThermalMultiStartUnitCommitment},
    W::Type{<:PM.AbstractPowerModel},
)
    data = _get_data_for_rocc(container, model)

    # TODO: Refactor this to a cleaner format that doesn't require passing the device and rate_data this way
    for r in data
        add_device_services!(r, get_component(r.ic_power), model)
    end
    if !isempty(data)
        device_multistart_rateofchange!(
            container,
            data,
            RampConstraint(),
            PowerAboveMinimumVariable(),
            PSY.ThermalMultiStart,
        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end
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
        add_cons_container!(
            container,
            StartupTimeLimitTemperatureConstraint(),
            T,
            names,
            time_steps;
            sparse = true,
            meta = "hot",
        ),
        add_cons_container!(
            container,
            StartupTimeLimitTemperatureConstraint(),
            T,
            names,
            time_steps;
            sparse = true,
            meta = "warm",
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
    con = add_cons_container!(container, StartTypeConstraint(), T, set_name, time_steps)

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

    con_ub = add_cons_container!(
        container,
        StartupInitialConditionConstraint(),
        T,
        set_name,
        time_steps,
        1:(MAX_START_STAGES - 1);
        sparse = true,
        meta = "ub",
    )
    con_lb = add_cons_container!(
        container,
        StartupInitialConditionConstraint(),
        T,
        set_name,
        time_steps,
        1:(MAX_START_STAGES - 1);
        sparse = true,
        meta = "lb",
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
    constraint = add_cons_container!(container, MustRunConstraint(), T, names, time_steps)

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
    @assert lenght_devices_off == lenght_devices_on
    time_params = Vector{UpDown}(undef, lenght_devices_on)
    ini_conds = Matrix{InitialCondition}(undef, lenght_devices_on, 2)
    idx = 0
    for (ix, ic) in enumerate(initial_conditions_on)
        g = get_component(ic)
        @assert g == get_component(initial_conditions_off[ix])
        time_limits = PSY.get_time_limits(g)
        name = PSY.get_name(g)
        if !(time_limits === nothing)
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
            time_params[idx] = time_params[idx] = (up = up_val, down = down_val)
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
    T::Type{DurationConstraint},
    devices::IS.FlattenIteratorWrapper{U},
    model::DeviceModel{U, V},
    W::Type{<:PM.AbstractPowerModel},
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
    T::Type{DurationConstraint},
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

########################### Cost Function Calls#############################################
# These functions are custom implementations of the cost data. In the file cost_functions.jl there are default implementations. Define these only if needed.

function AddCostSpec(
    ::Type{T},
    ::Type{U},
    container::OptimizationContainer,
) where {T <: PSY.ThermalGen, U <: AbstractThermalUnitCommitment}
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        has_status_variable = has_on_variable(container, T),
        has_status_parameter = has_on_parameter(container, T),
        variable_cost = PSY.get_variable,
        start_up_cost = PSY.get_start_up,
        shut_down_cost = PSY.get_shut_down,
        fixed_cost = PSY.get_fixed,
        sos_status = SOSStatusVariable.VARIABLE,
    )
end

function AddCostSpec(
    ::Type{PSY.ThermalMultiStart},
    ::Type{U},
    container::OptimizationContainer,
) where {U <: AbstractStandardUnitCommitment}
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = PSY.ThermalMultiStart,
        has_status_variable = has_on_variable(container, PSY.ThermalMultiStart),
        has_status_parameter = has_on_parameter(container, PSY.ThermalMultiStart),
        variable_cost = PSY.get_variable,
        start_up_cost = x -> getfield(PSY.get_start_up(x), :cold),
        shut_down_cost = PSY.get_shut_down,
        fixed_cost = PSY.get_fixed,
        sos_status = SOSStatusVariable.VARIABLE,
    )
end

function AddCostSpec(
    ::Type{T},
    ::Type{U},
    container::OptimizationContainer,
) where {T <: PSY.ThermalGen, U <: AbstractThermalDispatchFormulation}
    if has_on_parameter(container, T)
        sos_status = SOSStatusVariable.PARAMETER
    else
        sos_status = SOSStatusVariable.NO_VARIABLE
    end

    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        has_status_variable = has_on_variable(container, T),
        has_status_parameter = has_on_parameter(container, T),
        variable_cost = PSY.get_variable,
        fixed_cost = PSY.get_fixed,
        sos_status = sos_status,
    )
end

function AddCostSpec(
    ::Type{T},
    ::Type{U},
    container::OptimizationContainer,
) where {T <: PSY.ThermalGen, U <: AbstractCompactUnitCommitment}
    fixed_cost_func = x -> PSY.get_fixed(x) + PSY.get_no_load(x)
    return AddCostSpec(;
        variable_type = PowerAboveMinimumVariable,
        component_type = T,
        has_status_variable = has_on_variable(container, T),
        has_status_parameter = has_on_parameter(container, T),
        variable_cost = _get_compact_varcost,
        shut_down_cost = PSY.get_shut_down,
        start_up_cost = PSY.get_start_up,
        fixed_cost = fixed_cost_func,
        sos_status = SOSStatusVariable.VARIABLE,
        uses_compact_power = true,
    )
end

function AddCostSpec(
    ::Type{T},
    ::Type{ThermalCompactDispatch},
    container::OptimizationContainer,
) where {T <: PSY.ThermalGen}
    if has_on_parameter(container, T)
        sos_status = SOSStatusVariable.PARAMETER
    else
        sos_status = SOSStatusVariable.NO_VARIABLE
    end
    fixed_cost_func = x -> PSY.get_fixed(x) + PSY.get_no_load(x)
    return AddCostSpec(;
        variable_type = PowerAboveMinimumVariable,
        component_type = T,
        has_status_variable = has_on_variable(container, T),
        has_status_parameter = has_on_parameter(container, T),
        variable_cost = _get_compact_varcost,
        fixed_cost = fixed_cost_func,
        sos_status = sos_status,
        uses_compact_power = true,
    )
end

function AddCostSpec(
    ::Type{T},
    ::Type{U},
    container::OptimizationContainer,
) where {T <: PSY.ThermalGen, U <: ThermalMultiStartUnitCommitment}
    fixed_cost_func = x -> PSY.get_fixed(x) + PSY.get_no_load(x)
    return AddCostSpec(;
        variable_type = PowerAboveMinimumVariable,
        component_type = T,
        has_status_variable = has_on_variable(container, T),
        has_status_parameter = has_on_parameter(container, T),
        variable_cost = _get_compact_varcost,
        start_up_cost = PSY.get_start_up,
        shut_down_cost = PSY.get_shut_down,
        fixed_cost = fixed_cost_func,
        sos_status = SOSStatusVariable.VARIABLE,
        has_multistart_variables = true,
        uses_compact_power = true,
    )
end

function PSY.get_no_load(cost::Union{PSY.ThreePartCost, PSY.TwoPartCost})
    _, no_load_cost = _convert_variable_cost(PSY.get_variable(cost))
    return no_load_cost
end

function _get_compact_varcost(cost)
    return PSY.get_variable(cost)
end

function _get_compact_varcost(cost::Union{PSY.ThreePartCost, PSY.TwoPartCost})
    var_cost, _ = _convert_variable_cost(PSY.get_variable(cost))
    return var_cost
end

function _convert_variable_cost(var_cost::PSY.VariableCost)
    return var_cost, 0.0
end

function _convert_variable_cost(var_cost::PSY.VariableCost{Float64})
    return var_cost, var_cost
end

function _convert_variable_cost(variable_cost::PSY.VariableCost{Vector{NTuple{2, Float64}}})
    var_cost = PSY.get_cost(variable_cost)
    no_load_cost, p_min = var_cost[1]
    var_cost = PSY.VariableCost([(c - no_load_cost, pp - p_min) for (c, pp) in var_cost])
    return var_cost, no_load_cost
end

"""
Cost function for generators formulated as No-Min
"""
function cost_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, ThermalDispatchNoMin},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ThermalGen}
    no_min_spec = AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        has_status_variable = has_on_variable(container, T),
        has_status_parameter = has_on_parameter(container, T),
        variable_cost = PSY.get_variable,
        fixed_cost = PSY.get_fixed,
    )
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    for g in devices
        component_name = PSY.get_name(g)
        op_cost = PSY.get_operation_cost(g)
        cost_component = PSY.get_variable(op_cost)
        if isa(cost_component, PSY.VariableCost{Array{Tuple{Float64, Float64}, 1}})
            @debug "PWL cost function detected for device $(component_name) using ThermalDispatchNoMin"
            slopes = PSY.get_slopes(cost_component)
            if any(slopes .< 0) || !pwlparamcheck(cost_component)
                throw(
                    IS.InvalidValue(
                        "The PWL cost data provided for generator $(PSY.get_name(g)) is not compatible with a No Min Cost.",
                    ),
                )
            end
            if slopes[1] != 0.0
                @debug "PWL has no 0.0 intercept for generator $(PSY.get_name(g))"
                # adds a first intercept a x = 0.0 and Y below the intercept of the first tuple to make convex equivalent
                first_pair = PSY.get_cost(cost_component)[1]
                cost_function_data = deepcopy(cost_component.cost)
                intercept_point = (0.0, first_pair[2] - COST_EPSILON)
                cost_function_data = vcat(intercept_point, cost_function_data)
                @assert slope_convexity_check(slopes)
            else
                cost_function_data = cost_component.cost
            end
            time_steps = get_time_steps(container)
            for t in time_steps
                gen_cost = pwl_gencost_linear!(
                    container,
                    no_min_spec,
                    component_name,
                    cost_function_data,
                    t,
                )
                add_to_cost_expression!(container, no_min_spec.multiplier * gen_cost * dt)
            end
        else
            add_to_cost!(container, no_min_spec, op_cost, g)
        end
    end
    return
end

function cost_function!(
    ::OptimizationContainer,
    ::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
    ::DeviceModel{PSY.ThermalMultiStart, ThermalDispatchNoMin},
    ::Type{<:PM.AbstractPowerModel},
    ::Union{Nothing, AbstractAffectFeedForward},
)
    error("DispatchNoMin is not compatible with ThermalMultiStart")
end
