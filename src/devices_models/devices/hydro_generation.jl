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

########################### ActivePowerVariable, HydroGen #################################

get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.HydroGen}) = false
get_variable_expression_name(::ActivePowerVariable, ::Type{<:PSY.HydroGen}) = :nodal_balance_active

get_variable_initial_value(pv::ActivePowerVariable, d::PSY.HydroGen, settings) =
    get_variable_initial_value(pv, d, get_warm_start(settings) ? WarmStartVariable() : ColdStartVariable())
get_variable_initial_value(::ActivePowerVariable, d::PSY.HydroGen, ::WarmStartVariable) = PSY.get_active_power(d)
get_variable_initial_value(::ActivePowerVariable, d::PSY.HydroGen, ::ColdStartVariable) = nothing

get_variable_lower_bound(::ActivePowerVariable, d::PSY.HydroGen, _) = PSY.get_active_power_limits(d).min
get_variable_upper_bound(::ActivePowerVariable, d::PSY.HydroGen, _) = PSY.get_active_power_limits(d).max

############## ReactivePowerVariable, HydroGen ####################

get_variable_binary(::ReactivePowerVariable, ::Type{<:PSY.HydroGen}) = false

get_variable_expression_name(::ReactivePowerVariable, ::Type{<:PSY.HydroGen}) = :nodal_balance_reactive

get_variable_initial_value(pv::ReactivePowerVariable, d::PSY.HydroGen, settings) =
get_variable_initial_value(pv, d, get_warm_start(settings) ? WarmStartVariable() : ColdStartVariable())
get_variable_initial_value(::ReactivePowerVariable, d::PSY.HydroGen, ::WarmStartVariable) = PSY.get_active_power(d)
get_variable_initial_value(::ReactivePowerVariable, d::PSY.HydroGen, ::ColdStartVariable) = nothing

get_variable_lower_bound(::ReactivePowerVariable, d::PSY.HydroGen, _) = PSY.get_active_power_limits(d).min
get_variable_upper_bound(::ReactivePowerVariable, d::PSY.HydroGen, _) = PSY.get_active_power_limits(d).max


############## EnergyVariable, HydroGen ####################

get_variable_binary(::EnergyVariable, ::Type{<:PSY.HydroGen}) = false
get_variable_initial_value(pv::EnergyVariable, d::PSY.HydroGen, settings) = PSY.get_initial_storage(d)
get_variable_lower_bound(::EnergyVariable, d::PSY.HydroGen, _) = 0.0
get_variable_upper_bound(::EnergyVariable, d::PSY.HydroGen, _) = PSY.get_storage_capacity(d)

########################### EnergyVariableUp, HydroGen #################################

get_variable_binary(::EnergyVariableUp, ::Type{<:PSY.HydroGen}) = false

get_variable_initial_value(pv::EnergyVariableUp, d::PSY.HydroGen, settings) = PSY.get_initial_storage(d).up

get_variable_lower_bound(::EnergyVariableUp, d::PSY.HydroGen, _) = 0.0
get_variable_upper_bound(::EnergyVariableUp, d::PSY.HydroGen, _) = PSY.get_storage_capacity(d).up

########################### EnergyVariableDown, HydroGen #################################

get_variable_binary(::EnergyVariableDown, ::Type{<:PSY.HydroGen}) = false

get_variable_initial_value(pv::EnergyVariableDown, d::PSY.HydroGen, settings) = PSY.get_initial_storage(d).down

get_variable_lower_bound(::EnergyVariableDown, d::PSY.HydroGen, _) = 0.0
get_variable_upper_bound(::EnergyVariableDown, d::PSY.HydroGen, _) = PSY.get_storage_capacity(d).down

########################### ActivePowerInVariable, HydroGen #################################

get_variable_binary(::ActivePowerInVariable, ::Type{<:PSY.HydroGen}) = false
get_variable_expression_name(::ActivePowerInVariable, ::Type{<:PSY.HydroGen}) = :nodal_balance_active

get_variable_lower_bound(::ActivePowerInVariable, d::PSY.HydroGen, _) = 0.0
get_variable_upper_bound(::ActivePowerInVariable, d::PSY.HydroGen, _) = nothing
get_variable_sign(::ActivePowerInVariable, d::PSY.HydroGen) = -1.0

########################### ActivePowerOutVariable, HydroGen #################################

