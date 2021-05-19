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

############## SpillageVariable, HydroGen ####################

get_variable_binary(::SpillageVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_lower_bound(::SpillageVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0

############## ReserveVariable, HydroGen ####################

get_variable_binary(::ReserveVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = true
get_variable_binary(::ReserveVariable, ::Type{<:PSY.HydroPumpedStorage}, ::AbstractHydroFormulation) = true
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
    ::Type{<:RangeConstraint},
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
            constraint_name = make_constraint_name(
                RangeConstraint,
                ReactivePowerVariable,
                T,
            ),
            variable_name = make_variable_name(ReactivePowerVariable, T),
            limits_func = x -> PSY.get_reactive_power_limits(x),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

"""
This function define the range constraint specs for the
active power for dispatch Run of River formulations.
"""
function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
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
                constraint_name = make_constraint_name(
                    RangeConstraint,
                    ActivePowerVariable,
                    T,
                ),
                variable_name = make_variable_name(ActivePowerVariable, T),
                limits_func = x -> (min = 0.0, max = PSY.get_active_power(x)),
                constraint_func = device_range!,
                constraint_struct = DeviceRangeConstraintInfo,
            ),
        )
    end

    return DeviceRangeConstraintSpec(;
        timeseries_range_constraint_spec = TimeSeriesConstraintSpec(
            constraint_name = make_constraint_name(RangeConstraint, ActivePowerVariable, T),
            variable_name = make_variable_name(ActivePowerVariable, T),
            parameter_name = use_parameters ? ACTIVE_POWER : nothing,
            forecast_label = "max_active_power",
            multiplier_func = x -> PSY.get_max_active_power(x),
            constraint_func = use_parameters ? device_timeseries_param_ub! :
                              device_timeseries_ub!,
        ),
    )
end

"""
This function define the range constraint specs for the
active power for dispatch Reservoir formulations.
"""
function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
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
            constraint_name = make_constraint_name(RangeConstraint, ActivePowerVariable, T),
            variable_name = make_variable_name(ActivePowerVariable, T),
            limits_func = x -> PSY.get_active_power_limits(x),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

"""
This function define the range constraint specs for the
active power for commitment formulations (semi continuous).
"""
function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
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
            constraint_name = make_constraint_name(RangeConstraint, ActivePowerVariable, T),
            variable_name = make_variable_name(ActivePowerVariable, T),
            bin_variable_names = [make_variable_name(OnVariable, T)],
            limits_func = x -> PSY.get_active_power_limits(x),
            constraint_func = device_semicontinuousrange!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

"""
This function define the range constraint specs for the
reactive power for commitment formulations (semi continuous).
"""
function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
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
            constraint_name = make_constraint_name(
                RangeConstraint,
                ReactivePowerVariable,
                T,
            ),
            variable_name = make_variable_name(ReactivePowerVariable, T),
            bin_variable_names = [make_variable_name(OnVariable, T)],
            limits_func = x -> PSY.get_active_power_limits(x),
            constraint_func = device_semicontinuousrange!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
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
            constraint_name = make_constraint_name(
                RangeConstraint,
                ActivePowerOutVariable,
                T,
            ),
            variable_name = make_variable_name(ActivePowerOutVariable, T),
            limits_func = x -> PSY.get_active_power_limits(x),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
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
            constraint_name = make_constraint_name(
                RangeConstraint,
                ActivePowerInVariable,
                T,
            ),
            variable_name = make_variable_name(ActivePowerInVariable, T),
            limits_func = x -> PSY.get_active_power_limits_pump(x),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
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
            constraint_name = make_constraint_name(
                RangeConstraint,
                ActivePowerOutVariable,
                T,
            ),
            variable_name = make_variable_name(ActivePowerOutVariable, T),
            bin_variable_names = [make_variable_name(ReserveVariable, T)],
            limits_func = x -> PSY.get_active_power_limits(x),
            constraint_func = reserve_device_semicontinuousrange!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
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
            constraint_name = make_constraint_name(
                RangeConstraint,
                ActivePowerInVariable,
                T,
            ),
            variable_name = make_variable_name(ActivePowerInVariable, T),
            bin_variable_names = [make_variable_name(ReserveVariable, T)],
            limits_func = x -> PSY.get_active_power_limits_pump(x),
            constraint_func = reserve_device_semicontinuousrange!,
            constraint_struct = DeviceRangeConstraintInfo,
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
                constraint_name = make_constraint_name(COMMITMENT, V),
                variable_name = make_variable_name(ActivePowerVariable, V),
                parameter_name = use_parameters ? ACTIVE_POWER : nothing,
                forecast_label = "max_active_power",
                multiplier_func = x -> PSY.get_max_active_power(x),
                constraint_func = use_parameters ? device_timeseries_param_ub! :
                                  device_timeseries_ub!,
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
        constraint_name = make_constraint_name(ENERGY_CAPACITY, H),
        energy_variable = make_variable_name(ENERGY, H),
        initial_condition = InitialEnergyLevel,
        pout_variable_names = [
            make_variable_name(ACTIVE_POWER, H),
            make_variable_name(SPILLAGE, H),
        ],
        constraint_func = use_parameters ? energy_balance_param! : energy_balance!,
        parameter_name = INFLOW,
        forecast_label = "inflow",
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
        constraint_name = make_constraint_name(ENERGY_CAPACITY_UP, H),
        energy_variable = make_variable_name(ENERGY_UP, H),
        initial_condition = InitialEnergyLevelUp,
        pin_variable_names = [make_variable_name(ACTIVE_POWER_IN, H)],
        pout_variable_names = [
            make_variable_name(ACTIVE_POWER_OUT, H),
            make_variable_name(SPILLAGE, H),
        ],
        constraint_func = use_parameters ? energy_balance_param! : energy_balance!,
        parameter_name = INFLOW,
        forecast_label = "inflow",
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
        constraint_name = make_constraint_name(ENERGY_CAPACITY_DOWN, H),
        energy_variable = make_variable_name(ENERGY_DOWN, H),
        initial_condition = InitialEnergyLevelDown,
        pout_variable_names = [make_variable_name(ACTIVE_POWER_IN, H)],
        pin_variable_names = [
            make_variable_name(ACTIVE_POWER_OUT, H),
            make_variable_name(SPILLAGE, H),
        ],
        constraint_func = use_parameters ? energy_balance_param! : energy_balance!,
        parameter_name = OUTFLOW,
        forecast_label = "outflow",
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
    target_forecast_label = "storage_target"
    constraint_infos_target = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    if use_forecast_data
        for (ix, d) in enumerate(devices)
            ts_vector_target =
                get_time_series(optimization_container, d, target_forecast_label)
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
            make_constraint_name(ENERGY_TARGET, T),
            (
                make_variable_name(ENERGY, T),
                make_variable_name(ENERGY_SHORTAGE, T),
                make_variable_name(ENERGY_SURPLUS, T),
            ),
            UpdateRef{T}(TARGET, target_forecast_label),
        )
    else
        energy_target!(
            optimization_container,
            constraint_infos_target,
            make_constraint_name(ENERGY_TARGET, T),
            (
                make_variable_name(ENERGY, T),
                make_variable_name(ENERGY_SHORTAGE, T),
                make_variable_name(ENERGY_SURPLUS, T),
            ),
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
                make_constraint_name(RangeConstraint, EnergyShortageVariable, T),
                make_variable_name(EnergyShortageVariable, T),
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
    status_initial_condition!(optimization_container, devices, device_formulation)
    output_initial_condition!(optimization_container, devices, device_formulation)
    duration_initial_condition!(optimization_container, devices, device_formulation)

    return
end

function initial_conditions!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{H},
    device_formulation::AbstractHydroDispatchFormulation,
) where {H <: PSY.HydroGen}
    output_initial_condition!(optimization_container, devices, device_formulation)

    return
