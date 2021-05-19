#! format: off

abstract type AbstractHybridFormulation <: AbstractDeviceFormulation end
abstract type AbstractHybridDisaptchFormulation <: AbstractDeviceFormulation end
struct PhysicalCoupling <: AbstractHybridFormulation end
struct FinancialCoupling <: AbstractHybridFormulation end
struct StandardHybridFormulation <: AbstractHybridFormulation end
struct TightCoupling <: AbstractHybridFormulation end

struct FinancialCouplingDisaptch <: AbstractHybridDisaptchFormulation end
struct StandardHybridFormulationDisaptch <: AbstractHybridDisaptchFormulation end

########################### ActivePowerInVariable, HybridSystem #################################

get_variable_binary(::ActivePowerInVariable, ::Type{PSY.HybridSystem}, _) = false
get_variable_expression_name(::ActivePowerInVariable, ::Type{PSY.HybridSystem}) = :nodal_balance_active
get_variable_sign(::ActivePowerInVariable, ::Type{PSY.HybridSystem}, _) = -1.0
get_variable_lower_bound(::ActivePowerInVariable, d::PSY.HybridSystem, _) = 0.0

########################### ActivePowerOutVariable, HybridSystem #################################

get_variable_binary(::ActivePowerOutVariable, ::Type{PSY.HybridSystem}, _) = false
get_variable_expression_name(::ActivePowerOutVariable, ::Type{PSY.HybridSystem}) = :nodal_balance_active
get_variable_lower_bound(::ActivePowerOutVariable, d::PSY.HybridSystem, _) = 0.0
get_variable_upper_bound(::ActivePowerOutVariable, d::PSY.HybridSystem, _) = PSY.get_output_active_power_limits(d).max
get_variable_sign(::ActivePowerOutVariable, ::Type{PSY.HybridSystem}, _) = 1.0

########################### ActivePowerShortageVariable, HybridSystem #################################

get_variable_binary(::ActivePowerShortageVariable, ::Type{PSY.HybridSystem}, _) = false
get_variable_lower_bound(::ActivePowerShortageVariable, d::PSY.HybridSystem, _) = 0.0
get_variable_upper_bound(::ActivePowerShortageVariable, d::PSY.HybridSystem, _) = PSY.get_output_active_power_limits(d).max
get_variable_sign(::ActivePowerShortageVariable, ::Type{PSY.HybridSystem}, _) = 1.0

########################### ActivePowerSurplusVariable, HybridSystem #################################

get_variable_binary(::ActivePowerSurplusVariable, ::Type{PSY.HybridSystem}, _) = false
get_variable_lower_bound(::ActivePowerSurplusVariable, d::PSY.HybridSystem, _) = 0.0
get_variable_upper_bound(::ActivePowerSurplusVariable, d::PSY.HybridSystem, _) = PSY.get_output_active_power_limits(d).max
get_variable_sign(::ActivePowerSurplusVariable, ::Type{PSY.HybridSystem}, _) = 1.0

############## SubComponentActivePowerVariable, HybridSystem ####################

get_variable_binary(::SubComponentActivePowerVariable, ::Type{PSY.HybridSystem}, _) = false
get_variable_lower_bound(::SubComponentActivePowerVariable, d::PSY.HybridSystem, _) = 0.0
get_variable_sign(::SubComponentActivePowerVariable, ::Type{PSY.HybridSystem}, _) = 1.0

############## SubComponentActivePowerInVariable, HybridSystem ####################

get_variable_binary(::SubComponentActivePowerInVariable, ::Type{PSY.HybridSystem}, _) = false
get_variable_lower_bound(::SubComponentActivePowerInVariable, d::PSY.HybridSystem, _) = 0.0
get_variable_sign(::SubComponentActivePowerInVariable, ::Type{PSY.HybridSystem}, _) = -1.0

############## SubComponentActivePowerOutVariable, HybridSystem ####################

get_variable_binary(::SubComponentActivePowerOutVariable, ::Type{PSY.HybridSystem}, _) = false
get_variable_lower_bound(::SubComponentActivePowerOutVariable, d::PSY.HybridSystem, _) = 0.0
get_variable_sign(::SubComponentActivePowerOutVariable, ::Type{PSY.HybridSystem}, _) = 1.0
############## SubComponentEnergyVariable, HybridSystem ####################

