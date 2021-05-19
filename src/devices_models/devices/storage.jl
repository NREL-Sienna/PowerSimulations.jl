#! format: off

abstract type AbstractStorageFormulation <: AbstractDeviceFormulation end
abstract type AbstractEnergyManagement  <: AbstractStorageFormulation end
struct BookKeeping <: AbstractStorageFormulation end
struct BookKeepingwReservation <: AbstractStorageFormulation end
struct BatteryAncialliryServices <: AbstractStorageFormulation end
struct EnergyTarget <: AbstractEnergyManagement end

get_variable_sign(_, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = NaN
########################### ActivePowerInVariable, Storage #################################

get_variable_binary(::ActivePowerInVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = false
get_variable_expression_name(::ActivePowerInVariable, ::Type{<:PSY.Storage}) = :nodal_balance_active

get_variable_lower_bound(::ActivePowerInVariable, d::PSY.Storage, ::AbstractStorageFormulation) = 0.0
get_variable_upper_bound(::ActivePowerInVariable, d::PSY.Storage, ::AbstractStorageFormulation) = PSY.get_input_active_power_limits(d).max
get_variable_sign(::ActivePowerInVariable, d::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = -1.0

########################### ActivePowerOutVariable, Storage #################################

get_variable_binary(::ActivePowerOutVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = false
get_variable_expression_name(::ActivePowerOutVariable, ::Type{<:PSY.Storage}) = :nodal_balance_active

get_variable_lower_bound(::ActivePowerOutVariable, d::PSY.Storage, ::AbstractStorageFormulation) = 0.0
get_variable_upper_bound(::ActivePowerOutVariable, d::PSY.Storage, ::AbstractStorageFormulation) = PSY.get_output_active_power_limits(d).max
get_variable_sign(::ActivePowerOutVariable, d::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = 1.0

############## ReactivePowerVariable, Storage ####################
get_variable_sign(::PowerSimulations.ReactivePowerVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = 1.0
get_variable_binary(::ReactivePowerVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = false
get_variable_expression_name(::ReactivePowerVariable, ::Type{<:PSY.Storage}) = :nodal_balance_reactive

############## EnergyVariable, Storage ####################

get_variable_binary(::EnergyVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = false
get_variable_lower_bound(::EnergyVariable, d::PSY.Storage, ::AbstractStorageFormulation) = 0.0
get_variable_initial_value(::EnergyVariable, d::PSY.Storage, ::AbstractStorageFormulation) = PSY.get_initial_energy(d)

############## ReserveVariable, Storage ####################

get_variable_binary(::ReserveVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = true

get_target_multiplier(v::PSY.BatteryEMS) = PSY.get_rating(v)
get_efficiency(v::T, var::Type{<:InitialConditionType}) where T <: PSY.Storage = PSY.get_efficiency(v)

############## EnergyShortageVariable, Storage ####################

get_variable_binary(::EnergyShortageVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = false
get_variable_lower_bound(::EnergyShortageVariable, d::PSY.Storage, ::AbstractStorageFormulation) = 0.0
get_variable_upper_bound(::EnergyShortageVariable, d::PSY.HydroGen, ::AbstractStorageFormulation) = PSY.get_rating(d)

############## EnergySlackDown, Storage ####################

get_variable_binary(::EnergySurplusVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = false
get_variable_upper_bound(::EnergySurplusVariable, d::PSY.Storage, ::AbstractStorageFormulation) = 0.0
get_variable_lower_bound(::EnergySurplusVariable, d::PSY.HydroGen, ::AbstractStorageFormulation) = - PSY.get_rating(d)
#! format: on

################################## output power constraints#################################

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ActivePowerOutVariable},
    ::Type{T},
    ::Type{<:BookKeeping},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.Storage}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(
                RangeConstraint,
                ActivePowerOutVariable,
                T,
            ),
            variable_name = make_variable_name(ActivePowerOutVariable, T),
            limits_func = x -> PSY.get_output_active_power_limits(x),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ActivePowerInVariable},
    ::Type{T},
    ::Type{<:BookKeeping},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.Storage}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(
                RangeConstraint,
                ActivePowerInVariable,
                T,
            ),
            variable_name = make_variable_name(ActivePowerInVariable, T),
            limits_func = x -> PSY.get_input_active_power_limits(x),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ActivePowerOutVariable},
    ::Type{T},
    ::Type{<:AbstractStorageFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.Storage}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(
                RangeConstraint,
                ActivePowerOutVariable,
                T,
            ),
            variable_name = make_variable_name(ActivePowerOutVariable, T),
            bin_variable_names = [make_variable_name(ReserveVariable, T)],
            limits_func = x -> PSY.get_output_active_power_limits(x),
            constraint_func = device_semicontinuousrange!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ActivePowerInVariable},
    ::Type{T},
    ::Type{<:AbstractStorageFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.Storage}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(
                RangeConstraint,
                ActivePowerInVariable,
                T,
            ),
            variable_name = make_variable_name(ActivePowerInVariable, T),
            bin_variable_names = [make_variable_name(ReserveVariable, T)],
            limits_func = x -> PSY.get_input_active_power_limits(x),
            constraint_func = reserve_device_semicontinuousrange!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function add_constraints!(
    optimization_container::OptimizationContainer,
    ::Type{<:RangeConstraint},
    ::Type{ReactivePowerVariable},
    devices::IS.FlattenIteratorWrapper{St},
    model::DeviceModel{St, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation, S <: PM.AbstractPowerModel}
    constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        limits = PSY.get_reactive_power_limits(d)
        constraint_infos[ix] = DeviceRangeConstraintInfo(name, limits)
    end

    device_range!(
        optimization_container,
        RangeConstraintSpecInternal(
            constraint_infos,
            make_constraint_name(RangeConstraint, ReactivePowerVariable, St),
            make_variable_name(ReactivePowerVariable, St),
        ),
    )
    return
end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{St},
    formulation::AbstractStorageFormulation,
) where {St <: PSY.Storage}
    storage_energy_initial_condition!(optimization_container, devices, formulation)
    return
end

######################### Initialize Functions for Storage #################################
# TODO: This IC needs a cache for Simulation over long periods of tim
function storage_energy_initial_condition!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::D,
) where {T <: PSY.Storage, D <: AbstractStorageFormulation}
    key = ICKey(InitialEnergyLevel, T)
    _make_initial_conditions!(
        optimization_container,
        devices,
        D(),
        EnergyVariable(),
        key,
        _make_initial_condition_energy,
        _get_variable_initial_value,
        StoredEnergy,
    )

    return
end

############################ Energy Capacity Constraints####################################
function energy_capacity_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{St},
    model::DeviceModel{St, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation, S <: PM.AbstractPowerModel}
    constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        limits = PSY.get_state_of_charge_limits(d)
        constraint_info = DeviceRangeConstraintInfo(name, limits)
        add_device_services!(constraint_info, d, model)
        constraint_infos[ix] = constraint_info
    end

    device_range!(
        optimization_container,
        RangeConstraintSpecInternal(
            constraint_infos,
            make_constraint_name(ENERGY_CAPACITY, St),
            make_variable_name(ENERGY, St),
        ),
    )
    return
end

############################ book keeping constraints ######################################

function DeviceEnergyBalanceConstraintSpec(
    ::Type{<:EnergyBalanceConstraint},
    ::Type{EnergyVariable},
    ::Type{St},
    ::Type{<:AbstractStorageFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {St <: PSY.Storage}
    return DeviceEnergyBalanceConstraintSpec(;
        constraint_name = make_constraint_name(ENERGY_LIMIT, St),
        energy_variable = make_variable_name(ENERGY, St),
        initial_condition = InitialEnergyLevel,
        pin_variable_names = [make_variable_name(ACTIVE_POWER_IN, St)],
        pout_variable_names = [make_variable_name(ACTIVE_POWER_OUT, St)],
        constraint_func = energy_balance!,
    )
end

############################ reserve constraints ######################################

function reserve_contribution_constraint!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.Storage, D <: AbstractStorageFormulation}
    constraint_infos_up = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    constraint_infos_dn = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    constraint_infos_energy = Vector{ReserveRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        up_info = DeviceRangeConstraintInfo(name, PSY.get_output_active_power_limits(d))
        down_info = DeviceRangeConstraintInfo(name, PSY.get_input_active_power_limits(d))
        energy_info = ReserveRangeConstraintInfo(
            name,
            PSY.get_state_of_charge_limits(d),
            PSY.get_efficiency(d),
        )
        add_device_services!(up_info, down_info, d, model)
        add_device_services!(energy_info, d, model)
        constraint_infos_energy[ix] = energy_info
        constraint_infos_up[ix] = up_info
        constraint_infos_dn[ix] = down_info
    end

    reserve_power_ub!(
        optimization_container,
        constraint_infos_up,
        constraint_infos_dn,
        make_constraint_name(RESERVE_POWER, T),
        (make_variable_name(ACTIVE_POWER_IN, T), make_variable_name(ACTIVE_POWER_OUT, T)),
    )

    reserve_energy_ub!(
        optimization_container,
        constraint_infos_energy,
        make_constraint_name(RESERVE_ENERGY, T),
        make_variable_name(ENERGY, T),
    )

    return
end

############################ Energy Management constraints ######################################

function energy_target_constraint!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, EnergyTarget},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.Storage}
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
            constraint_info_target =
                DeviceTimeSeriesConstraintInfo(d, x -> PSY.get_rating(x), ts_vector_target)
            constraint_infos_target[ix] = constraint_info_target
        end
    else
        for (ix, d) in enumerate(devices)
            ts_vector_target =
                length(time_steps) == 1 ? [PSY.get_storage_target(d)] :
                vcat(zeros(time_steps[end - 1]), PSY.get_storage_target(d))
            constraint_info_target =
                DeviceTimeSeriesConstraintInfo(d, x -> PSY.get_rating(x), ts_vector_target)
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

function AddCostSpec(
    ::Type{PSY.BatteryEMS},
    ::Type{EnergyTarget},
    optimization_container::OptimizationContainer,
)
    return AddCostSpec(;
        variable_type = ActivePowerOutVariable,
        component_type = PSY.BatteryEMS,
        variable_cost = PSY.get_variable,
        multiplier = OBJECTIVE_FUNCTION_POSITIVE,
    )
end
