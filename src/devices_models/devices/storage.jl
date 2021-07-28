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
get_variable_upper_bound(::EnergyVariable, d::PSY.Storage, ::AbstractStorageFormulation) = PSY.get_state_of_charge_limits(d).max
get_variable_lower_bound(::EnergyVariable, d::PSY.Storage, ::AbstractStorageFormulation) = PSY.get_state_of_charge_limits(d).min
get_variable_initial_value(::EnergyVariable, d::PSY.Storage, ::AbstractStorageFormulation) = PSY.get_initial_energy(d)

############## ReservationVariable, Storage ####################

get_variable_binary(::ReservationVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = true

get_efficiency(v::T, var::Type{<:InitialConditionType}) where T <: PSY.Storage = PSY.get_efficiency(v)

############## EnergyShortageVariable, Storage ####################

get_variable_binary(::EnergyShortageVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = false
get_variable_lower_bound(::EnergyShortageVariable, d::PSY.Storage, ::AbstractStorageFormulation) = 0.0
get_variable_upper_bound(::EnergyShortageVariable, d::PSY.Storage, ::AbstractStorageFormulation) = PSY.get_rating(d)

############## EnergySurplusVariable, Storage ####################

get_variable_binary(::EnergySurplusVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = false
get_variable_upper_bound(::EnergySurplusVariable, d::PSY.Storage, ::AbstractStorageFormulation) = 0.0
get_variable_lower_bound(::EnergySurplusVariable, d::PSY.Storage, ::AbstractStorageFormulation) = - PSY.get_rating(d)
#! format: on

get_multiplier_value(
    ::EnergyTargetTimeSeriesParameter,
    d::PSY.Storage,
    ::AbstractStorageFormulation,
) = PSY.get_rating(d)

function _initialize_timeseries_labels(
    ::Type{D},
    ::Type{EnergyTarget},
) where {D <: PSY.Storage}
    return Dict{Type{<:TimeSeriesParameter}, String}(
        EnergyTargetTimeSeriesParameter => "storage_target",
    )
end

################################## output power constraints#################################

get_min_max_limits(
    device::PSY.Storage,
    ::Type{<:ReactivePowerVariableLimitsConstraint},
    ::Type{<:AbstractStorageFormulation},
) = PSY.get_reactive_power_limits(device)
get_min_max_limits(
    device::PSY.Storage,
    ::Type{<:InputActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractStorageFormulation},
) = PSY.get_input_active_power_limits(device)
get_min_max_limits(
    device::PSY.Storage,
    ::Type{<:OutputActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractStorageFormulation},
) = PSY.get_output_active_power_limits(device)
get_min_max_limits(
    device::PSY.Storage,
    ::Type{<:OutputActivePowerVariableLimitsConstraint},
    ::Type{BookKeeping},
) = PSY.get_output_active_power_limits(device)

function add_constraints!(
    container::OptimizationContainer,
    T::Type{InputActivePowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Storage, W <: AbstractStorageFormulation}
    use_parameters = built_for_simulation(container)
    constraint = T()
    variable = U()
    component_type = V
    time_steps = get_time_steps(container)
    jump_variable = get_variable(container, variable, component_type)
    names = [PSY.get_name(d) for d in devices]
    binary_variables = [ReservationVariable()]

    @assert length(binary_variables) == 1
    varbin = get_variable(container, only(binary_variables), component_type)

    names = [PSY.get_name(x) for x in devices]
    # MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    # In the future this can be updated
    con_ub = add_cons_container!(
        container,
        constraint,
        component_type,
        names,
        time_steps,
        meta = "ub",
    )
    con_lb = add_cons_container!(
        container,
        constraint,
        component_type,
        names,
        time_steps,
        meta = "lb",
    )

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        limits = get_min_max_limits(device, T, W)
        if JuMP.has_lower_bound(jump_variable[ci_name, t])
            JuMP.set_lower_bound(jump_variable[ci_name, t], 0.0)
        end
        expression_ub = JuMP.AffExpr(0.0, jump_variable[ci_name, t] => 1.0)
        expression_lb = JuMP.AffExpr(0.0, jump_variable[ci_name, t] => 1.0)
        con_ub[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_ub <= limits.max * (1 - varbin[ci_name, t])
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_lb >= limits.min * (1 - varbin[ci_name, t])
        )
    end
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:PowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Storage, W <: AbstractStorageFormulation}
    use_parameters = built_for_simulation(container)
    constraint = T()
    variable = U()
    component_type = V
    time_steps = get_time_steps(container)
    jump_variable = get_variable(container, variable, component_type)
    names = [PSY.get_name(d) for d in devices]
    binary_variables = [ReservationVariable()]

    con_ub = add_cons_container!(
        container,
        constraint,
        component_type,
        names,
        time_steps,
        meta = "ub",
    )
    con_lb = add_cons_container!(
        container,
        constraint,
        component_type,
        names,
        time_steps,
        meta = "lb",
    )

    @assert length(binary_variables) == 1 "Expected $(binary_variables) for $U $V $T $W to be length 1"
    varbin = get_variable(container, only(binary_variables), component_type)

    for (i, device) in enumerate(devices), t in time_steps
        ci_name = PSY.get_name(device)
        # TODO: deal with additional expressions terms for services
        expression_ub = JuMP.AffExpr(0.0, jump_variable[ci_name, t] => 1.0)
        expression_lb = JuMP.AffExpr(0.0, jump_variable[ci_name, t] => 1.0)
        limits = get_min_max_limits(device, T, W) # depends on constraint type and formulation type
        con_ub[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_ub <= limits.max * varbin[ci_name, t]
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expression_lb >= limits.min * varbin[ci_name, t]
        )
    end
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:OutputActivePowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Storage, W <: BookKeeping}
    add_range_constraints!(container, T, U, devices, model, X, feedforward)
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{ReactivePowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Storage, W <: BookKeeping}
    add_range_constraints!(container, T, U, devices, model, X, feedforward)
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{InputActivePowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Storage, W <: BookKeeping}
    add_range_constraints!(container, T, U, devices, model, X, feedforward)
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
"""
Min and max limits for Energy Capacity Constraint and AbstractStorageFormulation
"""
function get_min_max_limits(
    d,
    ::Type{EnergyCapacityConstraint},
    ::Type{<:AbstractStorageFormulation},
)
    PSY.get_state_of_charge_limits(d)
end

"""
Add Energy Capacity Constraints for AbstractStorageFormulation
"""
function energy_capacity_constraints!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Storage, W <: AbstractStorageFormulation, X <: PM.AbstractPowerModel}
    add_range_constraints!(
        container,
        EnergyCapacityConstraint,
        EnergyVariable,
        devices,
        model,
        X,
        feedforward,
    )
end

############################ book keeping constraints ######################################

"""
Add Energy Balance Constraints for AbstractStorageFormulation
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{EnergyBalanceConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Storage, W <: AbstractStorageFormulation, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    names = [PSY.get_name(x) for x in devices]
    initial_conditions = get_initial_conditions(container, InitialEnergyLevel, V)
    energy_var = get_variable(container, EnergyVariable(), V)
    powerin_var = get_variable(container, ActivePowerInVariable(), V)
    powerout_var = get_variable(container, ActivePowerOutVariable(), V)

    constraint =
        add_cons_container!(container, EnergyBalanceConstraint(), V, names, time_steps)

    for ic in initial_conditions
        device = ic.device
        efficiency = PSY.get_efficiency(device)
        name = PSY.get_name(device)
        constraint[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            energy_var[name, 1] ==
            ic.value +
            (
                powerin_var[name, 1] * efficiency.in -
                (powerout_var[name, 1] / efficiency.out)
            ) * fraction_of_hour
        )

        for t in time_steps[2:end]
            constraint[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                energy_var[name, t] ==
                energy_var[name, t - 1] +
                (
                    powerin_var[name, t] * efficiency.in -
                    (powerout_var[name, t] / efficiency.out)
                ) * fraction_of_hour
            )
        end
    end
    return
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
"""
Add Energy Target Constraints for EnergyTarget formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{EnergyTargetConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.Storage, W <: EnergyTarget, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    name_index = [PSY.get_name(d) for d in devices]
    energy_var = get_variable(container, EnergyVariable(), V)
    shortage_var = get_variable(container, EnergyShortageVariable(), V)
    surplus_var = get_variable(container, EnergySurplusVariable(), V)

    parameter_container = get_parameter(container, EnergyTargetTimeSeriesParameter(), V)
    param = get_parameter_array(parameter_container)
    multiplier = get_multiplier_array(parameter_container)

    constraint =
        add_cons_container!(container, EnergyTargetConstraint(), V, name_index, time_steps)
    for d in devices
        name = PSY.get_name(d)
        shortage_cost = PSY.get_energy_shortage_cost(PSY.get_operation_cost(d))
        if shortage_cost == 0.0
            @warn(
                "Device $name has energy shortage cost set to 0.0, as a result the model will turnoff the EnergyShortageVariable to avoid infeasible/unbounded problem."
            )
            JuMP.delete_upper_bound.(shortage_var[name, :])
            JuMP.set_upper_bound.(shortage_var[name, :], 0.0)
        end
        for t in time_steps
            constraint[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                energy_var[name, t] + shortage_var[name, t] + surplus_var[name, t] ==
                multiplier[name, t] * param[name, t]
            )
        end
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
