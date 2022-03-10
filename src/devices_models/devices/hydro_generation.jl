#! format: off
requires_initialization(::AbstractHydroFormulation) = false
requires_initialization(::AbstractHydroUnitCommitment) = true

get_variable_multiplier(_, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = 1.0
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.HydroGen}, ::Type{<:PSY.Reserve{PSY.ReserveUp}}) = ActivePowerRangeExpressionUB
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.HydroGen}, ::Type{<:PSY.Reserve{PSY.ReserveDown}}) = ActivePowerRangeExpressionLB
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.HydroPumpedStorage}, ::Type{<:PSY.Reserve{PSY.ReserveUp}}) = ReserveRangeExpressionUB
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.HydroPumpedStorage}, ::Type{<:PSY.Reserve{PSY.ReserveDown}}) = ReserveRangeExpressionLB

########################### ActivePowerVariable, HydroGen #################################
get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_warm_start_value(::ActivePowerVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power(d)
get_variable_lower_bound(::ActivePowerVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power_limits(d).min
get_variable_lower_bound(::ActivePowerVariable, d::PSY.HydroGen, ::AbstractHydroUnitCommitment) = 0.0
get_variable_upper_bound(::ActivePowerVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power_limits(d).max

############## ActivePowerVariable, HydroDispatchRunOfRiver ####################
get_variable_lower_bound(::ActivePowerVariable, d::PSY.HydroGen, ::HydroDispatchRunOfRiver) = 0.0

############## ReactivePowerVariable, HydroGen ####################
get_variable_binary(::ReactivePowerVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_warm_start_value(::ReactivePowerVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power(d)
get_variable_lower_bound(::ReactivePowerVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power_limits(d).min
get_variable_upper_bound(::ReactivePowerVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power_limits(d).max

############## EnergyVariable, HydroGen ####################
get_variable_binary(::EnergyVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_warm_start_value(pv::EnergyVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_initial_storage(d)
get_variable_lower_bound(::EnergyVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0
get_variable_upper_bound(::EnergyVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_storage_capacity(d)

########################### EnergyVariableUp, HydroGen #################################
get_variable_binary(::EnergyVariableUp, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_warm_start_value(pv::EnergyVariableUp, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_initial_storage(d).up
get_variable_lower_bound(::EnergyVariableUp, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0
get_variable_upper_bound(::EnergyVariableUp, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_storage_capacity(d).up

########################### EnergyVariableDown, HydroGen #################################
get_variable_binary(::EnergyVariableDown, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_warm_start_value(::EnergyVariableDown, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_initial_storage(d).down
get_variable_lower_bound(::EnergyVariableDown, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0
get_variable_upper_bound(::EnergyVariableDown, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_storage_capacity(d).down

########################### ActivePowerInVariable, HydroGen #################################
get_variable_binary(::ActivePowerInVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_lower_bound(::ActivePowerInVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0
get_variable_upper_bound(::ActivePowerInVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = nothing
get_variable_multiplier(::ActivePowerInVariable, d::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = -1.0

########################### ActivePowerOutVariable, HydroGen #################################
get_variable_binary(::ActivePowerOutVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_lower_bound(::ActivePowerOutVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0
get_variable_upper_bound(::ActivePowerOutVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = nothing
get_variable_multiplier(::ActivePowerOutVariable, d::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = 1.0

############## OnVariable, HydroGen ####################
get_variable_binary(::OnVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = true
get_variable_warm_start_value(::OnVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power(d) > 0 ? 1.0 : 0.0

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
get_variable_upper_bound(::EnergyShortageVariable, d::PSY.HydroPumpedStorage, ::AbstractHydroFormulation) = PSY.get_storage_capacity(d).up
############## EnergySurplusVariable, HydroGen ####################
get_variable_binary(::EnergySurplusVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_upper_bound(::EnergySurplusVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0
get_variable_lower_bound(::EnergySurplusVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = - PSY.get_storage_capacity(d)
get_variable_lower_bound(::EnergySurplusVariable, d::PSY.HydroPumpedStorage, ::AbstractHydroFormulation) = - PSY.get_storage_capacity(d).up
########################### Parameter related set functions ################################
get_multiplier_value(::EnergyBudgetTimeSeriesParameter, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_storage_capacity(d)
get_multiplier_value(::EnergyTargetTimeSeriesParameter, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_storage_capacity(d)
get_multiplier_value(::InflowTimeSeriesParameter, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_inflow(d) * PSY.get_conversion_factor(d)
get_multiplier_value(::OutflowTimeSeriesParameter, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_outflow(d) * PSY.get_conversion_factor(d)
get_multiplier_value(::TimeSeriesParameter, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_max_active_power(d)
get_multiplier_value(::TimeSeriesParameter, d::PSY.HydroGen, ::FixedOutput) = PSY.get_max_active_power(d)

get_parameter_multiplier(::VariableValueParameter, d::PSY.HydroGen, ::AbstractHydroFormulation) = 1.0
get_initial_parameter_value(::VariableValueParameter, d::PSY.HydroGen, ::AbstractHydroFormulation) = 1.0
get_expression_multiplier(::OnStatusParameter, ::ActivePowerRangeExpressionUB, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power_limits(d).max
get_expression_multiplier(::OnStatusParameter, ::ActivePowerRangeExpressionLB, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power_limits(d).min

#################### Initial Conditions for models ###############
initial_condition_default(::DeviceStatus, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_status(d)
initial_condition_variable(::DeviceStatus, d::PSY.HydroGen, ::AbstractHydroFormulation) = OnVariable()
initial_condition_default(::DevicePower, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power(d)
initial_condition_variable(::DevicePower, d::PSY.HydroGen, ::AbstractHydroFormulation) = ActivePowerVariable()
initial_condition_default(::InitialEnergyLevel, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_initial_storage(d)
initial_condition_variable(::InitialEnergyLevel, d::PSY.HydroGen, ::AbstractHydroFormulation) = EnergyVariable()
initial_condition_default(::InitialEnergyLevelUp, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_initial_storage(d).up
initial_condition_variable(::InitialEnergyLevelUp, d::PSY.HydroGen, ::AbstractHydroFormulation) = EnergyVariableUp()
initial_condition_default(::InitialEnergyLevelDown, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_initial_storage(d).down
initial_condition_variable(::InitialEnergyLevelDown, d::PSY.HydroGen, ::AbstractHydroFormulation) = EnergyVariableDown()
initial_condition_default(::InitialTimeDurationOn, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_status(d) ? PSY.get_time_at_status(d) :  0.0
initial_condition_variable(::InitialTimeDurationOn, d::PSY.HydroGen, ::AbstractHydroFormulation) = OnVariable()
initial_condition_default(::InitialTimeDurationOff, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_status(d) ? 0.0 : PSY.get_time_at_status(d)
initial_condition_variable(::InitialTimeDurationOff, d::PSY.HydroGen, ::AbstractHydroFormulation) = OnVariable()

########################Objective Function##################################################
proportional_cost(cost::Nothing, ::PSY.HydroGen, ::ActivePowerVariable, ::AbstractHydroFormulation)=0.0
proportional_cost(cost::PSY.OperationalCost, ::OnVariable, ::PSY.HydroGen, ::AbstractHydroFormulation)=PSY.get_fixed(cost)
proportional_cost(cost::PSY.StorageManagementCost, ::EnergySurplusVariable, ::PSY.HydroGen, ::AbstractHydroFormulation)=PSY.get_energy_surplus_cost(cost)
proportional_cost(cost::PSY.StorageManagementCost, ::EnergyShortageVariable, ::PSY.HydroGen, ::AbstractHydroFormulation)=PSY.get_energy_shortage_cost(cost)

objective_function_multiplier(::ActivePowerVariable, ::AbstractHydroFormulation)=OBJECTIVE_FUNCTION_POSITIVE
objective_function_multiplier(::ActivePowerOutVariable, ::AbstractHydroFormulation)=OBJECTIVE_FUNCTION_POSITIVE
objective_function_multiplier(::OnVariable, ::AbstractHydroFormulation)=OBJECTIVE_FUNCTION_POSITIVE
objective_function_multiplier(::EnergySurplusVariable, ::AbstractHydroFormulation)=OBJECTIVE_FUNCTION_NEGATIVE
objective_function_multiplier(::EnergyShortageVariable, ::AbstractHydroFormulation)=OBJECTIVE_FUNCTION_POSITIVE

sos_status(::PSY.HydroGen, ::AbstractHydroFormulation)=SOSStatusVariable.NO_VARIABLE
sos_status(::PSY.HydroGen, ::AbstractHydroUnitCommitment)=SOSStatusVariable.VARIABLE

variable_cost(::Nothing, ::ActivePowerVariable, ::PSY.HydroGen, ::AbstractHydroFormulation)=0.0
variable_cost(cost::PSY.OperationalCost, ::ActivePowerVariable, ::PSY.HydroGen, ::AbstractHydroFormulation)=PSY.get_variable(cost)
variable_cost(cost::PSY.OperationalCost, ::ActivePowerOutVariable, ::PSY.HydroGen, ::AbstractHydroFormulation)=PSY.get_variable(cost)

#! format: on

function get_initial_conditions_device_model(
    ::OperationModel,
    model::DeviceModel{T, <:AbstractHydroFormulation},
) where {T <: PSY.HydroEnergyReservoir}
    return model
end

function get_initial_conditions_device_model(
    ::OperationModel,
    ::DeviceModel{T, <:AbstractHydroFormulation},
) where {T <: PSY.HydroDispatch}
    return DeviceModel(PSY.HydroDispatch, HydroDispatchRunOfRiver)
end

function get_initial_conditions_device_model(
    ::OperationModel,
    ::DeviceModel{T, <:AbstractHydroFormulation},
) where {T <: PSY.HydroPumpedStorage}
    return DeviceModel(PSY.HydroPumpedStorage, HydroDispatchPumpedStorage)
end

function get_default_time_series_names(
    ::Type{<:PSY.HydroGen},
    ::Type{<:Union{FixedOutput, HydroDispatchRunOfRiver, HydroCommitmentRunOfRiver}},
)
    return Dict{Type{<:TimeSeriesParameter}, String}(
        ActivePowerTimeSeriesParameter => "max_active_power",
        ReactivePowerTimeSeriesParameter => "max_active_power",
    )
end

function get_default_time_series_names(
    ::Type{PSY.HydroEnergyReservoir},
    ::Type{<:Union{HydroCommitmentReservoirBudget, HydroDispatchReservoirBudget}},
)
    return Dict{Type{<:TimeSeriesParameter}, String}(
        EnergyBudgetTimeSeriesParameter => "hydro_budget",
    )
end

function get_default_time_series_names(
    ::Type{PSY.HydroEnergyReservoir},
    ::Type{<:Union{HydroDispatchReservoirStorage, HydroCommitmentReservoirStorage}},
)
    return Dict{Type{<:TimeSeriesParameter}, String}(
        EnergyTargetTimeSeriesParameter => "storage_target",
        InflowTimeSeriesParameter => "inflow",
    )
end

function get_default_time_series_names(
    ::Type{PSY.HydroPumpedStorage},
    ::Type{<:HydroDispatchPumpedStorage},
)
    return Dict{Type{<:TimeSeriesParameter}, String}(
        InflowTimeSeriesParameter => "inflow",
        OutflowTimeSeriesParameter => "outflow",
    )
end

function get_default_attributes(
    ::Type{T},
    ::Type{D},
) where {T <: PSY.HydroGen, D <: Union{FixedOutput, AbstractHydroFormulation}}
    return Dict{String, Any}("reservation" => false)
end

function get_default_attributes(
    ::Type{PSY.HydroPumpedStorage},
    ::Type{HydroDispatchPumpedStorage},
)
    return Dict{String, Any}("reservation" => true)
end

"""
Time series constraints
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{ActivePowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HydroGen, W <: HydroDispatchRunOfRiver}
    if !has_semicontinuous_feedforward(model, U)
        add_range_constraints!(container, T, U, devices, model, X)
    end
    add_parameterized_upper_bound_range_constraints(
        container,
        ActivePowerVariableTimeSeriesLimitsConstraint,
        U,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        X,
    )
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{ActivePowerVariableLimitsConstraint},
    U::Type{<:RangeConstraintLBExpressions},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HydroGen, W <: HydroDispatchRunOfRiver}
    if !has_semicontinuous_feedforward(model, U)
        add_range_constraints!(container, T, U, devices, model, X)
    end
    return
end

"""
Add semicontinuous range constraints for Hydro Unit Commitment formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{ActivePowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, <:RangeConstraintLBExpressions}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HydroGen, W <: HydroCommitmentRunOfRiver}
    add_semicontinuous_range_constraints!(container, T, U, devices, model, X)
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{ActivePowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HydroGen, W <: HydroCommitmentRunOfRiver}
    add_semicontinuous_range_constraints!(container, T, U, devices, model, X)
    add_parameterized_upper_bound_range_constraints(
        container,
        ActivePowerVariableTimeSeriesLimitsConstraint,
        U,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        X,
    )
    return
end

"""
Min and max reactive Power Variable limits
"""
function get_min_max_limits(
    x::PSY.HydroGen,
    ::Type{<:ReactivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHydroFormulation},
)
    return PSY.get_reactive_power_limits(x)
end

"""
Min and max active Power Variable limits
"""
function get_min_max_limits(
    x::PSY.HydroGen,
    ::Type{<:ActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHydroFormulation},
)
    return PSY.get_active_power_limits(x)
end

function get_min_max_limits(
    x::PSY.HydroGen,
    ::Type{<:ActivePowerVariableLimitsConstraint},
    ::Type{HydroDispatchRunOfRiver},
)
    return (min=0.0, max=PSY.get_max_active_power(x))
end

"""
Add power variable limits constraints for hydro unit commitment formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:PowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HydroGen, W <: AbstractHydroUnitCommitment}
    add_semicontinuous_range_constraints!(container, T, U, devices, model, X)
    return
end

"""
Add power variable limits constraints for hydro dispatch formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:PowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HydroGen, W <: AbstractHydroDispatchFormulation}
    if !has_semicontinuous_feedforward(model, U)
        add_range_constraints!(container, T, U, devices, model, X)
    end
    return
end

"""
Add input power variable limits constraints for hydro dispatch formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{InputActivePowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HydroPumpedStorage, W <: AbstractHydroReservoirFormulation}
    if get_attribute(model, "reservation")
        add_reserve_range_constraints!(container, T, U, devices, model, X)
    else
        if !has_semicontinuous_feedforward(model, U)
            add_range_constraints!(container, T, U, devices, model, X)
        end
    end
    return
end

"""
Add output power variable limits constraints for hydro dispatch formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:PowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HydroPumpedStorage, W <: AbstractHydroReservoirFormulation}
    if get_attribute(model, "reservation")
        add_reserve_range_constraints!(container, T, U, devices, model, X)
    else
        if !has_semicontinuous_feedforward(model, U)
            add_range_constraints!(container, T, U, devices, model, X)
        end
    end
    return
end

"""
Min and max output active power variable limits for hydro dispatch pumped storage
"""
function get_min_max_limits(
    x::PSY.HydroGen,
    ::Type{<:OutputActivePowerVariableLimitsConstraint},
    ::Type{HydroDispatchPumpedStorage},
)
    return PSY.get_active_power_limits(x)
end

"""
Min and max input active power variable limits for hydro dispatch pumped storage
"""
function get_min_max_limits(
    x::PSY.HydroGen,
    ::Type{<:InputActivePowerVariableLimitsConstraint},
    ::Type{HydroDispatchPumpedStorage},
)
    return PSY.get_active_power_limits_pump(x)
end

######################## Energy balance constraints ############################

"""
This function defines the constraints for the water level (or state of charge)
for the Hydro Reservoir.
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{EnergyBalanceConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    V <: PSY.HydroEnergyReservoir,
    W <: AbstractHydroFormulation,
    X <: PM.AbstractPowerModel,
}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    names = [PSY.get_name(x) for x in devices]
    initial_conditions = get_initial_condition(container, InitialEnergyLevel(), V)
    energy_var = get_variable(container, EnergyVariable(), V)
    power_var = get_variable(container, ActivePowerVariable(), V)
    spillage_var = get_variable(container, WaterSpillageVariable(), V)

    constraint = add_constraints_container!(
        container,
        EnergyBalanceConstraint(),
        V,
        names,
        time_steps,
    )
    param = get_parameter_array(container, InflowTimeSeriesParameter(), V)
    multiplier = get_parameter_multiplier_array(container, InflowTimeSeriesParameter(), V)

    for ic in initial_conditions
        device = get_component(ic)
        name = PSY.get_name(device)
        constraint[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            energy_var[name, 1] ==
            get_value(ic) - power_var[name, 1] * fraction_of_hour -
            spillage_var[name, 1] * fraction_of_hour +
            param[name, 1] * multiplier[name, 1]
        )

        for t in time_steps[2:end]
            constraint[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                energy_var[name, t] ==
                energy_var[name, t - 1] + param[name, t] * multiplier[name, t] -
                power_var[name, t] * fraction_of_hour -
                spillage_var[name, t] * fraction_of_hour
            )
        end
    end
    return
end

"""
This function defines the constraints for the water level (or state of charge)
for the HydroPumpedStorage.
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{EnergyCapacityUpConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    V <: PSY.HydroPumpedStorage,
    W <: AbstractHydroFormulation,
    X <: PM.AbstractPowerModel,
}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    names = [PSY.get_name(x) for x in devices]
    initial_conditions = get_initial_condition(container, InitialEnergyLevelUp(), V)

    energy_var = get_variable(container, EnergyVariableUp(), V)
    powerin_var = get_variable(container, ActivePowerInVariable(), V)
    powerout_var = get_variable(container, ActivePowerOutVariable(), V)
    spillage_var = get_variable(container, WaterSpillageVariable(), V)

    constraint = add_constraints_container!(
        container,
        EnergyCapacityUpConstraint(),
        V,
        names,
        time_steps,
    )
    param = get_parameter_array(container, InflowTimeSeriesParameter(), V)
    multiplier = get_parameter_multiplier_array(container, InflowTimeSeriesParameter(), V)

    for ic in initial_conditions
        device = get_component(ic)
        efficiency = PSY.get_pump_efficiency(device)
        name = PSY.get_name(device)
        constraint[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            energy_var[name, 1] ==
            get_value(ic) +
            (
                powerin_var[name, 1] * efficiency - spillage_var[name, 1] -
                powerout_var[name, 1]
            ) * fraction_of_hour +
            param[name, 1] * multiplier[name, 1]
        )

        for t in time_steps[2:end]
            constraint[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                energy_var[name, t] ==
                energy_var[name, t - 1] +
                param[name, t] * multiplier[name, t] +
                (powerin_var[name, 1] - powerout_var[name, t] - spillage_var[name, t]) *
                fraction_of_hour
            )
        end
    end
    return
end

"""
Add energy capacity down constraints for hydro pumped storage
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{EnergyCapacityDownConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    V <: PSY.HydroPumpedStorage,
    W <: AbstractHydroFormulation,
    X <: PM.AbstractPowerModel,
}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    names = [PSY.get_name(x) for x in devices]
    initial_conditions = get_initial_condition(container, InitialEnergyLevelDown(), V)

    energy_var = get_variable(container, EnergyVariableDown(), V)
    powerin_var = get_variable(container, ActivePowerInVariable(), V)
    powerout_var = get_variable(container, ActivePowerOutVariable(), V)
    spillage_var = get_variable(container, WaterSpillageVariable(), V)

    constraint = add_constraints_container!(
        container,
        EnergyCapacityDownConstraint(),
        V,
        names,
        time_steps,
    )

    param = get_parameter_array(container, OutflowTimeSeriesParameter(), V)
    multiplier = get_parameter_multiplier_array(container, OutflowTimeSeriesParameter(), V)

    for ic in initial_conditions
        device = get_component(ic)
        efficiency = PSY.get_pump_efficiency(device)
        name = PSY.get_name(device)
        constraint[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            energy_var[name, 1] ==
            get_value(ic) -
            (
                spillage_var[name, 1] + powerout_var[name, 1] -
                powerin_var[name, 1] / efficiency
            ) * fraction_of_hour - param[name, 1] * multiplier[name, 1]
        )

        for t in time_steps[2:end]
            constraint[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                energy_var[name, t] ==
                energy_var[name, t - 1] - param[name, t] * multiplier[name, t] +
                (
                    powerout_var[name, 1] - powerin_var[name, t] / efficiency +
                    spillage_var[name, t]
                ) * fraction_of_hour
            )
        end
    end
    return
end

"""
Add energy target constraints for hydro gen
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{EnergyTargetConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {V <: PSY.HydroGen, W <: AbstractHydroFormulation, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    set_name = [PSY.get_name(d) for d in devices]
    constraint = add_constraints_container!(
        container,
        EnergyTargetConstraint(),
        V,
        set_name,
        time_steps,
    )

    e_var = get_variable(container, EnergyVariable(), V)
    shortage_var = get_variable(container, EnergyShortageVariable(), V)
    surplus_var = get_variable(container, EnergySurplusVariable(), V)
    param = get_parameter_array(container, EnergyTargetTimeSeriesParameter(), V)
    multiplier =
        get_parameter_multiplier_array(container, EnergyTargetTimeSeriesParameter(), V)

    for d in devices
        name = PSY.get_name(d)
        cost_data = PSY.get_operation_cost(d)
        if isa(cost_data, PSY.StorageManagementCost)
            shortage_cost = PSY.get_energy_shortage_cost(cost_data)
        else
            @debug "Data for device $name doesn't contain shortage costs"
            shortage_cost = 0.0
        end

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
                e_var[name, t] + shortage_var[name, t] + surplus_var[name, t] ==
                multiplier[name, t] * param[name, t]
            )
        end
    end
    return
end

##################################### Water/Energy Budget Constraint ############################
"""
This function define the budget constraint for the
active power budget formulation.

`` sum(P[t]) <= Budget ``
"""

function add_constraints!(
    container::OptimizationContainer,
    ::Type{EnergyBudgetConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {V <: PSY.HydroGen, W <: AbstractHydroFormulation, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    set_name = [PSY.get_name(d) for d in devices]
    constraint =
        add_constraints_container!(container, EnergyBudgetConstraint(), V, set_name)

    variable_out = get_variable(container, ActivePowerVariable(), V)
    param = get_parameter_array(container, EnergyBudgetTimeSeriesParameter(), V)
    multiplier =
        get_parameter_multiplier_array(container, EnergyBudgetTimeSeriesParameter(), V)

    for d in devices
        name = PSY.get_name(d)
        constraint[name] = JuMP.@constraint(
            container.JuMPmodel,
            sum([variable_out[name, t] for t in time_steps]) <= sum([multiplier[name, t] * param[name, t] for t in time_steps])
        )
    end
    return
end

##################################### Auxillary Variables ############################

function calculate_aux_variable_value!(
    container::OptimizationContainer,
    ::AuxVarKey{EnergyOutput, T},
    system::PSY.System,
) where {T <: PSY.HydroGen}
    devices = PSY.get_components(T, system)
    time_steps = get_time_steps(container)

    p_variable_results = get_variable(container, ActivePowerVariable(), T)
    aux_variable_container = get_aux_variable(container, EnergyOutput(), T)
    for d in devices, t in time_steps
        name = PSY.get_name(d)
        min = PSY.get_active_power_limits(d).min
        aux_variable_container[name, t] = jump_value(p_variable_results[name, t])
    end

    return
end

##################################### Hydro generation cost ############################
function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.HydroGen, U <: AbstractHydroUnitCommitment}
    add_variable_cost!(container, ActivePowerVariable(), devices, U())
    add_proportional_cost!(container, OnVariable(), devices, U())
    return
end

function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{PSY.HydroPumpedStorage},
    ::DeviceModel{PSY.HydroPumpedStorage, T},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: HydroDispatchPumpedStorage}
    add_variable_cost!(container, ActivePowerOutVariable(), devices, T())
    return
end

function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.HydroGen, U <: AbstractHydroDispatchFormulation}
    add_variable_cost!(container, ActivePowerVariable(), devices, U())
    return
end

function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {
    T <: PSY.HydroPumpedStorage,
    U <: Union{HydroDispatchReservoirStorage, HydroDispatchReservoirBudget},
}
    add_variable_cost!(container, ActivePowerOutVariable(), devices, U())
    add_proportional_cost!(container, EnergySurplusVariable(), devices, U())
    add_proportional_cost!(container, EnergyShortageVariable(), devices, U())
    return
end

function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.HydroEnergyReservoir, U <: HydroDispatchReservoirStorage}
    add_variable_cost!(container, ActivePowerVariable(), devices, U())
    add_proportional_cost!(container, EnergySurplusVariable(), devices, U())
    add_proportional_cost!(container, EnergyShortageVariable(), devices, U())
    return
end

function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.HydroEnergyReservoir, U <: HydroCommitmentReservoirStorage}
    add_variable_cost!(container, ActivePowerVariable(), devices, U())
    add_proportional_cost!(container, EnergySurplusVariable(), devices, U())
    add_proportional_cost!(container, EnergyShortageVariable(), devices, U())
    return
end
