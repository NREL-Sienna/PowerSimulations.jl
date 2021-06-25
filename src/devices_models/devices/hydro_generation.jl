#! format: off

abstract type AbstractHydroFormulation <: AbstractDeviceFormulation end
abstract type AbstractHydroDispatchFormulation <: AbstractHydroFormulation end
abstract type AbstractHydroUnitCommitment <: AbstractHydroFormulation end
abstract type AbstractHydroReservoirFormulation <: AbstractHydroDispatchFormulation end
struct HydroDispatchRunOfRiver <: AbstractHydroDispatchFormulation end
struct HydroDispatchReservoirBudget <: AbstractHydroReservoirFormulation end
struct HydroDispatchReservoirStorage <: AbstractHydroReservoirFormulation end
struct HydroDispatchPumpedStorage <: AbstractHydroReservoirFormulation end
struct HydroDispatchPumpedStoragewReservation <: AbstractHydroReservoirFormulation end
struct HydroCommitmentRunOfRiver <: AbstractHydroUnitCommitment end
struct HydroCommitmentReservoirBudget <: AbstractHydroUnitCommitment end
struct HydroCommitmentReservoirStorage <: AbstractHydroUnitCommitment end

get_variable_sign(_, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = 1.0
########################### ActivePowerVariable, HydroGen #################################
get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_expression_name(::ActivePowerVariable, ::Type{<:PSY.HydroGen}) = :nodal_balance_active

get_variable_initial_value(::ActivePowerVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power(d)

get_variable_lower_bound(::ActivePowerVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power_limits(d).min
get_variable_upper_bound(::ActivePowerVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power_limits(d).max

############## ActivePowerVariable, HydroDispatchRunOfRiver ####################
get_variable_lower_bound(::ActivePowerVariable, d::PSY.HydroGen, ::HydroDispatchRunOfRiver) = 0.0

############## ReactivePowerVariable, HydroGen ####################
get_variable_binary(::ReactivePowerVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_expression_name(::ReactivePowerVariable, ::Type{<:PSY.HydroGen}) = :nodal_balance_reactive
get_variable_initial_value(::ReactivePowerVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power(d)
get_variable_lower_bound(::ReactivePowerVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power_limits(d).min
get_variable_upper_bound(::ReactivePowerVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power_limits(d).max

############## EnergyVariable, HydroGen ####################
get_variable_binary(::EnergyVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_initial_value(pv::EnergyVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_initial_storage(d)
get_variable_lower_bound(::EnergyVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0
get_variable_upper_bound(::EnergyVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_storage_capacity(d)

########################### EnergyVariableUp, HydroGen #################################

get_variable_binary(::EnergyVariableUp, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false

get_variable_initial_value(pv::EnergyVariableUp, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_initial_storage(d).up

get_variable_lower_bound(::EnergyVariableUp, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0
get_variable_upper_bound(::EnergyVariableUp, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_storage_capacity(d).up

########################### EnergyVariableDown, HydroGen #################################

get_variable_binary(::EnergyVariableDown, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false

get_variable_initial_value(::EnergyVariableDown, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_initial_storage(d).down

get_variable_lower_bound(::EnergyVariableDown, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0
get_variable_upper_bound(::EnergyVariableDown, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_storage_capacity(d).down

########################### ActivePowerInVariable, HydroGen #################################

get_variable_binary(::ActivePowerInVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_expression_name(::ActivePowerInVariable, ::Type{<:PSY.HydroGen}) = :nodal_balance_active

get_variable_lower_bound(::ActivePowerInVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0
get_variable_upper_bound(::ActivePowerInVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = nothing
get_variable_sign(::ActivePowerInVariable, d::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = -1.0

########################### ActivePowerOutVariable, HydroGen #################################

get_variable_binary(::ActivePowerOutVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_expression_name(::ActivePowerOutVariable, ::Type{<:PSY.HydroGen}) = :nodal_balance_active

get_variable_lower_bound(::ActivePowerOutVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0
get_variable_upper_bound(::ActivePowerOutVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = nothing
get_variable_sign(::ActivePowerOutVariable, d::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = 1.0

############## OnVariable, HydroGen ####################

get_variable_binary(::OnVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = true
get_variable_initial_value(::OnVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power(d) > 0 ? 1.0 : 0.0

############## WaterSpillageVariable, HydroGen ####################

get_variable_binary(::WaterSpillageVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_lower_bound(::WaterSpillageVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0

############## ReservationVariable, HydroGen ####################

get_variable_binary(::ReservationVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = true
get_variable_binary(::ReservationVariable, ::Type{<:PSY.HydroPumpedStorage}, ::AbstractHydroFormulation) = true
############## EnergyShortageVariable, HydroGen ####################

get_variable_binary(::EnergyShortageVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_lower_bound(::EnergyShortageVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0
get_variable_upper_bound(::EnergyShortageVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_storage_capacity(d)

############## EnergySurplusVariable, HydroGen ####################

get_variable_binary(::EnergySurplusVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_upper_bound(::EnergySurplusVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0
get_variable_lower_bound(::EnergySurplusVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = - PSY.get_storage_capacity(d)

get_efficiency(v::T, var::Type{<:InitialConditionType}) where T <: PSY.HydroGen = (in = 1.0, out = 1.0)
get_efficiency(v::PSY.HydroPumpedStorage, var::Type{InitialEnergyLevelUp}) = (in = PSY.get_pump_efficiency(v), out = 1.0)
get_efficiency(v::PSY.HydroPumpedStorage, var::Type{InitialEnergyLevelDown}) = (in = 1.0, out = PSY.get_pump_efficiency(v))

#! format: on

"""
This function define the range constraint specs for the
reactive power for dispatch formulations.
"""
function DeviceRangeConstraintSpec(
    ::Type{<:ReactivePowerVariableLimitsConstraint},
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractHydroDispatchFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HydroGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_type = ReactivePowerVariableLimitsConstraint(),
            variable_type = ReactivePowerVariable(),
            limits_func = x -> PSY.get_reactive_power_limits(x),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
            component_type = T,
        ),
    )
end

"""
This function define the range constraint specs for the
active power for dispatch Run of River formulations.
"""
function DeviceRangeConstraintSpec(
    ::Type{<:ActivePowerVariableLimitsConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractHydroDispatchFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HydroGen}
    if !use_parameters && !use_forecasts
        return DeviceRangeConstraintSpec(;
            range_constraint_spec = RangeConstraintSpec(;
                constraint_type = ActivePowerVariableLimitsConstraint(),
                variable_type = ActivePowerVariable(),
                limits_func = x -> (min = 0.0, max = PSY.get_active_power(x)),
                constraint_func = device_range!,
                constraint_struct = DeviceRangeConstraintInfo,
                component_type = T,
            ),
        )
    end

    return DeviceRangeConstraintSpec(;
        timeseries_range_constraint_spec = TimeSeriesConstraintSpec(
            constraint_type = ActivePowerVariableLimitsConstraint(),
            variable_type = ActivePowerVariable(),
            parameter = ActivePowerTimeSeriesParameter("max_active_power"),
            multiplier_func = x -> PSY.get_max_active_power(x),
            constraint_func = use_parameters ? device_timeseries_param_ub! :
                              device_timeseries_ub!,
            component_type = T,
        ),
    )
end

"""
This function define the range constraint specs for the
active power for dispatch Reservoir formulations.
"""
function DeviceRangeConstraintSpec(
    ::Type{<:ActivePowerVariableLimitsConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractHydroReservoirFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HydroGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_type = ActivePowerVariableLimitsConstraint(),
            variable_type = ActivePowerVariable(),
            limits_func = x -> PSY.get_active_power_limits(x),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
            component_type = T,
        ),
    )
end

"""
This function define the range constraint specs for the
active power for commitment formulations (semi continuous).
"""
function DeviceRangeConstraintSpec(
    ::Type{<:ActivePowerVariableLimitsConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractHydroUnitCommitment},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Nothing,
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HydroGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_type = ActivePowerVariableLimitsConstraint(),
            variable_type = ActivePowerVariable(),
            bin_variable_types = [OnVariable()],
            limits_func = x -> PSY.get_active_power_limits(x),
            constraint_func = device_semicontinuousrange!,
            constraint_struct = DeviceRangeConstraintInfo,
            component_type = T,
        ),
    )
end

"""
This function define the range constraint specs for the
reactive power for commitment formulations (semi continuous).
"""
function DeviceRangeConstraintSpec(
    ::Type{<:ReactivePowerVariableLimitsConstraint},
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractHydroUnitCommitment},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Nothing,
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HydroGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_type = ReactivePowerVariableLimitsConstraint(),
            variable_type = ReactivePowerVariable(),
            bin_variable_types = [OnVariable()],
            limits_func = x -> PSY.get_active_power_limits(x),
            constraint_func = device_semicontinuousrange!,
            constraint_struct = DeviceRangeConstraintInfo,
            component_type = T,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:OutputActivePowerVariableLimitsConstraint},
    ::Type{ActivePowerOutVariable},
    ::Type{T},
    ::Type{<:HydroDispatchPumpedStorage},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HydroGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_type = OutputActivePowerVariableLimitsConstraint(),
            variable_type = ActivePowerOutVariable(),
            limits_func = x -> PSY.get_active_power_limits(x),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
            component_type = T,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:InputActivePowerVariableLimitsConstraint},
    ::Type{ActivePowerInVariable},
    ::Type{T},
    ::Type{<:HydroDispatchPumpedStorage},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HydroGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_type = InputActivePowerVariableLimitsConstraint(),
            variable_type = ActivePowerInVariable(),
            limits_func = x -> PSY.get_active_power_limits_pump(x),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
            component_type = T,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:OutputActivePowerVariableLimitsConstraint},
    ::Type{ActivePowerOutVariable},
    ::Type{T},
    ::Type{<:HydroDispatchPumpedStoragewReservation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HydroGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_type = OutputActivePowerVariableLimitsConstraint(),
            variable_type = ActivePowerOutVariable(),
            bin_variable_types = [ReservationVariable()],
            limits_func = x -> PSY.get_active_power_limits(x),
            constraint_func = reserve_device_semicontinuousrange!,
            constraint_struct = DeviceRangeConstraintInfo,
            component_type = T,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:InputActivePowerVariableLimitsConstraint},
    ::Type{ActivePowerInVariable},
    ::Type{T},
    ::Type{<:HydroDispatchPumpedStoragewReservation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HydroGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_type = InputActivePowerVariableLimitsConstraint(),
            variable_type = ActivePowerInVariable(),
            bin_variable_types = [ReservationVariable()],
            limits_func = x -> PSY.get_active_power_limits_pump(x),
            constraint_func = reserve_device_semicontinuousrange!,
            constraint_struct = DeviceRangeConstraintInfo,
            component_type = T,
        ),
    )
end
######################## RoR constraints ############################

"""
This function define the range constraint specs for the
reactive power for Commitment Run of River formulation.
    `` P <= multiplier * P_max ``
"""
function commit_hydro_active_power_ub!(
    optimization_container::OptimizationContainer,
    devices,
    model::DeviceModel{V, W},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HydroGen, W <: AbstractHydroUnitCommitment}
    use_parameters = model_has_parameters(optimization_container)
    use_forecasts = model_uses_forecasts(optimization_container)
    if use_parameters || use_forecasts
        spec = DeviceRangeConstraintSpec(;
            timeseries_range_constraint_spec = TimeSeriesConstraintSpec(
                constraint_type = CommitmentConstraint(),
                variable_type = ActivePowerVariable(),
                parameter = ActivePowerTimeSeriesParameter("max_active_power"),
                multiplier_func = x -> PSY.get_max_active_power(x),
                constraint_func = use_parameters ? device_timeseries_param_ub! :
                                  device_timeseries_ub!,
                component_type = V,
            ),
        )
        device_range_constraints!(optimization_container, devices, model, feedforward, spec)
    end
end

######################## Energy balance constraints ############################

"""
This function defines the constraints for the water level (or state of charge)
for the Hydro Reservoir.
"""
function DeviceEnergyBalanceConstraintSpec(
    ::Type{<:EnergyBalanceConstraint},
    ::Type{EnergyVariable},
    ::Type{H},
    ::Type{<:AbstractHydroFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {H <: PSY.HydroEnergyReservoir}
    return DeviceEnergyBalanceConstraintSpec(;
        constraint_type = EnergyCapacityConstraint(),
        energy_variable = EnergyVariable(),
        initial_condition = InitialEnergyLevel,
        pout_variable_types = [ActivePowerVariable(), WaterSpillageVariable()],
        constraint_func = use_parameters ? energy_balance_param! : energy_balance!,
        component_type = H,
        parameter = InflowTimeSeriesParameter("inflow"),
        multiplier_func = x -> PSY.get_inflow(x) * PSY.get_conversion_factor(x),
    )
end

"""
This function defines the constraints for the water level (or state of charge)
for the HydroPumpedStorage.
"""
function DeviceEnergyBalanceConstraintSpec(
    ::Type{<:EnergyBalanceConstraint},
    ::Type{EnergyVariableUp},
    ::Type{H},
    ::Type{<:AbstractHydroFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {H <: PSY.HydroPumpedStorage}
    return DeviceEnergyBalanceConstraintSpec(;
        constraint_type = EnergyCapacityUpConstraint(),
        energy_variable = EnergyVariableUp(),
        initial_condition = InitialEnergyLevelUp,
        pin_variable_types = [ActivePowerInVariable()],
        pout_variable_types = [ActivePowerOutVariable(), WaterSpillageVariable()],
        constraint_func = use_parameters ? energy_balance_param! : energy_balance!,
        component_type = H,
        parameter = InflowTimeSeriesParameter("inflow"),
        multiplier_func = x -> PSY.get_inflow(x) * PSY.get_conversion_factor(x),
    )
end

function DeviceEnergyBalanceConstraintSpec(
    ::Type{<:EnergyBalanceConstraint},
    ::Type{EnergyVariableDown},
    ::Type{H},
    ::Type{<:AbstractHydroFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {H <: PSY.HydroPumpedStorage}
    return DeviceEnergyBalanceConstraintSpec(;
        constraint_type = EnergyCapacityDownConstraint(),
        energy_variable = EnergyVariableDown(),
        initial_condition = InitialEnergyLevelDown,
        pout_variable_types = [ActivePowerInVariable()],
        pin_variable_types = [ActivePowerOutVariable(), WaterSpillageVariable()],
        constraint_func = use_parameters ? energy_balance_param! : energy_balance!,
        component_type = H,
        parameter = OutflowTimeSeriesParameter("outflow"),
        multiplier_func = x -> PSY.get_outflow(x) * PSY.get_conversion_factor(x),
    )
end

function energy_target_constraint!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, S},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.HydroGen, S <: AbstractHydroFormulation}
    key = ICKey(InitialEnergyLevel, T)
    parameters = model_has_parameters(optimization_container)
    use_forecast_data = model_uses_forecasts(optimization_container)
    time_steps = model_time_steps(optimization_container)
    constraint_infos_target = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    if use_forecast_data
        for (ix, d) in enumerate(devices)
            ts_vector_target = get_time_series(optimization_container, d, "storage_target")
            constraint_info_target = DeviceTimeSeriesConstraintInfo(
                d,
                x -> PSY.get_storage_capacity(x),
                ts_vector_target,
            )
            constraint_infos_target[ix] = constraint_info_target
        end
    else
        for (ix, d) in enumerate(devices)
            ts_vector_target =
                length(time_steps) == 1 ? [PSY.get_storage_target(d)] :
                vcat(zeros(time_steps[end - 1]), PSY.get_storage_target(d))
            constraint_info_target = DeviceTimeSeriesConstraintInfo(
                d,
                x -> PSY.get_storage_capacity(x),
                ts_vector_target,
            )
            constraint_infos_target[ix] = constraint_info_target
        end
    end

    if parameters
        energy_target_param!(
            optimization_container,
            constraint_infos_target,
            EnergyTargetConstraint(),
            (EnergyVariable(), EnergyShortageVariable(), EnergySurplusVariable()),
            EnergyTargetTimeSeriesParameter("storage_target"),
            T,
        )
    else
        energy_target!(
            optimization_container,
            constraint_infos_target,
            EnergyTargetConstraint(),
            (EnergyVariable(), EnergyShortageVariable(), EnergySurplusVariable()),
            T,
        )
    end

    constraint_infos = Vector{DeviceRangeConstraintInfo}()
    for (ix, d) in enumerate(devices)
        op_cost = PSY.get_operation_cost(d)
        if PSY.get_energy_shortage_cost(op_cost) == 0.0
            dev_name = PSY.get_name(d)
            limits = (min = 0.0, max = 0.0)
            constraint_info = DeviceRangeConstraintInfo(dev_name, limits)
            push!(constraint_infos, constraint_info)
            @warn(
                "Device $dev_name has energy shortage cost set to 0.0, as a result the model will turnoff the EnergyShortageVariable to avoid infeasible/unbounded problem."
            )
        end
    end
    if !isempty(constraint_infos)
        device_range!(
            optimization_container,
            RangeConstraintSpecInternal(
                constraint_infos,
                EnergyShortageVariableLimitsConstraint(),
                EnergyShortageVariable(),
                Vector{VariableType}(),
                T,
            ),
        )
    end

    return
end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{H},
    device_formulation::AbstractHydroUnitCommitment,
) where {H <: PSY.HydroGen}
    add_initial_condition!(
        optimization_container,
        devices,
        formulation,
        DeviceStatus,
        OnVariable,
    )
    add_initial_condition!(
        optimization_container,
        devices,
        formulation,
        DevicePower,
        ActivePowerVariable,
    )
    add_initial_condition!(
        optimization_container,
        devices,
        formulation,
        InitialTimeDurationOn,
    )
    add_initial_condition!(
        optimization_container,
        devices,
        formulation,
        InitialTimeDurationOff,
    )

    return
end

function initial_conditions!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{H},
    device_formulation::AbstractHydroDispatchFormulation,
) where {H <: PSY.HydroGen}
    add_initial_condition!(
        optimization_container,
        devices,
        formulation,
        DevicePower,
        ActivePowerVariable,
    )
    return
end

########################## Addition to the nodal balances #################################
function NodalExpressionSpec(
    ::Type{T},
    parameter::ReactivePowerTimeSeriesParameter,
    use_forecasts::Bool,
) where {T <: PSY.HydroGen}
    return NodalExpressionSpec(
        parameter,
        T,
        use_forecasts ? x -> PSY.get_max_reactive_power(x) : x -> PSY.get_reactive_power(x),
        1.0,
        :nodal_balance_reactive,
    )
end

function NodalExpressionSpec(
    ::Type{T},
    parameter::ActivePowerTimeSeriesParameter,
    use_forecasts::Bool,
) where {T <: PSY.HydroGen}
    return NodalExpressionSpec(
        parameter,
        T,
        use_forecasts ? x -> PSY.get_max_active_power(x) : x -> PSY.get_active_power(x),
        1.0,
        :nodal_balance_active,
    )
end

##################################### Water/Energy Budget Constraint ############################
energy_budget_constraints!(
    ::OptimizationContainer,
    ::IS.FlattenIteratorWrapper{<:PSY.HydroGen},
    ::DeviceModel{<:PSY.HydroGen, <:AbstractHydroFormulation},
    ::Type{<:PM.AbstractPowerModel},
    ::IntegralLimitFF,
) = nothing

"""
This function define the budget constraint for the
active power budget formulation.

`` sum(P[t]) <= Budget ``
"""
function energy_budget_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{H},
    ::DeviceModel{H, <:AbstractHydroFormulation},
    ::Type{<:PM.AbstractPowerModel},
    ::Union{Nothing, AbstractAffectFeedForward},
) where {H <: PSY.HydroGen}
    forecast_name = "hydro_budget"
    constraint_data = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(optimization_container, d, forecast_name)
        @debug "time_series" ts_vector
        constraint_d =
            DeviceTimeSeriesConstraintInfo(d, x -> PSY.get_storage_capacity(x), ts_vector)
        constraint_data[ix] = constraint_d
    end

    if model_has_parameters(optimization_container)
        device_energy_budget_param_ub(
            optimization_container,
            constraint_data,
            EnergyBudgetConstraint(),
            EnergyBudgetTimeSeriesParameter("hydro_budget"),
            ActivePowerVariable(),
            H,
        )
    else
        device_energy_budget_ub(
            optimization_container,
            constraint_data,
            EnergyBudgetConstraint(),
            ActivePowerVariable(),
            H,
        )
    end
end

"""
This function define the budget constraint (using params)
for the active power budget formulation.
"""
function device_energy_budget_param_ub(
    optimization_container::OptimizationContainer,
    energy_budget_data::Vector{DeviceTimeSeriesConstraintInfo},
    cons_type::ConstraintType,
    param_type::TimeSeriesParameter,
    var_type::VariableType,
    ::Type{T},
) where {T <: PSY.Component}
    time_steps = model_time_steps(optimization_container)
    resolution = model_resolution(optimization_container)
    inv_dt = 1.0 / (Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR)
    variable_out = get_variable(optimization_container, var_type, T)
    set_name = [get_component_name(r) for r in energy_budget_data]
    constraint = add_cons_container!(optimization_container, cons_type, T, set_name)
    container =
        add_param_container!(optimization_container, param_type, T, set_name, time_steps)
    multiplier = get_multiplier_array(container)
    param = get_parameter_array(container)
    for constraint_info in energy_budget_data
        name = get_component_name(constraint_info)
        for t in time_steps
            multiplier[name, t] = constraint_info.multiplier * inv_dt
            param[name, t] = add_parameter(
                optimization_container.JuMPmodel,
                constraint_info.timeseries[t],
            )
        end
        constraint[name] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            sum([variable_out[name, t] for t in time_steps]) <= sum([multiplier[name, t] * param[name, t] for t in time_steps])
        )
    end

    return
end

"""
This function define the budget constraint
for the active power budget formulation.
"""
function device_energy_budget_ub(
    optimization_container::OptimizationContainer,
    energy_budget_constraints::Vector{DeviceTimeSeriesConstraintInfo},
    cons_type::ConstraintType,
    var_type::VariableType,
    ::Type{T},
) where {T <: PSY.Component}
    time_steps = model_time_steps(optimization_container)
    variable_out = get_variable(optimization_container, var_type, T)
    names = [get_component_name(x) for x in energy_budget_constraints]
    constraint = add_cons_container!(optimization_container, cons_type, T, names)

    for constraint_info in energy_budget_constraints
        name = get_component_name(constraint_info)
        resolution = model_resolution(optimization_container)
        inv_dt = 1.0 / (Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR)
        forecast = constraint_info.timeseries
        multiplier = constraint_info.multiplier * inv_dt
        constraint[name] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            sum([variable_out[name, t] for t in time_steps]) <= multiplier * sum(forecast)
        )
    end

    return
end

##################################### Hydro generation cost ############################
function AddCostSpec(
    ::Type{T},
    ::Type{U},
    ::OptimizationContainer,
) where {T <: PSY.HydroGen, U <: AbstractHydroFormulation}
    # Hydro Generators currently have no OperationalCost
    cost_function = x -> (x === nothing ? 1.0 : PSY.get_variable(x))
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        fixed_cost = PSY.get_fixed,
        variable_cost = cost_function,
        multiplier = OBJECTIVE_FUNCTION_POSITIVE,
    )
end

############################
function AddCostSpec(
    ::Type{T},
    ::Type{U},
    ::OptimizationContainer,
) where {T <: PSY.HydroPumpedStorage, U <: AbstractHydroFormulation}
    # Hydro Generators currently have no OperationalCost
    cost_function = x -> (x === nothing ? 1.0 : PSY.get_variable(x))
    return AddCostSpec(;
        variable_type = ActivePowerOutVariable,
        component_type = T,
        fixed_cost = PSY.get_fixed,
        variable_cost = cost_function,
        multiplier = OBJECTIVE_FUNCTION_POSITIVE,
    )
end
