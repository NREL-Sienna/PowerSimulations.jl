#! format: off

abstract type AbstractStorageFormulation <: AbstractDeviceFormulation end
abstract type AbstractEnergyManagement  <: AbstractStorageFormulation end
struct BookKeeping <: AbstractStorageFormulation end
struct BookKeepingwReservation <: AbstractStorageFormulation end
struct EndOfPeriodEnergyTarget <: AbstractEnergyManagement end

get_variable_sign(_, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = NaN
########################### ActivePowerInVariable, Storage #################################

get_variable_binary(::ActivePowerInVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = false
get_variable_expression_name(::ActivePowerInVariable, ::Type{<:PSY.Storage}) = :nodal_balance_active

get_variable_lower_bound(::ActivePowerInVariable, d::PSY.Storage, ::AbstractStorageFormulation) = 0.0
get_variable_upper_bound(::ActivePowerInVariable, d::PSY.Storage, ::AbstractStorageFormulation) = nothing
get_variable_sign(::ActivePowerInVariable, d::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = -1.0

########################### ActivePowerOutVariable, Storage #################################

get_variable_binary(::ActivePowerOutVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = false
get_variable_expression_name(::ActivePowerOutVariable, ::Type{<:PSY.Storage}) = :nodal_balance_active

get_variable_lower_bound(::ActivePowerOutVariable, d::PSY.Storage, ::AbstractStorageFormulation) = 0.0
get_variable_upper_bound(::ActivePowerOutVariable, d::PSY.Storage, ::AbstractStorageFormulation) = nothing
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

#! format: on

################################## output power constraints#################################

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
    key = ICKey(EnergyLevel, T)
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
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{St},
    ::Type{D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation, S <: PM.AbstractPowerModel}
    efficiency_data = make_efficiency_data(devices)
    key = ICKey(EnergyLevel, St)

    if !has_initial_conditions(optimization_container.initial_conditions, key)
        throw(
            IS.DataFormatError(
                "Initial Conditions for $(St) Energy Constraints not in the model",
            ),
        )
    end

    energy_balance(
        optimization_container,
        get_initial_conditions(optimization_container, ICKey(EnergyLevel, St)),
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

function energy_target_constraint!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{St},
    ::Type{EndOfPeriodEnergyTarget},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {St <: PSY.BatteryEMS, S <: PM.AbstractPowerModel}
    constraint_infos_target =
        Vector{DeviceEnergyTargetConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        constraint_info_target = DeviceEnergyTargetConstraintInfo(
            PSY.get_name(d),
            PSY.get_rating(d),
            PSY.get_storage_target(d),
        )
        constraint_infos_target[ix] = constraint_info_target
    end

    energy_soft_target(
        optimization_container,
        constraint_infos_target,
        make_constraint_name(ENERGY_TARGET, St),
        (make_variable_name(ENERGY, St), make_variable_name(ENERGY_TARGET_SLACK, St)),
    )

    return
end

############################ Energy Management constraints ######################################

function AddCostSpec(
    ::Type{PSY.BatteryEMS},
    ::Type{EndOfPeriodEnergyTarget},
    optimization_container::OptimizationContainer,
)
    variable_cost_func = x -> -PSY.get_energy_value(x) + PSY.get_penalty_cost(x)
    return AddCostSpec(;
        variable_type = EnergyVariable,
        component_type = PSY.BatteryEMS,
        variable_cost = variable_cost_func,
        multiplier = OBJECTIVE_FUNCTION_POSITIVE,
    )
end

function add_to_cost!(
    optimization_container::OptimizationContainer,
    spec::AddCostSpec,
    cost_data::Float64,
    component::T,
) where {T <: PSY.Storage}
    component_name = PSY.get_name(component)
    time_steps = model_time_steps(optimization_container)

    linear_gen_cost!(
        optimization_container,
        make_variable_name(spec.variable_type, spec.component_type),
        component_name,
        cost_data,
        time_steps[end],
    )
    return
end

"""
Add variables to the OptimizationContainer for a Storage device.
"""
function cost_function!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward} = nothing,
) where {T <: PSY.Storage, U <: AbstractStorageFormulation}
    for d in devices
        spec = AddCostSpec(T, U, optimization_container)
        @debug T, spec
        add_to_cost!(optimization_container, spec, spec.variable_cost(d), d)
    end
    return
end