get_variable_binary(::SubComponentEnergyVariable, ::Type{PSY.HybridSystem}, _) = false
get_variable_lower_bound(::SubComponentEnergyVariable, d::PSY.HybridSystem, _) = 0.0
get_variable_sign(::SubComponentEnergyVariable, ::Type{PSY.HybridSystem}, _) = 1.0
get_variable_initial_value(::SubComponentEnergyVariable, d::PSY.HybridSystem, _) = PSY.get_initial_energy(PSY.get_storage(d))
############## EnergyVariable, HybridSystem-Storage ####################

get_variable_binary(::EnergyVariable, ::Type{PSY.HybridSystem}, _) = false
get_variable_lower_bound(::EnergyVariable, d::PSY.HybridSystem, _) = 0.0
get_variable_sign(::EnergyVariable, ::Type{PSY.HybridSystem}, _) = 1.0
get_variable_initial_value(::EnergyVariable, d::PSY.HybridSystem, _) = PSY.get_initial_energy(PSY.get_storage(d))
############## ReactivePowerVariable, HybridSystem ####################

get_variable_binary(::ReactivePowerVariable, ::Type{PSY.HybridSystem}, _) = false
get_variable_expression_name(::ReactivePowerVariable, ::Type{PSY.HybridSystem}) = :nodal_balance_reactive
get_variable_sign(::ReactivePowerVariable, ::Type{PSY.HybridSystem}, _) = 1.0

############## SubComponentReactivePowerVariable, ThermalGen ####################

get_variable_binary(::SubComponentReactivePowerVariable, ::Type{PSY.HybridSystem}, _) = false
get_variable_sign(::SubComponentReactivePowerVariable, ::Type{PSY.HybridSystem}, _) = 1.0

####################

get_efficiency(v::T, var::Type{<:InitialConditionType}) where T <: PSY.HybridSystem = PSY.get_efficiency(PSY.get_storage(v))

########################### Active Device Range Constraint #################################

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ActivePowerInVariable},
    ::Type{T},
    ::Type{<:AbstractHybridFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HybridSystem}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(RangeConstraint, ActivePowerInVariable, T),
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
    ::Type{<:AbstractHybridFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HybridSystem}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(RangeConstraint, ActivePowerOutVariable, T),
            variable_name = make_variable_name(ActivePowerOutVariable, T),
            limits_func = x -> PSY.get_output_active_power_limits(x),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{SubComponentActivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractHybridFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HybridSystem}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(RangeConstraint, ActivePowerVariable, T),
            variable_name = make_variable_name(SubComponentActivePowerVariable, T),
            limits_func = x -> PSY.get_active_power_limits(PSY.get_thermal_unit(x)),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
            subcomponent_type = PSY.ThermalGen,
        ),
        devices_filter_func = x -> !isnothing(PSY.get_thermal_unit(x))
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:ElectricLoadRangeConstraint},
    ::Type{SubComponentActivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractHybridFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HybridSystem}
    if (!use_parameters && !use_forecasts)
        return DeviceRangeConstraintSpec(;
            range_constraint_spec = RangeConstraintSpec(;
                constraint_name = make_constraint_name(ElectricLoadRangeConstraint, SubComponentActivePowerVariable, T),
                variable_name = make_variable_name(SubComponentActivePowerVariable, T),
                limits_func = x -> (min = 0.0, max = PSY.get_max_active_power(PSY.get_electric_load(x))),
                constraint_func = device_range!,
                constraint_struct = DeviceRangeConstraintInfo,
                subcomponent_type = PSY.ElectricLoad,
            ),
            devices_filter_func = x -> !isnothing(PSY.get_electric_load(x))
        )
    end

    return DeviceRangeConstraintSpec(;
        timeseries_range_constraint_spec = TimeSeriesConstraintSpec(
            constraint_name = make_constraint_name(ElectricLoadRangeConstraint, SubComponentActivePowerVariable, T),
            variable_name = make_variable_name(SubComponentActivePowerVariable, T),
            parameter_name = use_parameters ? ACTIVE_POWER : nothing,
            forecast_label = "max_active_power",
            multiplier_func = x -> PSY.get_max_active_power(PSY.get_electric_load(x)),
            constraint_func = use_parameters ? device_timeseries_param_ub! :
                              device_timeseries_ub!,
            subcomponent_type = PSY.ElectricLoad,
        ),
        devices_filter_func = x -> !isnothing(PSY.get_electric_load(x))
    )

