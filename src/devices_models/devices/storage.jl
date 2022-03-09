#! format: off
requires_initialization(::AbstractStorageFormulation) = false

get_variable_multiplier(_, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = NaN
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.Storage}, ::Type{<:PSY.Reserve{PSY.ReserveUp}}) = ReserveRangeExpressionUB
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.Storage}, ::Type{<:PSY.Reserve{PSY.ReserveDown}}) = ReserveRangeExpressionLB
########################### ActivePowerInVariable, Storage #################################
get_variable_binary(::ActivePowerInVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = false
get_variable_lower_bound(::ActivePowerInVariable, d::PSY.Storage, ::AbstractStorageFormulation) = 0.0
get_variable_upper_bound(::ActivePowerInVariable, d::PSY.Storage, ::AbstractStorageFormulation) = PSY.get_input_active_power_limits(d).max
get_variable_multiplier(::ActivePowerInVariable, d::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = -1.0

########################### ActivePowerOutVariable, Storage #################################
get_variable_binary(::ActivePowerOutVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = false
get_variable_lower_bound(::ActivePowerOutVariable, d::PSY.Storage, ::AbstractStorageFormulation) = 0.0
get_variable_upper_bound(::ActivePowerOutVariable, d::PSY.Storage, ::AbstractStorageFormulation) = PSY.get_output_active_power_limits(d).max
get_variable_multiplier(::ActivePowerOutVariable, d::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = 1.0

############## ReactivePowerVariable, Storage ####################
get_variable_multiplier(::ReactivePowerVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = 1.0
get_variable_binary(::ReactivePowerVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = false

############## EnergyVariable, Storage ####################
get_variable_binary(::EnergyVariable, ::Type{<:PSY.Storage}, ::AbstractStorageFormulation) = false
get_variable_upper_bound(::EnergyVariable, d::PSY.Storage, ::AbstractStorageFormulation) = PSY.get_state_of_charge_limits(d).max
get_variable_lower_bound(::EnergyVariable, d::PSY.Storage, ::AbstractStorageFormulation) = PSY.get_state_of_charge_limits(d).min
get_variable_warm_start_value(::EnergyVariable, d::PSY.Storage, ::AbstractStorageFormulation) = PSY.get_initial_energy(d)

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

#################### Initial Conditions for models ###############
initial_condition_default(::InitialEnergyLevel, d::PSY.Storage, ::AbstractStorageFormulation) = PSY.get_initial_energy(d)
initial_condition_variable(::InitialEnergyLevel, d::PSY.Storage, ::AbstractStorageFormulation) = EnergyVariable()

########################### Parameter related set functions ################################
get_parameter_multiplier(::VariableValueParameter, d::PSY.Storage, ::AbstractStorageFormulation) = 1.0
get_initial_parameter_value(::VariableValueParameter, d::PSY.Storage, ::AbstractStorageFormulation) = 1.0


########################Objective Function##################################################
objective_function_multiplier(::VariableType, ::AbstractStorageFormulation)=OBJECTIVE_FUNCTION_POSITIVE
objective_function_multiplier(::EnergySurplusVariable, ::EnergyTarget)=OBJECTIVE_FUNCTION_NEGATIVE
objective_function_multiplier(::EnergyShortageVariable, ::EnergyTarget)=OBJECTIVE_FUNCTION_POSITIVE

proportional_cost(cost::PSY.StorageManagementCost, ::EnergySurplusVariable, ::PSY.BatteryEMS, ::EnergyTarget)=PSY.get_energy_surplus_cost(cost)
proportional_cost(cost::PSY.StorageManagementCost, ::EnergyShortageVariable, ::PSY.BatteryEMS, ::EnergyTarget)=PSY.get_energy_shortage_cost(cost)

variable_cost(cost::PSY.StorageManagementCost, ::ActivePowerOutVariable, ::PSY.BatteryEMS, ::EnergyTarget)=PSY.get_variable(cost)


#! format: on

get_initial_conditions_device_model(
    ::OperationModel,
    ::DeviceModel{T, <:AbstractStorageFormulation},
) where {T <: PSY.Storage} = DeviceModel(T, BookKeeping)

get_multiplier_value(
    ::EnergyTargetTimeSeriesParameter,
    d::PSY.Storage,
    ::AbstractStorageFormulation,
) = PSY.get_rating(d)

function get_default_time_series_names(
    ::Type{D},
    ::Type{EnergyTarget},
) where {D <: PSY.Storage}
    return Dict{Type{<:TimeSeriesParameter}, String}(
        EnergyTargetTimeSeriesParameter => "storage_target",
    )
end

function get_default_time_series_names(
    ::Type{D},
    ::Type{<:Union{FixedOutput, AbstractStorageFormulation}},
) where {D <: PSY.Storage}
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

function get_default_attributes(
    ::Type{D},
    ::Type{T},
) where {D <: PSY.Storage, T <: Union{FixedOutput, AbstractStorageFormulation}}
    return Dict{String, Any}("reservation" => true)
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
    T::Type{<:PowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.Storage, W <: AbstractStorageFormulation}
    if get_attribute(model, "reservation")
        add_reserve_range_constraints!(container, T, U, devices, model, X)
    else
        add_range_constraints!(container, T, U, devices, model, X)
    end
end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{St},
    formulation::AbstractStorageFormulation,
) where {St <: PSY.Storage}
    add_initial_condition!(container, devices, formulation, InitialEnergyLevel())
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
    return PSY.get_state_of_charge_limits(d)
end

"""
Add Energy Capacity Constraints for AbstractStorageFormulation
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{EnergyCapacityConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {V <: PSY.Storage, W <: AbstractStorageFormulation, X <: PM.AbstractPowerModel}
    add_range_constraints!(
        container,
        EnergyCapacityConstraint,
        EnergyVariable,
        devices,
        model,
        X,
    )
    return
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
) where {V <: PSY.Storage, W <: AbstractStorageFormulation, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    names = [PSY.get_name(x) for x in devices]
    initial_conditions = get_initial_condition(container, InitialEnergyLevel(), V)
    energy_var = get_variable(container, EnergyVariable(), V)
    powerin_var = get_variable(container, ActivePowerInVariable(), V)
    powerout_var = get_variable(container, ActivePowerOutVariable(), V)

    constraint = add_constraints_container!(
        container,
        EnergyBalanceConstraint(),
        V,
        names,
        time_steps,
    )

    for ic in initial_conditions
        device = get_component(ic)
        efficiency = PSY.get_efficiency(device)
        name = PSY.get_name(device)
        constraint[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            energy_var[name, 1] ==
            get_value(ic) +
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
function add_constraints!(
    container::OptimizationContainer,
    ::Type{ReserveEnergyConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.Storage, D <: AbstractStorageFormulation}
    time_steps = get_time_steps(container)
    var_e = get_variable(container, EnergyVariable(), T)
    expr_up = get_expression(container, ReserveRangeExpressionUB(), T)
    expr_dn = get_expression(container, ReserveRangeExpressionLB(), T)
    names = [PSY.get_name(x) for x in devices]
    con_up = add_constraints_container!(
        container,
        ReserveEnergyConstraint(),
        T,
        names,
        time_steps,
        meta="up",
    )
    con_dn = add_constraints_container!(
        container,
        ReserveEnergyConstraint(),
        T,
        names,
        time_steps,
        meta="dn",
    )

    for d in devices, t in time_steps
        name = PSY.get_name(d)
        limits = PSY.get_state_of_charge_limits(d)
        efficiency = PSY.get_efficiency(d)
        con_up[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expr_up[name, t] <= (var_e[name, t] - limits.min) * efficiency.out
        )
        con_dn[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expr_dn[name, t] <= (limits.max - var_e[name, t]) / efficiency.in
        )
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{RangeLimitConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.Storage, D <: AbstractStorageFormulation}
    time_steps = get_time_steps(container)
    var_in = get_variable(container, ActivePowerInVariable(), T)
    var_out = get_variable(container, ActivePowerOutVariable(), T)
    expr_up = get_expression(container, ReserveRangeExpressionUB(), T)
    expr_dn = get_expression(container, ReserveRangeExpressionLB(), T)
    names = [PSY.get_name(x) for x in devices]
    con_up = add_constraints_container!(
        container,
        RangeLimitConstraint(),
        T,
        names,
        time_steps,
        meta="up",
    )
    con_dn = add_constraints_container!(
        container,
        RangeLimitConstraint(),
        T,
        names,
        time_steps,
        meta="dn",
    )

    for d in devices, t in time_steps
        name = PSY.get_name(d)
        out_limits = PSY.get_output_active_power_limits(d)
        in_limits = PSY.get_input_active_power_limits(d)
        con_up[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expr_up[name, t] <= var_in[name, t] + (out_limits.max - var_out[name, t])
        )
        con_dn[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            expr_dn[name, t] <= var_out[name, t] + (in_limits.max - var_in[name, t])
        )
    end
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
) where {V <: PSY.Storage, W <: EnergyTarget, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    name_index = [PSY.get_name(d) for d in devices]
    energy_var = get_variable(container, EnergyVariable(), V)
    shortage_var = get_variable(container, EnergyShortageVariable(), V)
    surplus_var = get_variable(container, EnergySurplusVariable(), V)

    param = get_parameter_array(container, EnergyTargetTimeSeriesParameter(), V)
    multiplier =
        get_parameter_multiplier_array(container, EnergyTargetTimeSeriesParameter(), V)

    constraint = add_constraints_container!(
        container,
        EnergyTargetConstraint(),
        V,
        name_index,
        time_steps,
    )
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

##################################### Storage generation cost ############################
function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.Storage, U <: AbstractStorageFormulation}
    add_proportional_cost!(container, ActivePowerOutVariable(), devices, U())
    add_proportional_cost!(container, ActivePowerInVariable(), devices, U())
    return
end

function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{PSY.BatteryEMS},
    ::DeviceModel{PSY.BatteryEMS, T},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: EnergyTarget}
    add_variable_cost!(container, ActivePowerOutVariable(), devices, T())
    add_proportional_cost!(container, EnergySurplusVariable(), devices, T())
    add_proportional_cost!(container, EnergyShortageVariable(), devices, T())
    return
end
