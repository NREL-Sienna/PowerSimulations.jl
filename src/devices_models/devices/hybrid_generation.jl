abstract type AbstractHybridFormulation <: AbstractDeviceFormulation end
abstract type AbstractStandardHybridFormulation <: AbstractHybridFormulation end
struct BasicHybridDispatch <: AbstractHybridFormulation end
struct StandardHybridDispatch <: AbstractStandardHybridFormulation end

requires_initialization(::AbstractHybridFormulation) = false

get_variable_multiplier(_, ::Type{<:PSY.HybridSystem}, ::AbstractHybridDisaptchFormulation) = 1.0
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.ThermalGen}, ::Type{<:PSY.Reserve{PSY.ReserveUp}}) = ActivePowerRangeExpressionUB
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.ThermalGen}, ::Type{<:PSY.Reserve{PSY.ReserveDown}}) = ActivePowerRangeExpressionLB

########################### ActivePowerOutVariable, HybridSystem #################################
get_variable_binary(::ActivePowerVariable, ::Type{PSY.HybridSystem}, ::AbstractHybridFormulation ) = false
get_variable_warm_start_value(::ActivePowerVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_active_power(d)
get_variable_lower_bound(::ActivePowerVariable, d::PSY.HybridSystem, ::AbstractStandardHybridFormulation) = -1.0 * get_input_active_power_limits(d).max

get_variable_lower_bound(::ActivePowerVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = get_input_active_power_limits(d).min

get_variable_upper_bound(::ActivePowerVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_output_active_power_limits(d).max

############## ComponentActivePowerVariable, HybridSystem ####################
get_variable_binary(::ComponentActivePowerVariable, ::Type{PSY.HybridSystem}, ::AbstractHybridFormulation) = false
get_variable_lower_bound(::ComponentActivePowerVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = 0.0

############## ActivePowerInVariable, HybridSystem ####################
get_variable_binary(::ActivePowerInVariable, ::Type{PSY.HybridSystem}, ::AbstractHybridFormulation) = false
get_variable_lower_bound(::ActivePowerInVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_input_active_power_limits(d).min
get_variable_upper_bound(::ActivePowerInVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_input_active_power_limits(d).max

############## ActivePowerOutVariable, HybridSystem ####################
get_variable_binary(::ActivePowerOutVariable, ::Type{PSY.HybridSystem}, ::AbstractHybridFormulation) = false
get_variable_upper_bound(::ActivePowerOutVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_output_active_power_limits(d).max
get_variable_lower_bound(::ActivePowerOutVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_output_active_power_limits(d).min

############## EnergyVariable, HybridSystem ####################
get_variable_binary(::EnergyVariable, ::Type{PSY.HybridSystem}, ::AbstractHybridFormulation) = false
get_variable_upper_bound(::EnergyVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_state_of_charge_limits(PSY.get_storage(d)).max
get_variable_lower_bound(::EnergyVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_state_of_charge_limits(PSY.get_storage(d)).min
get_variable_warm_start_value(::EnergyVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_initial_energy(PSY.get_storage(d))

############## ReactivePowerVariable, HybridSystem ####################
get_variable_binary(::ReactivePowerVariable, ::Type{PSY.HybridSystem}, ::AbstractHybridFormulation) = false
get_variable_upper_bound(::ReactivePowerVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_reactive_power_limits(PSY.get_storage(d)).max
get_variable_lower_bound(::ReactivePowerVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_reactive_power_limits(PSY.get_storage(d)).min
get_variable_warm_start_value(::ReactivePowerVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_reactive_power(PSY.get_storage(d))

############## ComponentReactivePowerVariable, ThermalGen ####################
get_variable_binary(::ComponentReactivePowerVariable, ::Type{PSY.HybridSystem}, ::AbstractHybridFormulation) = false
get_variable_lower_bound(::ComponentReactivePowerVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = 0.0

############## SubComponentReserveVariable, HybridSystem ####################
get_variable_binary(::SubComponentReserveVariable, ::Type{<:PSY.HybridSystem}, ::AbstractHybridFormulation) = true
get_variable_lower_bound(::SubComponentReserveVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = 0.0

####################

initial_condition_default(::InitialEnergyLevel, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_initial_energy(PSY.get_storage(d))
initial_condition_variable(::InitialEnergyLevel, d::PSY.HybridSystem, ::AbstractHybridFormulation) = EnergyVariable()

get_initial_conditions_device_model(
    ::DeviceModel{T, <:AbstractHybridFormulation},
) where {T <: PSY.HybridSystem} = DeviceModel(T, BasicHybridDisaptch)

get_multiplier_value(::ActivePowerTimeSeriesParameter, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_max_active_power(get_renewable_unit(d))


check_subcomponent_exist(v::PSY.HybridSystem, ::Type{PSY.ThermalGen}) =
    isnothing(PSY.get_thermal_unit(v)) ? false : true
check_subcomponent_exist(v::PSY.HybridSystem, ::Type{PSY.RenewableGen}) =
    isnothing(PSY.get_renewable_unit(v)) ? false : true
check_subcomponent_exist(v::PSY.HybridSystem, ::Type{PSY.ElectricLoad}) =
    isnothing(PSY.get_electric_load(v)) ? false : true
check_subcomponent_exist(v::PSY.HybridSystem, ::Type{PSY.Storage}) =
    isnothing(PSY.get_storage(v)) ? false : true

function get_default_time_series_names(
    ::Type{<:PSY.HybridSystem},
    ::Type{<:Union{FixedOutput, AbstractHybridFormulation}},
)
    return Dict{Type{<:TimeSeriesParameter}, String}(
        ActivePowerTimeSeriesParameter => "max_active_power",
        # EnergyTargetTimeSeriesParameter => "storage_target",
    )
end

function get_default_attributes(
    ::Type{<:PSY.HybridSystem},
    ::Type{<:AbstractHybridFormulation},
)
    return Dict{String, Any}("reservation" => true)
end

################################ output power constraints ###########################

get_min_max_limits(
    device::PSY.HybridSystem,
    ::Type{<:ReactivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHybridFormulation},
) = PSY.get_reactive_power_limits(device)

get_min_max_limits(
    device::PSY.HybridSystem,
    ::Type{InputActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHybridFormulation},
) = PSY.get_input_active_power_limits(PSY.get_storage(device))

get_min_max_limits(
    device::PSY.HybridSystem,
    ::Type{OutputActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHybridFormulation},
) = PSY.get_output_active_power_limits(PSY.get_storage(device))

get_min_max_limits(
    device::PSY.RenewableGen,
    ::Type{ComponentActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHybridFormulation},
) = PSY.get_active_power_limits(PSY.get_thermal_unit(device))

get_min_max_limits(
    device::PSY.HybridSystem,
    ::Type{ActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHybridFormulation},
) = (min = PSY.get_input_active_power_limits(device).max, max = PSY.get_output_active_power_limits(device).max)

get_min_max_limits(
    device::PSY.HybridSystem,
    ::PSY.ThermalGen,
    ::Type{ComponentReactivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHybridFormulation},
) = PSY.get_reactive_power_limits(PSY.get_thermal_unit(device))

get_min_max_limits(
    device::PSY.HybridSystem,
    ::PSY.RenewableGen,
    ::Type{ComponentActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHybridFormulation},
) = PSY.get_reactive_power_limits(PSY.get_renewable_unit(device))

get_min_max_limits(
    device::PSY.HybridSystem,
    ::Type{EnergyCapacityConstraint},
    ::Type{<:AbstractHybridFormulation},
) = PSY.get_state_of_charge_limits(PSY.get_storage(device))


function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:PowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    add_range_constraints!(container, T, U, devices, model, X, feedforward)
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{ComponentActivePowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    add_range_constraints!(container, T, U, devices, model, X, feedforward)
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{InputActivePowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    if get_attribute(model, "reservation")
        add_reserve_range_constraints!(container, T, U, devices, model, X, feedforward)
    else
        add_range_constraints!(container, T, U, devices, model, X, feedforward)
    end
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{OutputActivePowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    if get_attribute(model, "reservation")
        add_reserve_range_constraints!(container, T, U, devices, model, X, feedforward)
    else
        add_range_constraints!(container, T, U, devices, model, X, feedforward)
    end
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{EnergyVariableLimitConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    add_range_constraints!(
        container,
        T,
        U,
        devices,
        model,
        X,
        feedforward,
    )
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{ComponentReactivePowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    time_steps = get_time_steps(container)
    var = get_variable(container, ComponentReactivePowerVariable(), V)
    device_names = [PSY.get_name(d) for d in devices]
    subcomp_types = get_subcomponent_var_types(variable_type)

    constraint_ub = add_cons_container!(container, ReactiveRangeConstraint(), V, device_names, subcomp_types, time_steps; meta = "ub", sparse = true)
    constraint_lb = add_cons_container!(container, ReactiveRangeConstraint(), V, device_names, subcomp_types, time_steps; meta = "lb", sparse = true)

    for t in time_steps, d in devices, subcomp in subcomp_types
        !check_subcomponent_exist(d, subcomp) && continue
        name = PSY.get_name(device)
        limits = get_min_max_limits(device,subcomp, T, W)
        constraint_ub[name, subcomp, t] =
            JuMP.@constraint(container.JuMPmodel, var[name, subcomp, t] <= limits.max)
        constraint_lb[name, subcomp, t] =
            JuMP.@constraint(container.JuMPmodel, var[name, subcomp, t] >= limits.min)
    end
            
end
######################## Energy balance constraints ############################

function add_constraints!(
    container::OptimizationContainer,
    ::Type{EnergyBalanceConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    names = [PSY.get_name(x) for x in devices if !isnothing(PSY.get_storage(device))]
    initial_conditions = get_initial_condition(container, InitialEnergyLevel(), V)
    energy_var = get_variable(container, EnergyVariable(), V)
    powerin_var = get_variable(container, ActivePowerInVariable(), V)
    powerout_var = get_variable(container, ActivePowerOutVariable(), V)

    constraint =
        add_cons_container!(container, EnergyBalanceConstraint(), V, names, time_steps)

    for ic in initial_conditions
        device = get_component(ic)
        isnothing(PSY.get_storage(device)) && continue
        storage_device = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage_device)
        name = PSY.get_name(device)
        constraint[name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            energy_var[name, 1] ==
            get_value(ic) +
            (powerin_var[name, 1] * efficiency.in -
                (powerout_var[name, 1] / efficiency.out)
            ) * fraction_of_hour
        )

        for t in time_steps[2:end]
            constraint[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                energy_var[name, t] ==
                energy_var[name, t - 1] +
                (powerin_var[name, t] * efficiency.in -
                    (powerout_var[name, t] / efficiency.out)
                ) * fraction_of_hour
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{PowerOutputRangeConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, D},
    ::Type{X},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HybridSystem, D <: AbstractHybridFormulation, X <: PM.AbstractPowerModel}

    time_steps = model_time_steps(container)
    name_index = [PSY.get_name(d) for d in devices]

    var_p = get_variable(container, ActivePowerVariable(), V)
    var_sub_p = get_variable(container, ComponentActivePowerVariable(), V)
    var_out = get_variable(container, ActivePowerOutVariable(), V)
    var_in = get_variable(container, ActivePowerInVariable(), V)

    constraint = add_cons_container!(container, PowerOutputRangeConstraint(), V, name_index, time_steps)

    for d in devices, t in time_steps
        name = PSY.get_name(d)

        constraint[name, t] =
            JuMP.@constraint(container.JuMPmodel, 
            var_p[name, t] == var_sub_p[name, PSY.RenewableGen, t] 
                + var_sub_p[name, PSY.ThermalGen, t] 
                + var_out[name, t] - var_in[name, t]
            )
    end

    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{ReactivePowerConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, D},
    ::Type{X},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HybridSystem, D <: AbstractHybridFormulation, X <: PM.AbstractPowerModel}

    time_steps = model_time_steps(container)
    name_index = [PSY.get_name(d) for d in devices]

    var_q = get_variable(container, ReactivePowerVariable(), V)
    var_sub_q = get_variable(container, ComponentReactivePowerVariable(), V)

    constraint = add_cons_container!(container, ReactivePowerConstraint(), V, name_index, time_steps)

    for d in devices, t in time_steps
        name = PSY.get_name(d)

        constraint[name, t] =
            JuMP.@constraint(container.JuMPmodel, 
            var_q[name, t] == var_sub_q[name, PSY.RenewableGen, t] 
                + var_sub_q[name, PSY.ThermalGen, t] 
                + var_sub_q[name, PSY.Storage, t]
            )
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{InterConnectionLimitConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, D},
    ::Type{X},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.HybridSystem, D <: AbstractHybridFormulation, X <: PM.AbstractPowerModel}

    time_steps = model_time_steps(container)
    name_index = [PSY.get_name(d) for d in devices]

    var_q = get_variable(container, ReactivePowerVariable(), V)
    var_p = get_variable(container, ActivePowerVariable(), V)


    constraint = add_cons_container!(container, InterConnectionLimitConstraint(), V, name_index, time_steps)

    for d in devices, t in time_steps
        name = PSY.get_name(d)
        rating = PSY.get_interconnection_rating(d)
        constraint[name, t] =
            JuMP.@constraint(container.JuMPmodel, 
            rating^2 == var_q[name, t]^2 + var_p[name, t]^2
            )
    end
    return
end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{D},
    formulation::AbstractHybridFormulation,
) where {D <: PSY.HybridSystem}
    add_initial_condition!(container, devices, formulation, InitialEnergyLevel())
    return
end


########################### Cost Function Calls#############################################

function AddCostSpec(
    ::Type{T},
    ::Type{U},
    psi_container::OptimizationContainer,
) where {T <: PSY.HybridSystem, U <: AbstractHybridFormulation}
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        variable_cost = PSY.get_variable,
        fixed_cost = PSY.get_fixed,
    )
end