end


function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{SubComponentActivePowerInVariable},
    ::Type{T},
    ::Type{<:AbstractHybridFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HybridSystem}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(RangeConstraint, SubComponentActivePowerInVariable, T),
            variable_name = make_variable_name(SubComponentActivePowerInVariable, T),
            limits_func = x -> PSY.get_input_active_power_limits(PSY.get_storage(x)),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
            subcomponent_type = PSY.Storage,
        ),
        devices_filter_func = x -> !isnothing(PSY.get_storage(x))
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{SubComponentActivePowerOutVariable},
    ::Type{T},
    ::Type{<:AbstractHybridFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HybridSystem}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(RangeConstraint, SubComponentActivePowerOutVariable, T),
            variable_name = make_variable_name(SubComponentActivePowerOutVariable, T),
            limits_func = x -> PSY.get_output_active_power_limits(PSY.get_storage(x)),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
            subcomponent_type = PSY.Storage,
        ),
        devices_filter_func = x -> !isnothing(PSY.get_storage(x))
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RenewableGenRangeConstraint},
    ::Type{SubComponentActivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractHybridFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HybridSystem}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(RenewableGenRangeConstraint, SubComponentActivePowerVariable, T),
            variable_name = make_variable_name(SubComponentActivePowerVariable, T),
            limits_func = x -> (min = 0.0, max = PSY.get_rating(PSY.get_renewable_unit(x))),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
            subcomponent_type = PSY.RenewableGen,
        ),
        devices_filter_func = x -> !isnothing(PSY.get_renewable_unit(x))
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RenewableGenRangeConstraint},
    ::Type{SubComponentActivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractHybridFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.RenewableGen}
    if !use_parameters && !use_forecasts
        return DeviceRangeConstraintSpec(;
            range_constraint_spec = RangeConstraintSpec(;
                constraint_name = make_constraint_name(
                    RenewableGenRangeConstraint,
                    SubComponentActivePowerVariable,
                    T,
                ),
                variable_name = make_variable_name(SubComponentActivePowerVariable, T),
                limits_func = x -> (min = 0.0, max = PSY.get_rating(PSY.get_renewable_unit(x))),
                constraint_func = device_range!,
                constraint_struct = DeviceRangeConstraintInfo,
                subcomponent_type = PSY.RenewableGen,
            ),
            devices_filter_func = x -> !isnothing(PSY.get_renewable_unit(x))
        )
    end

    return DeviceRangeConstraintSpec(;
        timeseries_range_constraint_spec = TimeSeriesConstraintSpec(;
            constraint_name = make_constraint_name(RenewableGenRangeConstraint, SubComponentActivePowerVariable, T),
            variable_name = make_variable_name(SubComponentActivePowerVariable, T),
            parameter_name = use_parameters ? ACTIVE_POWER : nothing,
            forecast_label = "max_active_power",
            multiplier_func = x -> PSY.get_max_active_power(x),
            constraint_func = use_parameters ? device_timeseries_param_ub! :
                              device_timeseries_ub!,
            subcomponent_type = PSY.RenewableGen,
        ),
        devices_filter_func = x -> !isnothing(PSY.get_renewable_unit(x))
    )
end



########################### Reactive Device Range Constraint #################################

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractHybridFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HybridSystem}
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

function DeviceRangeConstraintSpec(
    ::Type{<:ThermalRangeConstraint},
    ::Type{SubComponentReactivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractHybridFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HybridSystem}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(
                ThermalRangeConstraint,
                SubComponentReactivePowerVariable,
                T,
            ),
            variable_name = make_variable_name(SubComponentReactivePowerVariable, T),
            limits_func = x -> PSY.get_reactive_power_limits(PSY.get_thermal_unit(x)),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
            subcomponent_type = PSY.ThermalGen,
        ),
        devices_filter_func = x -> !isnothing(PSY.get_thermal_unit(x))
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:ElectricLoadRangeConstraint},
    ::Type{SubComponentReactivePowerVariable},
    ::Type{<:PSY.HybridSystem},
    ::Type{<:AbstractHybridFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
)
    return DeviceRangeConstraintSpec(;
        custom_optimization_container_func = custom_reactive_power_constraints!,
        devices_filter_func = x -> !isnothing(PSY.get_electric_load(x))
    )
end