end

######################### Initialize Functions for Hydro #################################
function status_initial_condition!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::D,
) where {T <: PSY.HydroGen, D <: AbstractHydroUnitCommitment}
    _make_initial_conditions!(
        optimization_container,
        devices,
        D(),
        OnVariable(),
        ICKey(DeviceStatus, T),
        _make_initial_condition_active_power,
        _get_variable_initial_value,
        # Doesn't require Cache
    )
end

function output_initial_condition!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::D,
) where {T <: PSY.HydroGen, D <: AbstractHydroFormulation}
    _make_initial_conditions!(
        optimization_container,
        devices,
        D(),
        ActivePowerVariable(),
        ICKey(DevicePower, T),
        _make_initial_condition_active_power,
        _get_variable_initial_value,
        # Doesn't require Cache
    )

    return
end

function duration_initial_condition!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::D,
) where {T <: PSY.HydroGen, D <: AbstractHydroUnitCommitment}
    for key in (ICKey(InitialTimeDurationOn, T), ICKey(InitialTimeDurationOff, T))
        _make_initial_conditions!(
            optimization_container,
            devices,
            D(),
            nothing,
            key,
            _make_initial_condition_active_power,
            _get_variable_initial_value,
            TimeStatusChange,
        )
    end

    return
end

function storage_energy_initial_condition!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::D,
) where {T <: PSY.HydroGen, D <: AbstractHydroFormulation}
    key = ICKey(InitialEnergyLevel, T)
    _make_initial_conditions!(
        optimization_container,
        devices,
        D(),
        EnergyVariable(),
        key,
        _make_initial_condition_reservoir_energy,
        _get_variable_initial_value,
        StoredEnergy,
    )

    return