get_variable_binary(::ActivePowerOutVariable, ::Type{<:PSY.HydroGen}) = false
get_variable_expression_name(::ActivePowerOutVariable, ::Type{<:PSY.HydroGen}) = :nodal_balance_active

get_variable_lower_bound(::ActivePowerOutVariable, d::PSY.HydroGen, _) = 0.0
get_variable_upper_bound(::ActivePowerOutVariable, d::PSY.HydroGen, _) = nothing
get_variable_sign(::ActivePowerOutVariable, d::PSY.HydroGen) = -1.0

############## OnVariable, HydroGen ####################

get_variable_binary(::OnVariable, ::Type{<:PSY.HydroGen}) = true

get_variable_initial_value(pv::OnVariable, d::PSY.HydroGen, settings) =
    get_variable_initial_value(pv, d, get_warm_start(settings) ? WarmStartVariable() : ColdStartVariable())
get_variable_initial_value(::OnVariable, d::PSY.HydroGen, ::WarmStartVariable) = PSY.get_active_power(d) > 0 ? 1.0 : 0.0
get_variable_initial_value(::OnVariable, d::PSY.HydroGen, ::ColdStartVariable) = nothing

############## SpillageVariable, HydroGen ####################

get_variable_binary(::SpillageVariable, ::Type{<:PSY.HydroGen}) = false
get_variable_lower_bound(::SpillageVariable, d::PSY.HydroGen, _) = 0.0

############## ReserveVariable, HydroGen ####################

get_variable_binary(::ReserveVariable, ::Type{<:PSY.HydroGen}) = true
get_variable_binary(::ReserveVariable, ::Type{<:PSY.HydroPumpedStorage}) = true

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
    psi_container::PSIContainer,
    devices,
    model::DeviceModel{V, W},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HydroGen, W <: AbstractHydroUnitCommitment}
    use_parameters = model_has_parameters(psi_container)
    use_forecasts = model_uses_forecasts(psi_container)
    if use_parameters || use_forecasts
        spec = DeviceRangeConstraintSpec(;
            timeseries_range_constraint_spec = TimeSeriesConstraintSpec(
                constraint_name = make_constraint_name(
                    RangeConstraint,
                    ActivePowerVariable,
                    V,
                ),
                variable_name = make_variable_name(ActivePowerVariable, V),
                parameter_name = use_parameters ? ACTIVE_POWER : nothing,
                forecast_label = "max_active_power",
                multiplier_func = x -> PSY.get_max_active_power(x),
                constraint_func = use_parameters ? device_timeseries_param_ub! :
                                  device_timeseries_ub!,
            ),
        )
        device_range_constraints!(psi_container, devices, model, feedforward, spec)
    end
end

######################## Energy balance constraints ############################

"""
This function defines the constraints for the water level (or state of charge)
for the Hydro Reservoir.
"""
function energy_balance_constraint!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{H, S},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    H <: PSY.HydroEnergyReservoir,
    S <: Union{HydroDispatchReservoirStorage, HydroCommitmentReservoirStorage},
}
    key = ICKey(EnergyLevel, H)
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    if !has_initial_conditions(psi_container.initial_conditions, key)
        throw(IS.DataFormatError("Initial Conditions for $(H) Energy Constraints not in the model"))
    end

    inflow_forecast_label = "inflow"
    target_forecast_label = "storage_target"
    constraint_infos_inflow = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    constraint_infos_target = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector_inflow = get_time_series(psi_container, d, inflow_forecast_label)
        constraint_info_inflow = DeviceTimeSeriesConstraintInfo(
            d,
            x -> PSY.get_inflow(x) * PSY.get_conversion_factor(x),
            ts_vector_inflow,
        )
        add_device_services!(constraint_info_inflow.range, d, model)
        constraint_infos_inflow[ix] = constraint_info_inflow

        ts_vector_target = get_time_series(psi_container, d, target_forecast_label)
        constraint_info_target = DeviceTimeSeriesConstraintInfo(
            d,
            x -> PSY.get_storage_target(x) * PSY.get_storage_capacity(x),
            ts_vector_target,
        )
        constraint_infos_target[ix] = constraint_info_target
    end

    if parameters
        energy_balance_hydro_param!(
            psi_container,
            get_initial_conditions(psi_container, key),
            (constraint_infos_inflow, constraint_infos_target),
            (
                make_constraint_name(ENERGY_CAPACITY, H),
                make_constraint_name(ENERGY_TARGET, H),
            ),
            (
                make_variable_name(SPILLAGE, H),
                make_variable_name(ACTIVE_POWER, H),
                make_variable_name(ENERGY, H),
            ),
            (
                UpdateRef{H}(INFLOW, inflow_forecast_label),
                UpdateRef{H}(TARGET, target_forecast_label),
            ),
        )
    else
        energy_balance_hydro!(
            psi_container,
            get_initial_conditions(psi_container, key),
            (constraint_infos_inflow, constraint_infos_target),
            (
                make_constraint_name(ENERGY_CAPACITY, H),
                make_constraint_name(ENERGY_TARGET, H),
            ),
            (
                make_variable_name(SPILLAGE, H),
                make_variable_name(ACTIVE_POWER, H),
                make_variable_name(ENERGY, H),
            ),
        )
    end
    return