function custom_reactive_power_constraints!(
    psi_container::OptimizationContainer,
    devices::Union{Vector{T}, IS.FlattenIteratorWrapper{T}},
    ::Type{<:AbstractHybridFormulation},
) where {T <: PSY.HybridSystem}
    time_steps = model_time_steps(psi_container)
    constraint = JuMPConstraintArray(undef, [PSY.get_name(d) for d in devices], time_steps)
    assign_constraint!(psi_container, SUBCOMPONENT_REACTIVE_POWER, T, constraint)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        load = PSY.get_electric_load(d)
        idx = get_index(name, t, PSY.ElectricLoad)
        pf = sin(atan((PSY.get_max_reactive_power(load) / PSY.get_max_active_power(load))))
        reactive = get_variable(psi_container, SUBCOMPONENT_REACTIVE_POWER, T)[idx]
        real = get_variable(psi_container, SUBCOMPONENT_ACTIVE_POWER, T)[idx] * pf
        constraint[name, t] = JuMP.@constraint(psi_container.JuMPmodel, reactive == real)
    end
end

function DeviceRangeConstraintSpec(
    ::Type{<:StorageRangeConstraint},
    ::Type{SubComponentReactivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractHybridFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HybridSystem}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(
                StorageRangeConstraint,
                SubComponentReactivePowerVariable,
                T,
            ),
            variable_name = make_variable_name(SubComponentReactivePowerVariable, T),
            limits_func = x -> PSY.get_reactive_power_limits(PSY.get_storage(x)),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
            subcomponent_type = PSY.Storage,
        ),
        devices_filter_func = x -> !isnothing(PSY.get_storage(x))
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RenewableGenRangeConstraint},
    ::Type{SubComponentReactivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractHybridFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.HybridSystem}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(
                RenewableGenRangeConstraint,
                SubComponentReactivePowerVariable,
                T,
            ),
            variable_name = make_variable_name(SubComponentReactivePowerVariable, T),
            limits_func = x -> PSY.get_reactive_power_limits(PSY.get_renewable_unit(x)),
            constraint_func = device_range!,
            constraint_struct = DeviceRangeConstraintInfo,
            subcomponent_type = PSY.RenewableGen,
        ),
        devices_filter_func = x -> !isnothing(PSY.get_renewable_unit(x))
    )
end

############################ Energy Capacity Constraints####################################

