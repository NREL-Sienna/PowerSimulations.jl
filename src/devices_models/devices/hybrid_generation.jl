#! format: off
requires_initialization(::AbstractHybridFormulation) = false

get_variable_multiplier(_, ::Type{<:PSY.HybridSystem}, ::AbstractHybridFormulation) = 1.0
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.HybridSystem}, ::Type{<:PSY.Reserve{PSY.ReserveUp}}) = ComponentReserveUpBalanceExpression
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.HybridSystem}, ::Type{<:PSY.Reserve{PSY.ReserveDown}}) = ComponentReserveDownBalanceExpression

########################### ActivePowerOutVariable, HybridSystem #################################
get_variable_binary(::ActivePowerVariable, ::Type{PSY.HybridSystem}, ::AbstractHybridFormulation) = false
get_variable_warm_start_value(::ActivePowerVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_active_power(d)
get_variable_lower_bound(::ActivePowerVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = -1.0 * PSY.get_input_active_power_limits(d).max
get_variable_lower_bound(::ActivePowerVariable, d::PSY.HybridSystem, ::AbstractStandardHybridFormulation) = PSY.get_output_active_power_limits(d).min
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

############## ComponentActivePowerReserveUpVariable, HybridSystem ####################
get_variable_binary(::ComponentActivePowerReserveUpVariable, ::Type{<:PSY.HybridSystem}, ::AbstractHybridFormulation) = false
get_variable_lower_bound(::ComponentActivePowerReserveUpVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = 0.0

############## ComponentActivePowerReserveDownVariable, HybridSystem ####################
get_variable_binary(::ComponentActivePowerReserveDownVariable, ::Type{<:PSY.HybridSystem}, ::AbstractHybridFormulation) = false
get_variable_lower_bound(::ComponentActivePowerReserveDownVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = 0.0

############## ReservationVariable, HybridSystem ####################
get_variable_binary(::ReservationVariable, ::Type{<:PSY.HybridSystem}, ::AbstractHybridFormulation) = true

#################### Initial Conditions for models ###############

initial_condition_default(::InitialEnergyLevel, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_initial_energy(PSY.get_storage(d))
initial_condition_variable(::InitialEnergyLevel, d::PSY.HybridSystem, ::AbstractHybridFormulation) = EnergyVariable()

########################Objective Function##################################################
objective_function_multiplier(::VariableType, ::AbstractHybridFormulation)=OBJECTIVE_FUNCTION_POSITIVE

proportional_cost(cost::PSY.OperationalCost, ::OnVariable, ::PSY.HybridSystem, ::AbstractHybridFormulation)=PSY.get_fixed(cost)
proportional_cost(cost::PSY.MarketBidCost, ::OnVariable, ::PSY.HybridSystem, ::AbstractHybridFormulation)=PSY.get_no_load(cost)

sos_status(::PSY.HybridSystem, ::AbstractHybridFormulation)=SOSStatusVariable.NO_VARIABLE

uses_compact_power(::PSY.HybridSystem, ::AbstractHybridFormulation)=false
variable_cost(cost::PSY.OperationalCost, ::PSY.HybridSystem, ::AbstractHybridFormulation)=PSY.get_variable(cost)

get_multiplier_value(::ActivePowerTimeSeriesParameter, d::PSY.HybridSystem, ::Type{<:PSY.RenewableGen}, ::AbstractHybridFormulation) = PSY.get_max_active_power(PSY.get_renewable_unit(d))
get_multiplier_value(::ActivePowerTimeSeriesParameter, d::PSY.HybridSystem, ::Type{<:PSY.ElectricLoad}, ::AbstractHybridFormulation) = PSY.get_max_active_power(PSY.get_electric_load(d))
#! format: on
get_initial_conditions_device_model(
    ::OperationModel,
    ::DeviceModel{T, <:AbstractHybridFormulation},
) where {T <: PSY.HybridSystem} = DeviceModel(T, BasicHybridDisaptch)

does_subcomponent_exist(v::PSY.HybridSystem, ::Type{PSY.ThermalGen}) =
    !isnothing(PSY.get_thermal_unit(v))
does_subcomponent_exist(v::PSY.HybridSystem, ::Type{PSY.RenewableGen}) =
    !isnothing(PSY.get_renewable_unit(v))
does_subcomponent_exist(v::PSY.HybridSystem, ::Type{PSY.ElectricLoad}) =
    !isnothing(PSY.get_electric_load(v))
does_subcomponent_exist(v::PSY.HybridSystem, ::Type{PSY.Storage}) =
    !isnothing(PSY.get_storage(v))

get_subcomponent(v::PSY.HybridSystem, ::Type{PSY.ThermalGen}) = PSY.get_thermal_unit(v)
get_subcomponent(v::PSY.HybridSystem, ::Type{PSY.RenewableGen}) = PSY.get_renewable_unit(v)
get_subcomponent(v::PSY.HybridSystem, ::Type{PSY.ElectricLoad}) = PSY.get_electric_load(v)
get_subcomponent(v::PSY.HybridSystem, ::Type{PSY.Storage}) = PSY.get_storage(v)

function make_subsystem_time_series_name(subcomponent::PSY.Component, label::String)
    return make_subsystem_time_series_name(typeof(subcomponent), label)
end

function make_subsystem_time_series_name(subcomponent::Type{<:PSY.Component}, label::String)
    return IS.strip_module_name(subcomponent) * "__" * label
end

function get_default_time_series_names(
    ::Type{<:PSY.HybridSystem},
    ::Type{<:Union{FixedOutput, AbstractHybridFormulation}},
)
    return Dict{Type{<:TimeSeriesParameter}, String}(
        ActivePowerTimeSeriesParameter => "max_active_power",
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
    device::PSY.HybridSystem,
    ::Type{PSY.RenewableGen},
    ::Type{ComponentActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHybridFormulation},
) = PSY.get_active_power_limits(PSY.get_renewable_unit(device))

get_min_max_limits(
    device::PSY.HybridSystem,
    ::Type{ActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHybridFormulation},
) = (
    min=-1 * PSY.get_input_active_power_limits(device).max,
    max=PSY.get_output_active_power_limits(device).max,
)

get_min_max_limits(
    device::PSY.HybridSystem,
    ::Type{PSY.ThermalGen},
    ::Type{ComponentActivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHybridFormulation},
) = PSY.get_active_power_limits(PSY.get_thermal_unit(device))

get_min_max_limits(
    device::PSY.HybridSystem,
    ::Type{PSY.ThermalGen},
    ::Type{ComponentReactivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHybridFormulation},
) = PSY.get_reactive_power_limits(PSY.get_thermal_unit(device))

get_min_max_limits(
    device::PSY.HybridSystem,
    ::Type{PSY.RenewableGen},
    ::Type{ComponentReactivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHybridFormulation},
) = PSY.get_reactive_power_limits(PSY.get_renewable_unit(device))

get_min_max_limits(
    device::PSY.HybridSystem,
    ::Type{PSY.Storage},
    ::Type{ComponentReactivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHybridFormulation},
) = PSY.get_reactive_power_limits(PSY.get_storage(device))

get_min_max_limits(
    device::PSY.HybridSystem,
    ::Type{EnergyCapacityConstraint},
    ::Type{<:AbstractHybridFormulation},
) = PSY.get_state_of_charge_limits(PSY.get_storage(device))

function add_lower_bound_range_constraints_impl!(
    container::OptimizationContainer,
    T::Type{ComponentActivePowerVariableLimitsConstraint},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {V <: PSY.HybridSystem, W <: AbstractDeviceFormulation}
    constraint = T()
    component_type = V
    time_steps = get_time_steps(container)
    device_names =
        [PSY.get_name(d) for d in devices if does_subcomponent_exist(d, PSY.ThermalGen)]

    con_lb = add_constraints_container!(
        container,
        constraint,
        component_type,
        device_names,
        time_steps,
        meta="lb",
    )

    for device in devices, t in time_steps
        !does_subcomponent_exist(device, PSY.ThermalGen) && continue
        ci_name = PSY.get_name(device)
        subcomp_key = string(PSY.ThermalGen)
        limits = get_min_max_limits(device, PSY.ThermalGen, T, W) # depends on constraint type and formulation type
        con_lb[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[ci_name, subcomp_key, t] >= limits.min
        )
    end
end

function add_upper_bound_range_constraints_impl!(
    container::OptimizationContainer,
    T::Type{ComponentActivePowerVariableLimitsConstraint},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {V <: PSY.HybridSystem, W <: AbstractDeviceFormulation}
    constraint = T()
    component_type = V
    time_steps = get_time_steps(container)
    device_names =
        [PSY.get_name(d) for d in devices if does_subcomponent_exist(d, PSY.ThermalGen)]

    con_ub = add_constraints_container!(
        container,
        constraint,
        component_type,
        device_names,
        time_steps,
        meta="ub",
    )

    for device in devices, t in time_steps
        !does_subcomponent_exist(device, PSY.ThermalGen) && continue
        ci_name = PSY.get_name(device)
        subcomp_key = string(PSY.ThermalGen)
        limits = get_min_max_limits(device, PSY.ThermalGen, T, W) # depends on constraint type and formulation type
        con_ub[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[ci_name, subcomp_key, t] <= limits.max
        )
    end
end

function add_parameterized_upper_bound_range_constraints_impl!(
    container::OptimizationContainer,
    T::Type{ComponentActivePowerVariableLimitsConstraint},
    array,
    P::Type{<:ParameterType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {V <: PSY.HybridSystem, W <: AbstractDeviceFormulation}
    time_steps = get_time_steps(container)
    constraint = T()
    component_type = V
    names =
        [PSY.get_name(d) for d in devices if does_subcomponent_exist(d, PSY.RenewableGen)]

    constraint = add_constraints_container!(
        container,
        constraint,
        component_type,
        names,
        time_steps,
        meta="re ub",
    )

    parameter = get_parameter_array(container, P(), V)
    multiplier = get_parameter_multiplier_array(container, P(), V)
    for device in devices, t in time_steps
        !does_subcomponent_exist(device, PSY.RenewableGen) && continue
        subcomp_key = string(PSY.RenewableGen)
        name = PSY.get_name(device)
        constraint[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            array[name, subcomp_key, t] <=
            multiplier[name, subcomp_key, t] * parameter[name, subcomp_key, t]
        )
    end
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:PowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    add_range_constraints!(container, T, U, devices, model, X)
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{ComponentActivePowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    array = get_variable(container, U(), V)
    add_lower_bound_range_constraints_impl!(container, T, array, devices, model)
    add_upper_bound_range_constraints_impl!(container, T, array, devices, model)
    add_parameterized_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
    )
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{ComponentActivePowerVariableLimitsConstraint},
    U::Type{<:RangeConstraintLBExpressions},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    array = get_expression(container, U(), V)
    add_lower_bound_range_constraints_impl!(container, T, array, devices, model)
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{ComponentActivePowerVariableLimitsConstraint},
    U::Type{<:RangeConstraintUBExpressions},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    array = get_expression(container, U(), V)
    add_upper_bound_range_constraints_impl!(container, T, array, devices, model)
    add_parameterized_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
    )
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{InputActivePowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    if get_attribute(model, "reservation")
        add_reserve_range_constraints!(container, T, U, devices, model, X)
    else
        add_range_constraints!(container, T, U, devices, model, X)
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{OutputActivePowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    if get_attribute(model, "reservation")
        add_reserve_range_constraints!(container, T, U, devices, model, X)
    else
        add_range_constraints!(container, T, U, devices, model, X)
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{ComponentReactivePowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    time_steps = get_time_steps(container)
    var = get_variable(container, ComponentReactivePowerVariable(), V)
    device_names = [PSY.get_name(d) for d in devices]
    subcomp_types = get_subcomponent_types(U)

    constraint_ub = add_constraints_container!(
        container,
        ReactiveRangeConstraint(),
        V,
        device_names,
        subcomp_types,
        time_steps;
        meta="ub",
        sparse=true,
    )
    constraint_lb = add_constraints_container!(
        container,
        ReactiveRangeConstraint(),
        V,
        device_names,
        subcomp_types,
        time_steps;
        meta="lb",
        sparse=true,
    )

    for t in time_steps, d in devices, subcomp in subcomp_types
        !does_subcomponent_exist(d, subcomp) && continue
        name = PSY.get_name(d)
        limits = get_min_max_limits(d, subcomp, T, W)
        subcomp_key = string(subcomp)
        constraint_ub[name, subcomp, t] =
            JuMP.@constraint(container.JuMPmodel, var[name, subcomp_key, t] <= limits.max)
        constraint_lb[name, subcomp, t] =
            JuMP.@constraint(container.JuMPmodel, var[name, subcomp_key, t] >= limits.min)
    end
    return
end
######################## Energy balance constraints ############################

function add_constraints!(
    container::OptimizationContainer,
    ::Type{EnergyBalanceConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    names = [PSY.get_name(x) for x in devices if !isnothing(PSY.get_storage(x))]
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
        isnothing(PSY.get_storage(device)) && continue
        storage_device = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage_device)
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

function add_constraints!(
    container::OptimizationContainer,
    ::Type{PowerOutputRangeConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, D},
    ::Type{X},
) where {V <: PSY.HybridSystem, D <: AbstractHybridFormulation, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    name_index = [PSY.get_name(d) for d in devices]

    var_p = get_variable(container, ActivePowerVariable(), V)
    var_sub_p = get_variable(container, ComponentActivePowerVariable(), V)
    var_out = get_variable(container, ActivePowerOutVariable(), V)
    var_in = get_variable(container, ActivePowerInVariable(), V)

    constraint = add_constraints_container!(
        container,
        PowerOutputRangeConstraint(),
        V,
        name_index,
        time_steps,
    )

    for d in devices, t in time_steps
        name = PSY.get_name(d)

        constraint[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            var_p[name, t] ==
            var_sub_p[name, string(PSY.RenewableGen), t] +
            var_sub_p[name, string(PSY.ThermalGen), t] +
            var_out[name, t] - var_in[name, t]
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
) where {V <: PSY.HybridSystem, D <: AbstractHybridFormulation, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    name_index = [PSY.get_name(d) for d in devices]

    var_q = get_variable(container, ReactivePowerVariable(), V)
    var_sub_q = get_variable(container, ComponentReactivePowerVariable(), V)

    constraint = add_constraints_container!(
        container,
        ReactivePowerConstraint(),
        V,
        name_index,
        time_steps,
    )

    for d in devices, t in time_steps
        name = PSY.get_name(d)

        constraint[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            var_q[name, t] ==
            var_sub_q[name, string(PSY.RenewableGen), t] +
            var_sub_q[name, string(PSY.ThermalGen), t] +
            var_sub_q[name, string(PSY.Storage), t]
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
) where {V <: PSY.HybridSystem, D <: AbstractHybridFormulation, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    name_index = [PSY.get_name(d) for d in devices]

    var_q = get_variable(container, ReactivePowerVariable(), V)
    var_p = get_variable(container, ActivePowerVariable(), V)

    constraint = add_constraints_container!(
        container,
        InterConnectionLimitConstraint(),
        V,
        name_index,
        time_steps,
    )

    for d in devices, t in time_steps
        name = PSY.get_name(d)
        rating = PSY.get_interconnection_rating(d)
        constraint[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            rating^2 == var_q[name, t]^2 + var_p[name, t]^2
        )
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{ReserveEnergyConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.HybridSystem, D <: AbstractHybridFormulation}
    time_steps = get_time_steps(container)
    var_e = get_variable(container, EnergyVariable(), T)
    r_up = get_variable(container, ComponentActivePowerReserveUpVariable(), T)
    r_dn = get_variable(container, ComponentActivePowerReserveDownVariable(), T)
    names = [PSY.get_name(x) for x in devices if does_subcomponent_exist(d, PSY.Storage)]
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
        !does_subcomponent_exist(d, PSY.Storage) && continue
        name = PSY.get_name(d)
        limits = PSY.get_state_of_charge_limits(PSY.get_storage(d))
        efficiency = PSY.get_efficiency(d)
        con_up[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            r_up[name, t] <= (var_e[name, t] - limits.min) * efficiency.out
        )
        con_dn[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            r_dn[name, t] <= (limits.max - var_e[name, t]) / efficiency.in
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
) where {T <: PSY.HybridSystem, D <: AbstractHybridFormulation}
    time_steps = get_time_steps(container)
    var_in = get_variable(container, ActivePowerInVariable(), T)
    var_out = get_variable(container, ActivePowerOutVariable(), T)
    r_up = get_variable(container, ComponentActivePowerReserveUpVariable(), T)
    r_dn = get_variable(container, ComponentActivePowerReserveDownVariable(), T)
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
            r_up[name, t] <= var_in[name, t] + (out_limits.max - var_out[name, t])
        )
        con_dn[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            r_dn[name, t] <= var_out[name, t] + (in_limits.max - var_in[name, t])
        )
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{ComponentReserveUpBalance},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.HybridSystem, D <: AbstractHybridFormulation}
    time_steps = get_time_steps(container)
    sub_r_up = get_variable(container, ComponentActivePowerReserveUpVariable(), T)
    sub_expr_up = get_expression(container, ComponentReserveUpBalanceExpression(), T)
    names = [PSY.get_name(x) for x in devices]
    con_up = add_constraints_container!(
        container,
        ComponentReserveUpBalance(),
        T,
        names,
        time_steps,
    )

    for d in devices, t in time_steps
        name = PSY.get_name(d)
        con_up[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            sub_expr_up[name, t] == sum(
                sub_r_up[name, string(sub_comp_type), t] for
                sub_comp_type in [PSY.ThermalGen, PSY.RenewableGen, PSY.Storage]
            )
        )
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{ComponentReserveDownBalance},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.HybridSystem, D <: AbstractHybridFormulation}
    time_steps = get_time_steps(container)
    sub_r_dn = get_variable(container, ComponentActivePowerReserveDownVariable(), T)
    sub_expr_dn = get_expression(container, ComponentReserveDownBalanceExpression(), T)
    names = [PSY.get_name(x) for x in devices]
    con_dn = add_constraints_container!(
        container,
        ComponentReserveDownBalance(),
        T,
        names,
        time_steps,
    )

    for d in devices, t in time_steps
        name = PSY.get_name(d)
        con_dn[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            sub_expr_dn[name, t] == sum(
                sub_r_dn[name, string(sub_comp_type), t] for
                sub_comp_type in [PSY.ThermalGen, PSY.RenewableGen, PSY.Storage]
            )
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
function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.HybridSystem, U <: AbstractHybridFormulation}
    add_variable_cost!(container, ActivePowerVariable(), devices, U())
    add_proportional_cost!(container, OnVariable(), devices, U())
    return
end
