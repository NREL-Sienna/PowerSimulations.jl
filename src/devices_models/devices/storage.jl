#! format: off

abstract type AbstractStorageFormulation <: AbstractDeviceFormulation end
abstract type AbstractEnergyManagement  <: AbstractStorageFormulation end
struct BookKeeping <: AbstractStorageFormulation end
struct BookKeepingwReservation <: AbstractStorageFormulation end
struct BatteryAncillaryServices <: AbstractStorageFormulation end
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

############## ReservationVariable, Storage ####################

get_variable_binary(::ReservationVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = true

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
    ::Type{<:OutputActivePowerVariableLimitsConstraint},
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
            constraint_type = OutputActivePowerVariableLimitsConstraint(),
            variable_type = ActivePowerOutVariable(),
            limits_func = x -> PSY.get_output_active_power_limits(x),
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
    ::Type{<:BookKeeping},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.Storage}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_type = InputActivePowerVariableLimitsConstraint(),
            variable_type = ActivePowerInVariable(),
            limits_func = x -> PSY.get_input_active_power_limits(x),
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
    ::Type{<:AbstractStorageFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.Storage}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_type = OutputActivePowerVariableLimitsConstraint(),
            variable_type = ActivePowerOutVariable(),
            bin_variable_types = [ReservationVariable()],
            limits_func = x -> PSY.get_output_active_power_limits(x),
            constraint_func = device_semicontinuousrange!,
            constraint_struct = DeviceRangeConstraintInfo,
            component_type = T,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:InputActivePowerVariableLimitsConstraint},
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
            constraint_type = InputActivePowerVariableLimitsConstraint(),
            variable_type = ActivePowerInVariable(),
            bin_variable_types = [ReservationVariable()],
            limits_func = x -> PSY.get_input_active_power_limits(x),
            constraint_func = reserve_device_semicontinuousrange!,
            constraint_struct = DeviceRangeConstraintInfo,
            component_type = T,
        ),
    )
end

"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{<:ReactivePowerVariableLimitsConstraint},
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
        container,
        RangeConstraintSpecInternal(
            constraint_infos,
            ReactivePowerVariableLimitsConstraint(),
            ReactivePowerVariable(),
            St,
        ),
    )
    return
end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{St},
    formulation::AbstractStorageFormulation,
) where {St <: PSY.Storage}
    add_initial_condition!(
        container,
        devices,
        formulation,
        InitialEnergyLevel,
        EnergyVariable,
    )
    return
end

############################ Energy Capacity Constraints####################################
function energy_capacity_constraints!(
    container::OptimizationContainer,
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
        container,
        RangeConstraintSpecInternal(
            constraint_infos,
            EnergyCapacityConstraint(),
            EnergyVariable(),
            St,
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
        constraint_type = EnergyLimitConstraint(),
        energy_variable = EnergyVariable(),
        initial_condition = InitialEnergyLevel,
        pin_variable_types = [ActivePowerInVariable()],
        pout_variable_types = [ActivePowerOutVariable()],
        constraint_func = energy_balance!,
        component_type = St,
    )
end

############################ reserve constraints ######################################

function reserve_contribution_constraint!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{<:PM.AbstractPowerModel},
    ::Union{Nothing, AbstractAffectFeedForward},
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
            T,
        )
        add_device_services!(up_info, down_info, d, model)
        add_device_services!(energy_info, d, model)
        constraint_infos_energy[ix] = energy_info
        constraint_infos_up[ix] = up_info
        constraint_infos_dn[ix] = down_info
    end

    reserve_power_ub!(
        container,
        constraint_infos_up,
        constraint_infos_dn,
        RangeLimitConstraint(),
        (ActivePowerInVariable(), ActivePowerOutVariable()),
        T,
    )

    reserve_energy_ub!(
        container,
        constraint_infos_energy,
        ReserveEnergyConstraint(),
        EnergyVariable(),
        T,
    )

    return
end

############################ Energy Management constraints ######################################
function energy_target_constraint!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, EnergyTarget},
    ::Type{<:PM.AbstractPowerModel},
    ::Union{Nothing, AbstractAffectFeedForward},
) where {T <: PSY.Storage}
    time_steps = get_time_steps(container)
    target_forecast_name = "storage_target"
    constraint_infos_target = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector_target =
            length(time_steps) == 1 ? [PSY.get_storage_target(d)] :
            vcat(zeros(time_steps[end - 1]), PSY.get_storage_target(d))
        constraint_info_target =
            DeviceTimeSeriesConstraintInfo(d, x -> PSY.get_rating(x), ts_vector_target)
        constraint_infos_target[ix] = constraint_info_target
    end

    if built_for_simulation(container)
        energy_target_param!(
            container,
            constraint_infos_target,
            EnergyTargetConstraint(),
            (EnergyVariable(), EnergyShortageVariable(), EnergySurplusVariable()),
            EnergyTargetTimeSeriesParameter(target_forecast_name),
            T,
        )
    else
        energy_target!(
            container,
            constraint_infos_target,
            EnergyTargetConstraint(),
            (EnergyVariable(), EnergyShortageVariable(), EnergySurplusVariable()),
            T,
        )
    end

    constraint_infos = Vector{DeviceRangeConstraintInfo}()
    for d in devices
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
            container,
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

function AddCostSpec(
    ::Type{PSY.BatteryEMS},
    ::Type{EnergyTarget},
    container::OptimizationContainer,
)
    return AddCostSpec(;
        variable_type = ActivePowerOutVariable,
        component_type = PSY.BatteryEMS,
        variable_cost = PSY.get_variable,
        multiplier = OBJECTIVE_FUNCTION_POSITIVE,
    )
end