function energy_capacity_constraints!(
    psi_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{H},
    model::DeviceModel{H, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {H <: PSY.HybridSystem, D <: AbstractHybridFormulation, S <: PM.AbstractPowerModel}
    constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    idx = 0
    for (ix, d) in enumerate(devices)
        if !isnothing(PSY.get_storage(d))
            idx += 1
            name = PSY.get_name(d)
            limits = PSY.get_state_of_charge_limits(PSY.get_storage(d))
            constraint_info = DeviceRangeConstraintInfo(name, limits)
            add_device_services!(constraint_info, d, model)
            constraint_infos[idx] = constraint_info
        end
    end
    if idx < length(devices)
        deleteat!(constraint_infos, (idx + 1):length(devices))
    end

    if !isempty(constraint_infos)
        device_range!(
            psi_container,
            RangeConstraintSpecInternal(;
                constraint_infos = constraint_infos,
                constraint_name = make_constraint_name(ENERGY_CAPACITY, H),
                variable_name = make_variable_name(SUBCOMPONENT_ENERGY, H),
                subcomponent_type = PSY.Storage
            ),
        )
    end
    return
end


############################ Battery constraints ######################################

function DeviceEnergyBalanceConstraintSpec(
    ::Type{<:EnergyBalanceConstraint},
    ::Type{SubComponentEnergyVariable},
    ::Type{H},
    ::Type{<:AbstractHybridFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {H <: PSY.HybridSystem}
    return DeviceEnergyBalanceConstraintSpec(;
        constraint_name = make_constraint_name(ENERGY_LIMIT, H),
        energy_variable = make_variable_name(SUBCOMPONENT_ENERGY, H),
        initial_condition = InitialEnergyLevel,
        pin_variable_names = [make_variable_name(SUBCOMPONENT_ACTIVE_POWER_IN, H)],
        pout_variable_names = [make_variable_name(SUBCOMPONENT_ACTIVE_POWER_OUT, H)],
        constraint_func = energy_balance!,
        subcomponent_type = PSY.Storage
    )
end


################### Power Flow constraint #############################

function power_inflow_constraints!(
    psi_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{H},
    ::DeviceModel{H, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {H <: PSY.HybridSystem, D <: AbstractHybridFormulation, S <: PM.AbstractPowerModel}

    constraint_infos = Vector{HybridPowerInflowConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        has_load = !isnothing(PSY.get_electric_load(d))
        has_storage = !isnothing(PSY.get_storage(d))
        constraint_info = HybridPowerInflowConstraintInfo(name, has_load, has_storage)
        constraint_infos[ix] = constraint_info
    end

    power_inflow(
        psi_container,
        constraint_infos,
        make_constraint_name(POWER_BALANCE_INFLOW, H),
        (
            make_variable_name(ACTIVE_POWER_IN, H),
            make_variable_name(SUBCOMPONENT_ACTIVE_POWER, H),
            make_variable_name(SUBCOMPONENT_ACTIVE_POWER_IN, H),
        ),
    )
    return
end

function power_inflow_constraints!(
    psi_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{H},
    ::DeviceModel{H, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {H <: PSY.HybridSystem, D <: TightCoupling, S <: PM.AbstractPowerModel}

    constraint_infos = Vector{Tuple{HybridPowerInflowConstraintInfo, HybridPowerOutflowConstraintInfo}}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        has_load = !isnothing(PSY.get_electric_load(d))
        has_storage = !isnothing(PSY.get_storage(d))
        has_thermal = !isnothing(PSY.get_thermal_unit(d))
        has_renewable = !isnothing(PSY.get_renewable_unit(d))
        constraint_info = (HybridPowerInflowConstraintInfo(name, has_load, has_storage),
            HybridPowerOutflowConstraintInfo(name, has_thermal, has_storage, has_renewable)
        )
        constraint_infos[ix] = constraint_info
    end

    power_inflow(
        psi_container,
        constraint_infos,
        (
            make_constraint_name(POWER_BALANCE_INFLOW, H),
            make_constraint_name(BATTERY_COUPLING, H),
        ),
        (
            make_variable_name(ACTIVE_POWER_IN, H),
            make_variable_name(SUBCOMPONENT_ACTIVE_POWER, H),
            make_variable_name(SUBCOMPONENT_ACTIVE_POWER_IN, H),
        ),
    )
    return
end

function power_outflow_constraints!(
    psi_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{H},
    ::DeviceModel{H, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {H <: PSY.HybridSystem, D <: AbstractHybridFormulation, S <: PM.AbstractPowerModel}

    constraint_infos = Vector{HybridPowerOutflowConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        has_thermal = !isnothing(PSY.get_thermal_unit(d))
        has_renewable = !isnothing(PSY.get_renewable_unit(d))
        has_storage = !isnothing(PSY.get_storage(d))
        constraint_info = HybridPowerOutflowConstraintInfo(name, has_thermal, has_storage, has_renewable)
        constraint_infos[ix] = constraint_info
    end

    power_outflow(
        psi_container,
        constraint_infos,
        make_constraint_name(POWER_BALANCE_OUTFLOW, H),
        (
            make_variable_name(ACTIVE_POWER_OUT, H),
            make_variable_name(SUBCOMPONENT_ACTIVE_POWER, H),
            make_variable_name(SUBCOMPONENT_ACTIVE_POWER_OUT, H),
        ),
    )
    return
end

function reactive_power_constraints!(
    psi_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{H},
    ::DeviceModel{H, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {H <: PSY.HybridSystem, D <: AbstractHybridFormulation, S <: PM.AbstractPowerModel}

    constraint_infos = Vector{HybridReactiveConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        has_load = !isnothing(PSY.get_electric_load(d))
        has_storage = !isnothing(PSY.get_storage(d))
        has_thermal = !isnothing(PSY.get_thermal_unit(d))
        has_renewable = !isnothing(PSY.get_renewable_unit(d))
        constraint_info = HybridReactiveConstraintInfo(name, has_thermal, has_storage, has_renewable, has_load)
        constraint_infos[ix] = constraint_info
    end

    reactive_balance(
        psi_container,
        constraint_infos,
        make_constraint_name(REACTIVE, H),
        (
            make_variable_name(REACTIVE_POWER, H),
            make_variable_name(SUBCOMPONENT_REACTIVE_POWER, H),
        ),
    )
    return
end


function invertor_rating_constraints!(
    psi_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{H},
    ::DeviceModel{H, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {H <: PSY.HybridSystem, D <: AbstractHybridFormulation, S <: PM.AbstractPowerModel}

    constraint_infos = Vector{HybridInvertorConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        rating = PSY.get_interconnection_rating(d)
        constraint_info = HybridInvertorConstraintInfo(name, rating)
        constraint_infos[ix] = constraint_info
    end

    invertor_rating(
        psi_container,
        constraint_infos,
        make_constraint_name(INVERTOR_LIMIT, H),
        (
            make_variable_name(ACTIVE_POWER_OUT, H),
            make_variable_name(ACTIVE_POWER_IN, H),
            make_variable_name(REACTIVE_POWER, H),
        ),
    )
    return
end

########################### Initial Conditions #############################################

function initial_conditions!(
    psi_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::D,
) where {T <: PSY.HybridSystem, D <: AbstractHybridFormulation}
    # output_init(psi_container, devices)
    storage_energy_initial_condition!(psi_container, devices, D())
    return
end

function storage_energy_initial_condition!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::D,
) where {T <: PSY.HybridSystem, D <: AbstractHybridFormulation}
    key = ICKey(InitialEnergyLevel, T)
    _make_initial_conditions!(
        optimization_container,
        devices,
        D(),
        SubComponentEnergyVariable(),
        key,
        _make_initial_condition_energy,
        _get_variable_initial_value,
        StoredEnergy,
    )
    return
end

########################### Cost Function Calls#############################################

function AddCostSpec(
    ::Type{T},
    ::Type{U},
    psi_container::OptimizationContainer,
) where {T <: PSY.HybridSystem, U <: AbstractHybridFormulation}
    return AddCostSpec(;
        variable_type = ActivePowerOutVariable,
        component_type = T,
        variable_cost = PSY.get_variable,
        fixed_cost = PSY.get_fixed,
    )
end

function AddCostSpec(
    ::Type{T},
    ::Type{PhysicalCoupling},
    ::Type{<:PSY.ThermalGen},
    psi_container::OptimizationContainer,
) where {T <: PSY.HybridSystem}

    return AddCostSpec(;
        variable_type = SubComponentActivePowerVariable,
        component_type = T,
        has_status_variable = has_on_variable(psi_container, T),
        has_status_parameter = has_on_parameter(psi_container, T),
        variable_cost = PSY.get_variable,
        fixed_cost = PSY.get_fixed,
        sos_status = SOSStatusVariable.NO_VARIABLE,
        subcomponent_type = PSY.ThermalGen
    )
end

function AddCostSpec(
    ::Type{T},
    ::Type{PhysicalCoupling},
    ::Type{<:PSY.ControllableLoad},
    ::OptimizationContainer,
) where {T <: PSY.HybridSystem}
    cost_function = x -> (x == nothing ? 1.0 : PSY.get_variable(x))
    return AddCostSpec(;
        variable_type = SubComponentActivePowerVariable,
        component_type = T,
        variable_cost = cost_function,
        multiplier = OBJECTIVE_FUNCTION_NEGATIVE,
        subcomponent_type = PSY.ElectricLoad
    )
end


function cost_function!(
    psi_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    device_model::DeviceModel{T, PhysicalCoupling},
    network_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward} = nothing,
) where {T <: PSY.HybridSystem}
    for d in devices
        cost_function!(psi_container, d, device_model, network_formulation, feedforward)
    end
    return
end

function cost_function!(
    psi_container::OptimizationContainer,
    device::PSY.HybridSystem,
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward} = nothing,
) where {T <: PSY.HybridSystem, U <: AbstractHybridFormulation} 

    components = _get_components(device)
    for comp in components
        if has_cost_data(comp) 
            spec = AddCostSpec(T, U, typeof(comp), psi_container)
            @debug T, spec
            add_to_cost!(psi_container, spec, PSY.get_operation_cost(comp), device)
        end
    end
end


function _get_components(value::PSY.HybridSystem)
    components =
        [value.thermal_unit, value.electric_load, value.storage, value.renewable_unit]
    filter!(x -> !isnothing(x), components)
    return components
end

has_cost_data(v::PSY.Component) = false
has_cost_data(v::Union{PSY.ThermalGen, PSY.ControllableLoad}) = true
