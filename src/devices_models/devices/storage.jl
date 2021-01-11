#! format: off

abstract type AbstractStorageFormulation <: AbstractDeviceFormulation end
struct BookKeeping <: AbstractStorageFormulation end
struct BookKeepingwReservation <: AbstractStorageFormulation end
struct BookKeepingwTarget <: AbstractStorageFormulation end
struct BookKeepingwTargetTimeSeries <: AbstractStorageFormulation end
struct BookKeepingwSoftTarget <: AbstractStorageFormulation end
struct BookKeepingwSoftTargetTimeSeries <: AbstractStorageFormulation end
struct BookKeepingwEnergyValue <: AbstractStorageFormulation end
########################### ActivePowerInVariable, Storage #################################

get_variable_binary(::ActivePowerInVariable, ::Type{<:PSY.Storage}) = false
get_variable_expression_name(::ActivePowerInVariable, ::Type{<:PSY.Storage}) = :nodal_balance_active

get_variable_lower_bound(::ActivePowerInVariable, d::PSY.Storage, _) = 0.0
get_variable_upper_bound(::ActivePowerInVariable, d::PSY.Storage, _) = nothing
get_variable_sign(::ActivePowerInVariable, d::PSY.Storage) = -1.0

########################### ActivePowerOutVariable, Storage #################################

get_variable_binary(::ActivePowerOutVariable, ::Type{<:PSY.Storage}) = false
get_variable_expression_name(::ActivePowerOutVariable, ::Type{<:PSY.Storage}) = :nodal_balance_active

get_variable_lower_bound(::ActivePowerOutVariable, d::PSY.Storage, _) = 0.0
get_variable_upper_bound(::ActivePowerOutVariable, d::PSY.Storage, _) = nothing
get_variable_sign(::ActivePowerOutVariable, d::PSY.Storage) = -1.0

############## ReactivePowerVariable, Storage ####################

get_variable_binary(::ReactivePowerVariable, ::Type{<:PSY.Storage}) = false

get_variable_expression_name(::ReactivePowerVariable, ::Type{<:PSY.Storage}) = :nodal_balance_reactive

############## EnergyVariable, Storage ####################

get_variable_binary(::EnergyVariable, ::Type{<:PSY.Storage}) = false
get_variable_lower_bound(::EnergyVariable, d::PSY.Storage, _) = 0.0

############## ReserveVariable, Storage ####################

get_variable_binary(::ReserveVariable, ::Type{<:PSY.Storage}) = true

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
    ::Type{<:BookKeepingwReservation},
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
    ::Type{<:BookKeepingwReservation},
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
    psi_container::PSIContainer,
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
        psi_container,
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
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
    ::Type{D},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation}
    storage_energy_init(psi_container, devices)
    return
end

############################ Energy Capacity Constraints####################################

function energy_capacity_constraints!(
    psi_container::PSIContainer,
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
        psi_container,
        RangeConstraintSpecInternal(
            constraint_infos,
            make_constraint_name(ENERGY_CAPACITY, St),
            make_variable_name(ENERGY, St),
        ),
    )
    return
end

############################ book keeping constraints ######################################

function make_efficiency_data(
    devices::IS.FlattenIteratorWrapper{St},
) where {St <: PSY.Storage}
    names = Vector{String}(undef, length(devices))
    in_out = Vector{InOut}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        names[ix] = PSY.get_name(d)
        in_out[ix] = PSY.get_efficiency(d)
    end

    return names, in_out
end

function energy_balance_constraint!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
    ::Type{D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation, S <: PM.AbstractPowerModel}
    efficiency_data = make_efficiency_data(devices)
    key = ICKey(EnergyLevel, St)

    if !has_initial_conditions(psi_container.initial_conditions, key)
        throw(IS.DataFormatError("Initial Conditions for $(St) Energy Constraints not in the model"))
    end
    
    energy_balance(
        psi_container,
        get_initial_conditions(psi_container, ICKey(EnergyLevel, St)),
        efficiency_data,
        make_constraint_name(ENERGY_LIMIT, St),
        (
            make_variable_name(ACTIVE_POWER_IN, St),
            make_variable_name(ACTIVE_POWER_OUT, St),
            make_variable_name(ENERGY, St),
        ),
    )
    return
end

############################ Energy Management constraints ######################################