end

function storage_energy_initial_condition!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::D,
) where {T <: PSY.HydroPumpedStorage, D <: AbstractHydroFormulation}
    key_up = ICKey(InitialEnergyLevelUp, T)
    _make_initial_conditions!(
        optimization_container,
        devices,
        D(),
        EnergyVariableUp(),
        key_up,
        _make_initial_condition_reservoir_energy_up,
        _get_variable_initial_value,
        StoredEnergy,
    )

    key_down = ICKey(InitialEnergyLevelDown, T)
    _make_initial_conditions!(
        optimization_container,
        devices,
        D(),
        EnergyVariableDown(),
        key_down,
        _make_initial_condition_reservoir_energy_down,
        _get_variable_initial_value,
        StoredEnergy,
    )

    return
end

########################## Addition to the nodal balances #################################

function NodalExpressionSpec(
    ::Type{T},
    ::Type{<:PM.AbstractPowerModel},
    use_forecasts::Bool,
) where {T <: PSY.HydroGen}
    return NodalExpressionSpec(
        "max_active_power",
        REACTIVE_POWER,
        use_forecasts ? x -> PSY.get_max_reactive_power(x) : x -> PSY.get_reactive_power(x),
        1.0,
        T,
    )
end

function NodalExpressionSpec(
    ::Type{T},
    ::Type{<:PM.AbstractActivePowerModel},
    use_forecasts::Bool,
) where {T <: PSY.HydroGen}
    return NodalExpressionSpec(
        "max_active_power",
        ACTIVE_POWER,
        use_forecasts ? x -> PSY.get_max_active_power(x) : x -> PSY.get_active_power(x),
        1.0,
        T,
    )
end

##################################### Water/Energy Budget Constraint ############################
function energy_budget_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{H, <:AbstractHydroFormulation},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::IntegralLimitFF,
) where {H <: PSY.HydroGen}
    return
end

"""
This function define the budget constraint for the
active power budget formulation.

`` sum(P[t]) <= Budget ``
"""
function energy_budget_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{H, <:AbstractHydroFormulation},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {H <: PSY.HydroGen}
    forecast_label = "hydro_budget"
    constraint_data = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(optimization_container, d, forecast_label)
        @debug "time_series" ts_vector
        constraint_d =
            DeviceTimeSeriesConstraintInfo(d, x -> PSY.get_storage_capacity(x), ts_vector)
        constraint_data[ix] = constraint_d
    end

    if model_has_parameters(optimization_container)
        device_energy_budget_param_ub(
            optimization_container,
            constraint_data,
            make_constraint_name(ENERGY_BUDGET, H),
            UpdateRef{H}(ENERGY_BUDGET, forecast_label),
            make_variable_name(ACTIVE_POWER, H),
        )
    else
        device_energy_budget_ub(
            optimization_container,
            constraint_data,
            make_constraint_name(ENERGY_BUDGET),
            make_variable_name(ACTIVE_POWER, H),
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
    cons_name::Symbol,
    param_reference::UpdateRef,
    var_names::Symbol,
)
    time_steps = model_time_steps(optimization_container)
    resolution = model_resolution(optimization_container)
    inv_dt = 1.0 / (Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR)
    variable_out = get_variable(optimization_container, var_names)
    set_name = [get_component_name(r) for r in energy_budget_data]
    constraint = add_cons_container!(optimization_container, cons_name, set_name)
    container =
        add_param_container!(optimization_container, param_reference, set_name, time_steps)
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
    cons_name::Symbol,
    var_names::Symbol,
)
    time_steps = model_time_steps(optimization_container)
    variable_out = get_variable(optimization_container, var_names)
    names = [get_component_name(x) for x in energy_budget_constraints]
    constraint = add_cons_container!(optimization_container, cons_name, names)

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

#TODO: check this out
# function cost_function!(
#     optimization_container::OptimizationContainer,
#     devices::IS.FlattenIteratorWrapper{PSY.HydroEnergyReservoir},
#     device_formulation::Type{D},
#     system_formulation::Type{<:PM.AbstractPowerModel},
# ) where {D <: AbstractHydroFormulation}
#     add_to_cost!(
#         optimization_container,
#         devices,
#         make_variable_name(ACTIVE_POWER, PSY.HydroEnergyReservoir),
#         :fixed,
#         1.0,
#     )

#     return
# end

function cost_function!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{H},
    device_formulation::Type{D},
    system_formulation::Type{<:PM.AbstractPowerModel},
) where {D <: AbstractHydroFormulation, H <: PSY.HydroGen}
    return
end
