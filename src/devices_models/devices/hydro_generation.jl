#! format: off

abstract type AbstractHydroFormulation <: AbstractDeviceFormulation end
abstract type AbstractHydroDispatchFormulation <: AbstractHydroFormulation end
abstract type AbstractHydroUnitCommitment <: AbstractHydroFormulation end
abstract type AbstractHydroReservoirFormulation <: AbstractHydroDispatchFormulation end
struct HydroDispatchRunOfRiver <: AbstractHydroDispatchFormulation end
struct HydroDispatchReservoirBudget <: AbstractHydroReservoirFormulation end
struct HydroDispatchReservoirStorage <: AbstractHydroReservoirFormulation end
struct HydroDispatchPumpedStorage <: AbstractHydroReservoirFormulation end
struct HydroCommitmentRunOfRiver <: AbstractHydroUnitCommitment end
struct HydroCommitmentReservoirBudget <: AbstractHydroUnitCommitment end
struct HydroCommitmentReservoirStorage <: AbstractHydroUnitCommitment end

get_variable_multiplier(_, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = 1.0
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

############## EnergySurplusVariable, HydroGen ####################

get_variable_binary(::EnergySurplusVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = false
get_variable_upper_bound(::EnergySurplusVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = 0.0
get_variable_lower_bound(::EnergySurplusVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = - PSY.get_storage_capacity(d)

get_multiplier_value(::EnergyBudgetTimeSeriesParameter, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_storage_capacity(d)
get_multiplier_value(::EnergyTargetTimeSeriesParameter, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_storage_capacity(d)
get_multiplier_value(::InflowTimeSeriesParameter, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_inflow(d) * PSY.get_conversion_factor(d)
get_multiplier_value(::OutflowTimeSeriesParameter, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_outflow(d) * PSY.get_conversion_factor(d)

get_multiplier_value(::TimeSeriesParameter, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_max_active_power(d)

get_multiplier_value(::TimeSeriesParameter, d::PSY.HydroGen, ::FixedOutput) = PSY.get_max_active_power(d)

#! format: on

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
    ::Type{T},
) where {T <: Union{HydroCommitmentReservoirBudget, HydroDispatchReservoirBudget}}
    return Dict{Type{<:TimeSeriesParameter}, String}(
        EnergyBudgetTimeSeriesParameter => "hydro_budget",
    )
end

function get_default_time_series_names(
    ::Type{PSY.HydroEnergyReservoir},
    ::Type{T},
) where {T <: Union{HydroDispatchReservoirStorage, HydroCommitmentReservoirStorage}}
    return Dict{Type{<:TimeSeriesParameter}, String}(
        EnergyTargetTimeSeriesParameter => "storage_target",
        InflowTimeSeriesParameter => "inflow",
    )
end

function get_default_time_series_names(
    ::Type{PSY.HydroPumpedStorage},
    ::Type{T},
) where {T <: HydroDispatchPumpedStorage}
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
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HydroGen, W <: HydroDispatchRunOfRiver}
    add_range_constraints!(container, T, U, devices, model, X, feedforward)
    add_parameterized_upper_bound_range_constraints(
        container,
        ActivePowerVariableTimeSeriesLimitsConstraint,
        U,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        X,
        feedforward,
    )
end

"""
Add semicontinuous range constraints for Hydro Unit Commitment formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{ActivePowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HydroGen, W <: HydroCommitmentRunOfRiver}
    add_semicontinuous_range_constraints!(container, T, U, devices, model, X, feedforward)
    add_parameterized_upper_bound_range_constraints(
        container,
        ActivePowerVariableTimeSeriesLimitsConstraint,
        U,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        X,
        feedforward,
    )
end

"""
Min and max reactive Power Variable limits
"""
function get_min_max_limits(
    x::PSY.HydroGen,
    ::Type{<:ReactivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHydroFormulation},
)
    PSY.get_reactive_power_limits(x)
end

"""
Min and max active Power Variable limits
"""
function get_min_max_limits(
    x::PSY.HydroGen,
    ::Type{<:ActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHydroFormulation},
)
    PSY.get_active_power_limits(x)
end

function get_min_max_limits(
    x::PSY.HydroGen,
    ::Type{<:ActivePowerVariableLimitsConstraint},
    ::Type{HydroDispatchRunOfRiver},
)
    return (min = 0.0, max = PSY.get_max_active_power(x))
end

"""
Add power variable limits constraints for hydro unit commitment formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:PowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HydroGen, W <: AbstractHydroUnitCommitment}
    add_semicontinuous_range_constraints!(container, T, U, devices, model, X, feedforward)
end

"""
Add power variable limits constraints for hydro dispatch formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:PowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HydroGen, W <: AbstractHydroDispatchFormulation}
    add_range_constraints!(container, T, U, devices, model, X, feedforward)
end

"""
Add input power variable limits constraints for hydro dispatch formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{InputActivePowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HydroPumpedStorage, W <: AbstractHydroReservoirFormulation}
    if get_attribute(model, "reservation")
        add_reserve_range_constraints!(container, T, U, devices, model, X, feedforward)
    else
        add_range_constraints!(container, T, U, devices, model, X, feedforward)
    end
end

"""
Add output power variable limits constraints for hydro dispatch formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:PowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HydroPumpedStorage, W <: AbstractHydroReservoirFormulation}
    if get_attribute(model, "reservation")
        add_reserve_range_constraints!(container, T, U, devices, model, X, feedforward)
    else
        add_range_constraints!(container, T, U, devices, model, X, feedforward)
    end
end

"""
Min and max output active power variable limits for hydro dispatch pumped storage
"""
function get_min_max_limits(
    x::PSY.HydroGen,
    ::Type{<:OutputActivePowerVariableLimitsConstraint},
    ::Type{HydroDispatchPumpedStorage},
)
    PSY.get_active_power_limits(x)
end

"""
Min and max input active power variable limits for hydro dispatch pumped storage
"""
function get_min_max_limits(
    x::PSY.HydroGen,
    ::Type{<:InputActivePowerVariableLimitsConstraint},
    ::Type{HydroDispatchPumpedStorage},
)
    PSY.get_active_power_limits_pump(x)
end

######################## RoR constraints ############################

"""
This function define the range constraint specs for the
reactive power for Commitment Run of River formulation.
    `` P <= multiplier * P_max ``
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{ActivePowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HydroGen, W <: AbstractHydroUnitCommitment}
    add_range_constraints!(container, T, U, devices, model, X, feedforward)
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
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    V <: PSY.HydroEnergyReservoir,
    W <: AbstractHydroFormulation,
    X <: PM.AbstractPowerModel,
}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    names = [PSY.get_name(x) for x in devices]
    initial_conditions = get_initial_conditions(container, InitialEnergyLevel(), V)
    energy_var = get_variable(container, EnergyVariable(), V)
    power_var = get_variable(container, ActivePowerVariable(), V)
    spillage_var = get_variable(container, WaterSpillageVariable(), V)

    constraint =
        add_cons_container!(container, EnergyBalanceConstraint(), V, names, time_steps)
    param = get_parameter_array(container, InflowTimeSeriesParameter(), V)
    multiplier = get_parameter_multiplier_array(container, InflowTimeSeriesParameter(), V)

    for ic in initial_conditions
        device = ic.device
        name = PSY.get_name(device)
        constraint[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            energy_var[name, 1] ==
            ic.value - power_var[name, 1] * fraction_of_hour -
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
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    V <: PSY.HydroPumpedStorage,
    W <: AbstractHydroFormulation,
    X <: PM.AbstractPowerModel,
}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    names = [PSY.get_name(x) for x in devices]
    initial_conditions = get_initial_conditions(container, InitialEnergyLevelUp(), V)

    energy_var = get_variable(container, EnergyVariableUp(), V)
    powerin_var = get_variable(container, ActivePowerInVariable(), V)
    powerout_var = get_variable(container, ActivePowerOutVariable(), V)
    spillage_var = get_variable(container, WaterSpillageVariable(), V)

    constraint =
        add_cons_container!(container, EnergyCapacityUpConstraint(), V, names, time_steps)
    param = get_parameter_array(container, InflowTimeSeriesParameter(), V)
    multiplier = get_parameter_multiplier_array(container, InflowTimeSeriesParameter(), V)

    for ic in initial_conditions
        device = ic.device
        efficiency = PSY.get_pump_efficiency(device)
        name = PSY.get_name(device)
        constraint[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            energy_var[name, 1] ==
            ic.value +
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
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {
    V <: PSY.HydroPumpedStorage,
    W <: AbstractHydroFormulation,
    X <: PM.AbstractPowerModel,
}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    names = [PSY.get_name(x) for x in devices]
    initial_conditions = get_initial_conditions(container, InitialEnergyLevelDown(), V)

    energy_var = get_variable(container, EnergyVariableDown(), V)
    powerin_var = get_variable(container, ActivePowerInVariable(), V)
    powerout_var = get_variable(container, ActivePowerOutVariable(), V)
    spillage_var = get_variable(container, WaterSpillageVariable(), V)

    constraint =
        add_cons_container!(container, EnergyCapacityDownConstraint(), V, names, time_steps)

    param = get_parameter_array(container, OutflowTimeSeriesParameter(), V)
    multiplier = get_parameter_multiplier_array(container, OutflowTimeSeriesParameter(), V)

    for ic in initial_conditions
        device = ic.device
        efficiency = PSY.get_pump_efficiency(device)
        name = PSY.get_name(device)
        constraint[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            energy_var[name, 1] ==
            ic.value -
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
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HydroGen, W <: AbstractHydroFormulation, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    inv_dt = 1.0 / (Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR)
    set_name = [PSY.get_name(d) for d in devices]
    constraint =
        add_cons_container!(container, EnergyTargetConstraint(), V, set_name, time_steps)

    e_var = get_variable(container, EnergyVariable(), V)
    shortage_var = get_variable(container, EnergyShortageVariable(), V)
    surplus_var = get_variable(container, EnergySurplusVariable(), V)
    param = get_parameter_array(container, EnergyTargetTimeSeriesParameter(), V)
    multiplier =
        get_parameter_multiplier_array(container, EnergyTargetTimeSeriesParameter(), V)

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
                e_var[name, t] + shortage_var[name, t] + surplus_var[name, t] ==
                multiplier[name, t] * param[name, t]
            )
        end
    end
    return
end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{H},
    device_formulation::AbstractHydroUnitCommitment,
) where {H <: PSY.HydroGen}
    add_initial_condition!(container, devices, formulation, DeviceStatus, OnVariable)
    add_initial_condition!(
        container,
        devices,
        formulation,
        DevicePower,
        ActivePowerVariable,
    )
    add_initial_condition!(container, devices, formulation, InitialTimeDurationOn)
    add_initial_condition!(container, devices, formulation, InitialTimeDurationOff)

    return
end

function initial_conditions!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{H},
    device_formulation::AbstractHydroDispatchFormulation,
) where {H <: PSY.HydroGen}
    add_initial_condition!(
        container,
        devices,
        formulation,
        DevicePower,
        ActivePowerVariable,
    )
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
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HydroGen, W <: AbstractHydroFormulation, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    # Variable not used. Check if needed Sourabh
    inv_dt = 1.0 / (Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR)
    set_name = [PSY.get_name(d) for d in devices]
    constraint = add_cons_container!(container, EnergyBudgetConstraint(), V, set_name)

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