function energy_target_constraint!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
    ::Type{BookKeepingwTargetTimeSeries},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {St <: PSY.BatterywEMS, S <: PM.AbstractPowerModel}

    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    target_forecast_label = "storage_target"
    constraint_infos_target = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector_target = get_time_series(psi_container, d, target_forecast_label)
        constraint_info_target = DeviceTimeSeriesConstraintInfo(
            d,
            x -> PSY.get_storage_target(x) * PSY.get_storage_capacity(x),
            ts_vector_target,
        )
        constraint_infos_target[ix] = constraint_info_target
    end

    if parameters
        energy_target_timeseries_param(
            psi_container,
            constraint_infos_target,
            make_constraint_name(ENERGY_TARGET, St),
            make_variable_name(ENERGY, St),
            UpdateRef{St}(TARGET, target_forecast_label),
        )
    else
        energy_target_timeseries(
            psi_container,
            constraint_infos_target,
            make_constraint_name(ENERGY_TARGET, St),
            make_variable_name(ENERGY, St),
        )
    end
    return
end

function energy_target_constraint!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
    ::Type{BookKeepingwTarget},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {St <: PSY.BatterywEMS, S <: PM.AbstractPowerModel}

    constraint_infos_target = Vector{DeviceEnergyTargetConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        constraint_info_target = DeviceEnergyTargetConstraintInfo(
            d,
            PSY.get_storage_capacity(d),
            PSY.get_storage_target(d),
        )
        constraint_infos_target[ix] = constraint_info_target
    end

    energy_target(
        psi_container,
        constraint_infos_target,
        make_constraint_name(ENERGY_TARGET, St),
        make_variable_name(ENERGY, St),
    )

    return
end

function energy_target_constraint!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
    ::Type{BookKeepingwSoftTargetTimeSeries},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {St <: PSY.BatterywEMS, S <: PM.AbstractPowerModel}

    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    target_forecast_label = "storage_target"
    constraint_infos_target = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector_target = get_time_series(psi_container, d, target_forecast_label)
        constraint_info_target = DeviceTimeSeriesConstraintInfo(
            d,
            x -> PSY.get_storage_target(x) * PSY.get_storage_capacity(x),
            ts_vector_target,
        )
        constraint_infos_target[ix] = constraint_info_target
    end

    if parameters
        energy_soft_target_timeseries_param(
            psi_container,
            constraint_infos_target,
            make_constraint_name(ENERGY_TARGET, St),
            (
                make_variable_name(ENERGY, St),
                make_variable_name(ENERGY_TARGET_SLACK, St),
            ),
            UpdateRef{St}(TARGET, target_forecast_label),
        )
    else
        energy_soft_target_timeseries(
            psi_container,
            constraint_infos_target,
            make_constraint_name(ENERGY_TARGET, St),
            (
                make_variable_name(ENERGY, St),
                make_variable_name(ENERGY_TARGET_SLACK, St),
            ),
        )
    end
    return
end

function energy_target_constraint!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
    ::Type{BookKeepingwSoftTarget},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {St <: PSY.BatterywEMS, S <: PM.AbstractPowerModel}

    constraint_infos_target = Vector{DeviceEnergyTargetConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        constraint_info_target = DeviceEnergyTargetConstraintInfo(
            d,
            PSY.get_storage_capacity(d),
            PSY.get_storage_target(d),
        )
        constraint_infos_target[ix] = constraint_info_target
    end

    energy_soft_target(
        psi_container,
        constraint_infos_target,
        make_constraint_name(ENERGY_TARGET, St),
        (
            make_variable_name(ENERGY, St),
            make_variable_name(ENERGY_TARGET_SLACK, St),
        ),
    )

    return
end

function AddCostSpec(
    ::Type{St},
    ::Type{D},
    psi_container::PSIContainer,
) where {St <: PSY.BatterywEMS, D <: Union{BookKeepingwSoftTarget, BookKeepingwSoftTargetTimeSeries}}
    return AddCostSpec(;
        variable_type = EnergyTargetSlackVariable,
        component_type = St,
        variable_cost = PSY.get_penalty_cost,
        multiplier = OBJECTIVE_FUNCTION_NEGATIVE,
    )
end

function AddCostSpec(
    ::Type{St},
    ::Type{BookKeepingwEnergyValue},
    psi_container::PSIContainer,
) where {St <: PSY.BatterywEMS}
    return AddCostSpec(;
        variable_type = EnergyVariable,
        component_type = St,
        variable_cost = PSY.get_energy_value,
        multiplier = OBJECTIVE_FUNCTION_POSITIVE,
    )
end