end

"""
This function defines the constraints for the water level (or state of charge)
for the HydroPumpedStorage.
"""
function energy_balance_constraint!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{H, S},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    H <: PSY.HydroPumpedStorage,
    S <: Union{HydroDispatchPumpedStorage, HydroDispatchPumpedStoragewReservation},
}
    key = ICKey(EnergyLevelUP, H)
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    if !has_initial_conditions(psi_container.initial_conditions, key)
        throw(IS.DataFormatError("Initial Conditions for $(H) Energy Constraints not in the model"))
    end

    forecast_label_in = "inflow"
    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label_in)
        constraint_info = DeviceTimeSeriesConstraintInfo(
            d,
            x -> PSY.get_inflow(x) * PSY.get_conversion_factor(x),
            ts_vector,
        )
        add_device_services!(constraint_info.range, d, model)
        constraint_infos[ix] = constraint_info
    end

    forecast_label_out = "outflow"
    constraint_infos_outflow =
        Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label_out)
        constraint_info = DeviceTimeSeriesConstraintInfo(
            d,
            x -> PSY.get_outflow(x) * PSY.get_conversion_factor(x),
            ts_vector,
        )
        add_device_services!(constraint_info.range, d, model)
        constraint_infos_outflow[ix] = constraint_info
    end

    if parameters
        energy_balance_hydro_param!(
            psi_container,
            get_initial_conditions(psi_container, key),
            (constraint_infos, constraint_infos_outflow),
            (
                make_constraint_name(ENERGY_CAPACITY_UP, H),
                make_constraint_name(ENERGY_CAPACITY_DOWN, H),
            ),
            (
                make_variable_name(SPILLAGE, H),
                make_variable_name(ACTIVE_POWER_OUT, H),
                make_variable_name(ENERGY_UP, H),
                make_variable_name(ACTIVE_POWER_IN, H),
                make_variable_name(ENERGY_DOWN, H),
            ),
            (
                UpdateRef{H}(INFLOW, forecast_label_in),
                UpdateRef{H}(OUTFLOW, forecast_label_out),
            ),
        )
    else
        energy_balance_hydro!(
            psi_container,
            get_initial_conditions(psi_container, key),
            (constraint_infos, constraint_infos_outflow),
            (
                make_constraint_name(ENERGY_CAPACITY_UP, H),
                make_constraint_name(ENERGY_CAPACITY_DOWN, H),
            ),
            (
                make_variable_name(SPILLAGE, H),
                make_variable_name(ACTIVE_POWER_OUT, H),
                make_variable_name(ENERGY_UP, H),
                make_variable_name(ACTIVE_POWER_IN, H),
                make_variable_name(ENERGY_DOWN, H),
            ),
        )
    end
    return
end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    device_formulation::Type{<:AbstractHydroUnitCommitment},
) where {H <: PSY.HydroGen}
    status_init(psi_container, devices)
    output_init(psi_container, devices)
    duration_init(psi_container, devices)

    return
end

function initial_conditions!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    device_formulation::Type{D},
) where {H <: PSY.HydroGen, D <: AbstractHydroDispatchFormulation}
    output_init(psi_container, devices)

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

function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.HydroEnergyReservoir},
    device_formulation::Type{D},
    system_formulation::Type{<:PM.AbstractPowerModel},
) where {D <: AbstractHydroFormulation}
    add_to_cost!(
        psi_container,
        devices,
        make_variable_name(ACTIVE_POWER, PSY.HydroEnergyReservoir),
        :fixed,
        -1.0,
    )

    return
end

function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    device_formulation::Type{D},
    system_formulation::Type{<:PM.AbstractPowerModel},
) where {D <: AbstractHydroFormulation, H <: PSY.HydroGen}
    return
end

##################################### Water/Energy Budget Constraint ############################
function energy_budget_constraints!(
    psi_container::PSIContainer,
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
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{H, <:AbstractHydroFormulation},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {H <: PSY.HydroGen}
    forecast_label = "hydro_budget"
    constraint_data = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        constraint_d =
            DeviceTimeSeriesConstraintInfo(d, x -> PSY.get_storage_capacity(x), ts_vector)
        constraint_data[ix] = constraint_d
    end

    if model_has_parameters(psi_container)
        device_energy_budget_param_ub(
            psi_container,
            constraint_data,
            make_constraint_name(ENERGY_BUDGET, H),
            UpdateRef{H}(ENERGY_BUDGET, forecast_label),
            make_variable_name(ACTIVE_POWER, H),
        )
    else
        device_energy_budget_ub(
            psi_container,
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
    psi_container::PSIContainer,
    energy_budget_data::Vector{DeviceTimeSeriesConstraintInfo},
    cons_name::Symbol,
    param_reference::UpdateRef,
    var_names::Symbol,
)
    time_steps = model_time_steps(psi_container)
    resolution = model_resolution(psi_container)
    inv_dt = 1.0 / (Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR)
    variable_out = get_variable(psi_container, var_names)
    set_name = [get_component_name(r) for r in energy_budget_data]
    constraint = add_cons_container!(psi_container, cons_name, set_name)
    container = add_param_container!(psi_container, param_reference, set_name, 1)
    multiplier = get_multiplier_array(container)
    param = get_parameter_array(container)
    for constraint_info in energy_budget_data
        name = get_component_name(constraint_info)
        multiplier[name, 1] = constraint_info.multiplier * inv_dt
        param[name, 1] =
            PJ.add_parameter(psi_container.JuMPmodel, sum(constraint_info.timeseries))
        constraint[name] = JuMP.@constraint(
            psi_container.JuMPmodel,
            sum([variable_out[name, t] for t in time_steps]) <= multiplier[name, 1] * param[name, 1]
        )
    end

    return
end

"""
This function define the budget constraint
for the active power budget formulation.
"""
function device_energy_budget_ub(
    psi_container::PSIContainer,
    energy_budget_constraints::Vector{DeviceTimeSeriesConstraintInfo},
    cons_name::Symbol,
    var_names::Symbol,
)
    time_steps = model_time_steps(psi_container)
    variable_out = get_variable(psi_container, var_names)
    names = [get_component_name(x) for x in energy_budget_constraints]
    constraint = add_cons_container!(psi_container, cons_name, names)

    for constraint_info in energy_budget_constraints
        name = get_component_name(constraint_info)
        resolution = model_resolution(psi_container)
        inv_dt = 1.0 / (Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR)
        forecast = constraint_info.timeseries
        multiplier = constraint_info.multiplier * inv_dt
        constraint[name] = JuMP.@constraint(
            psi_container.JuMPmodel,
            sum([variable_out[name, t] for t in time_steps]) <= multiplier * sum(forecast)
        )
    end

    return
end

##################################### Hydro generation cost ############################
function AddCostSpec(
    ::Type{T},
    ::Type{U},
    ::PSIContainer,
) where {T <: PSY.HydroDispatch, U <: AbstractHydroFormulation}
    # Hydro Generators currently have no OperationalCost
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        fixed_cost = x -> 1.0,
        multiplier = OBJECTIVE_FUNCTION_NEGATIVE,
    )
end

############################
function AddCostSpec(
    ::Type{T},
    ::Type{U},
    ::PSIContainer,
) where {T <: PSY.HydroGen, U <: AbstractHydroFormulation}
    # Hydro Generators currently have no OperationalCost
    cost_function = x -> isnothing(x) ? 1.0 : PSY.get_variable(x)
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        fixed_cost = PSY.get_fixed,
        variable_cost = cost_function,
        multiplier = OBJECTIVE_FUNCTION_POSITIVE,
    )
end
