#! format: off
requires_initialization(::AbstractHybridFormulation) = false

get_variable_multiplier(::ActivePowerOutVariable, ::Type{<:PSY.HybridSystem}, ::AbstractHybridFormulation) = 1.0
get_variable_multiplier(::ActivePowerInVariable, ::Type{<:PSY.HybridSystem}, ::AbstractHybridFormulation) = -1.0
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.HybridSystem}, ::Type{<:PSY.Reserve{PSY.ReserveUp}}) = ComponentReserveUpBalanceExpression
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.HybridSystem}, ::Type{<:PSY.Reserve{PSY.ReserveDown}}) = ComponentReserveDownBalanceExpression

########################### ActivePowerOutVariable, HybridSystem #################################
get_variable_binary(::ActivePowerVariable, ::Type{PSY.HybridSystem}, ::AbstractHybridFormulation) = false
get_variable_warm_start_value(::ActivePowerVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_active_power(d)
get_variable_lower_bound(::ActivePowerVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = -1.0 * PSY.get_input_active_power_limits(d).max
get_variable_lower_bound(::ActivePowerVariable, d::PSY.HybridSystem, ::AbstractStandardHybridFormulation) = PSY.get_output_active_power_limits(d).min
get_variable_upper_bound(::ActivePowerVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_output_active_power_limits(d).max

############## ComponentOutputActivePowerVariable, HybridSystem ####################
get_variable_binary(::ComponentInputActivePowerVariable, ::Type{PSY.HybridSystem}, ::AbstractHybridFormulation) = false
get_variable_lower_bound(::ComponentInputActivePowerVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = 0.0
get_variable_binary(::ComponentOutputActivePowerVariable, ::Type{PSY.HybridSystem}, ::AbstractHybridFormulation) = false
get_variable_lower_bound(::ComponentOutputActivePowerVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = 0.0


############## ActivePowerInVariable, HybridSystem ####################
get_variable_binary(::ActivePowerInVariable, ::Type{PSY.HybridSystem}, ::AbstractHybridFormulation) = false
get_variable_lower_bound(::ActivePowerInVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_input_active_power_limits(d).min
get_variable_upper_bound(::ActivePowerInVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_input_active_power_limits(d).max

############## ActivePowerOutVariable, HybridSystem ####################
get_variable_binary(::ActivePowerOutVariable, ::Type{PSY.HybridSystem}, ::AbstractHybridFormulation) = false
get_variable_upper_bound(::ActivePowerOutVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_output_active_power_limits(d).max
get_variable_lower_bound(::ActivePowerOutVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_output_active_power_limits(d).min

############## EnergyVariable, HybridSystem ####################
get_variable_binary(::ComponentEnergyVariable, ::Type{PSY.HybridSystem}, ::AbstractHybridFormulation) = false
get_variable_upper_bound(::ComponentEnergyVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_state_of_charge_limits(PSY.get_storage(d)).max
get_variable_lower_bound(::ComponentEnergyVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_state_of_charge_limits(PSY.get_storage(d)).min
get_variable_warm_start_value(::ComponentEnergyVariable, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_initial_energy(PSY.get_storage(d))

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
get_variable_binary(::ComponentReservationVariable, ::Type{<:PSY.HybridSystem}, ::AbstractHybridFormulation) = true

#################### Initial Conditions for models ###############

initial_condition_default(::ComponentInitialEnergyLevel, d::PSY.HybridSystem, ::AbstractHybridFormulation) = PSY.get_initial_energy(PSY.get_storage(d))
initial_condition_variable(::ComponentInitialEnergyLevel, d::PSY.HybridSystem, ::AbstractHybridFormulation) = ComponentEnergyVariable()

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
    return Dict{String, Any}("reservation" => true, "storage_reservation" => true)
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

get_min_max_limits(
    device::PSY.HybridSystem,
    ::Type{PSY.ElectricLoad},
    ::Type{ComponentReactivePowerVariableLimitsConstraint},
    ::Type{<:AbstractHybridFormulation},
) = (min=0.0, max=PSY.get_max_reactive_power(device))

########################## Add Variables Calls #############################################
const SUB_COMPONENT_TYPES =
    [PSY.ThermalGen, PSY.RenewableGen, PSY.ElectricLoad, PSY.Storage]
const SUB_COMPONENT_KEYS = ["ThermalGen", "RenewableGen", "ElectricLoad", "Storage"]
const _INPUT_TYPES = [PSY.ElectricLoad, PSY.Storage]
const _OUTPUT_TYPES = [PSY.ThermalGen, PSY.RenewableGen, PSY.Storage]
const _INPUT_KEYS = ["ElectricLoad", "Storage"]
const _OUTPUT_KEYS = ["ThermalGen", "RenewableGen", "Storage"]

function _add_variable!(
    container::OptimizationContainer,
    ::T,
    devices::U,
    formulation::AbstractHybridFormulation,
) where {
    T <: ComponentReactivePowerVariable,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.HybridSystem}
    @assert !isempty(devices)
    time_steps = get_time_steps(container)
    settings = get_settings(container)
    binary = get_variable_binary(T(), D, formulation)

    variable = add_variable_container!(
        container,
        T(),
        D,
        [PSY.get_name(d) for d in devices],
        SUB_COMPONENT_KEYS,
        time_steps;
        sparse=true,
    )

    for d in devices, (ix, subcomp) in enumerate(SUB_COMPONENT_TYPES)
        !does_subcomponent_exist(d, subcomp) && continue
        subcomp_key = SUB_COMPONENT_KEYS[ix]
        for t in time_steps
            name = PSY.get_name(d)
            variable[name, subcomp_key, t] = JuMP.@variable(
                get_jump_model(container),
                base_name = "$(T)_$(D)_$(subcomp_key)_{$(name), $(t)}",
                binary = binary
            )

            ub = get_variable_upper_bound(T(), d, formulation)
            ub !== nothing && JuMP.set_upper_bound(variable[name, subcomp_key, t], ub)

            lb = get_variable_lower_bound(T(), d, formulation)
            lb !== nothing &&
                !binary &&
                JuMP.set_lower_bound(variable[name, subcomp_key, t], lb)

            if get_warm_start(settings)
                init = get_variable_warm_start_value(T(), d, formulation)
                init !== nothing &&
                    JuMP.set_start_value(variable[name, subcomp_key, t], init)
            end
        end
    end
    # Workaround to remove invalid key combinations
    filter!(x -> x.second !== nothing, variable.data)
    return
end

function _add_variable!(
    container::OptimizationContainer,
    ::T,
    devices::U,
    formulation::AbstractHybridFormulation,
) where {
    T <: ComponentInputActivePowerVariable,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.HybridSystem}
    @assert !isempty(devices)
    time_steps = get_time_steps(container)
    settings = get_settings(container)
    binary = get_variable_binary(T(), D, formulation)

    variable = add_variable_container!(
        container,
        T(),
        D,
        [PSY.get_name(d) for d in devices],
        _INPUT_KEYS,
        time_steps;
        sparse=true,
    )

    for d in devices, (ix, subcomp) in enumerate(_INPUT_TYPES)
        !does_subcomponent_exist(d, subcomp) && continue
        subcomp_key = _INPUT_KEYS[ix]
        for t in time_steps
            name = PSY.get_name(d)
            variable[name, subcomp_key, t] = JuMP.@variable(
                get_jump_model(container),
                base_name = "$(T)_$(D)_$(subcomp)_{$(name), $(t)}",
                binary = binary
            )

            ub = get_variable_upper_bound(T(), d, formulation)
            ub !== nothing && JuMP.set_upper_bound(variable[name, subcomp_key, t], ub)

            lb = get_variable_lower_bound(T(), d, formulation)
            lb !== nothing &&
                !binary &&
                JuMP.set_lower_bound(variable[name, subcomp_key, t], lb)

            if get_warm_start(settings)
                init = get_variable_warm_start_value(T(), d, formulation)
                init !== nothing &&
                    JuMP.set_start_value(variable[name, subcomp_key, t], init)
            end
        end
    end
    # Workaround to remove invalid key combinations
    filter!(x -> x.second !== nothing, variable.data)
    return
end

function _add_variable!(
    container::OptimizationContainer,
    ::T,
    devices::U,
    formulation::AbstractHybridFormulation,
) where {
    T <: ComponentOutputActivePowerVariable,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.HybridSystem}
    @assert !isempty(devices)
    time_steps = get_time_steps(container)
    settings = get_settings(container)
    binary = get_variable_binary(T(), D, formulation)

    variable = add_variable_container!(
        container,
        T(),
        D,
        [PSY.get_name(d) for d in devices],
        _OUTPUT_KEYS,
        time_steps;
        sparse=true,
    )

    for d in devices, (ix, subcomp) in enumerate(_OUTPUT_TYPES)
        !does_subcomponent_exist(d, subcomp) && continue
        subcomp_key = _OUTPUT_KEYS[ix]
        for t in time_steps
            name = PSY.get_name(d)
            variable[name, subcomp_key, t] = JuMP.@variable(
                get_jump_model(container),
                base_name = "$(T)_$(D)_$(subcomp)_{$(name), $(t)}",
                binary = binary
            )

            ub = get_variable_upper_bound(T(), d, formulation)
            ub !== nothing && JuMP.set_upper_bound(variable[name, subcomp_key, t], ub)

            lb = get_variable_lower_bound(T(), d, formulation)
            lb !== nothing &&
                !binary &&
                JuMP.set_lower_bound(variable[name, subcomp_key, t], lb)

            if get_warm_start(settings)
                init = get_variable_warm_start_value(T(), d, formulation)
                init !== nothing &&
                    JuMP.set_start_value(variable[name, subcomp_key, t], init)
            end
        end
    end
    # Workaround to remove invalid key combinations
    filter!(x -> x.second !== nothing, variable.data)
    return
end

function _add_variable!(
    container::OptimizationContainer,
    ::T,
    devices::U,
    formulation::AbstractHybridFormulation,
) where {
    T <: Union{ComponentEnergyVariable, ComponentReservationVariable},
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.HybridSystem}
    @assert !isempty(devices)
    time_steps = get_time_steps(container)
    settings = get_settings(container)
    binary = get_variable_binary(T(), D, formulation)

    variable = add_variable_container!(
        container,
        T(),
        D,
        [PSY.get_name(d) for d in devices if does_subcomponent_exist(d, PSY.Storage)],
        time_steps;
        meta="storage",
    )

    for d in devices
        !does_subcomponent_exist(d, PSY.Storage) && continue
        for t in time_steps
            name = PSY.get_name(d)
            variable[name, t] = JuMP.@variable(
                get_jump_model(container),
                base_name = "$(T)_$(D)_Storage_{$(name), $(t)}",
                binary = binary
            )

            ub = get_variable_upper_bound(T(), d, formulation)
            ub !== nothing && JuMP.set_upper_bound(variable[name, t], ub)

            lb = get_variable_lower_bound(T(), d, formulation)
            lb !== nothing && !binary && JuMP.set_lower_bound(variable[name, t], lb)

            if get_warm_start(settings)
                init = get_variable_warm_start_value(T(), d, formulation)
                init !== nothing && JuMP.set_start_value(variable[name, t], init)
            end
        end
    end
    return
end

"""
Add variables to the OptimizationContainer for a Sub-Component of a hybrid systems.
"""
function add_variables!(
    container::OptimizationContainer,
    ::Type{T},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    formulation::AbstractHybridFormulation,
) where {
    T <: Union{
        ComponentInputActivePowerVariable,
        ComponentOutputActivePowerVariable,
        ComponentReactivePowerVariable,
    },
    U <: PSY.HybridSystem,
}
    _add_variable!(container, T(), devices, formulation)
    return
end

function add_variables!(
    container::OptimizationContainer,
    ::Type{T},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    formulation::AbstractHybridFormulation,
) where {
    T <: Union{ComponentEnergyVariable, ComponentReservationVariable},
    U <: PSY.HybridSystem,
}
    if !all(isnothing.(PSY.get_storage.(devices)))
        _add_variable!(container, T(), devices, formulation)
    end
    return
end

################################## Add Expression Calls ####################################
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <:
    Union{ComponentActivePowerRangeExpressionUB, ComponentActivePowerRangeExpressionLB},
    U <: Union{ComponentInputActivePowerVariable, ComponentOutputActivePowerVariable},
    V <: PSY.HybridSystem,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    time_steps = get_time_steps(container)
    variables = get_variable(container, U(), V)
    expressions = lazy_container_addition!(
        container,
        T(),
        V,
        [PSY.get_name(d) for d in devices],
        SUB_COMPONENT_KEYS,
        time_steps;
        sparse=true,
    )
    for (key, variable) in variables.data
        JuMP.add_to_expression!(expressions.data[key], variable)
    end
    return
end

########################## Add parameters calls ############################################
function add_parameters!(
    container::OptimizationContainer,
    ::Type{T},
    devices::U,
    model::DeviceModel{D, W},
) where {
    T <: TimeSeriesParameter,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.HybridSystem}
    if get_rebuild_model(get_settings(container)) && has_container_key(container, T, D)
        return
    end
    _devices = [d for d in devices if PSY.get_renewable_unit(d) !== nothing]
    add_parameters!(container, T(), _devices, model)
    return
end

function add_parameters!(
    container::OptimizationContainer,
    param::T,
    devices::U,
    model::DeviceModel{D, W},
) where {
    T <: ActivePowerTimeSeriesParameter,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.HybridSystem}
    error("HybridSystem is currently unsupported")
    ts_type = get_default_time_series_type(container)
    if !(ts_type <: Union{PSY.AbstractDeterministic, PSY.StaticTimeSeries})
        error("add_parameters! for TimeSeriesParameter is not compatible with $ts_type")
    end
    time_steps = get_time_steps(container)
    base_ts_name = get_time_series_names(model)[T]
    time_series_mult_id = create_time_series_multiplier_index(model, T)
    @debug "adding" T base_ts_name ts_type time_series_mult_id _group =
        LOG_GROUP_OPTIMIZATION_CONTAINER
    sub_comp_type = [PSY.RenewableGen, PSY.ElectricLoad]

    device_names = [PSY.get_name(d) for d in devices]
    initial_values = Dict{String, AbstractArray}()
    for device in devices, comp_type in sub_comp_type
        if does_subcomponent_exist(device, comp_type)
            sub_comp = get_subcomponent(device, comp_type)
            ts_name = PSY.make_subsystem_time_series_name(sub_comp, base_ts_name)
            ts_uuid = get_time_series_uuid(ts_type, device, ts_name)
            initial_values[ts_uuid] =
                get_time_series_initial_values!(container, ts_type, device, ts_name)
            multiplier = get_multiplier_value(T(), device, comp_type, W())
        else
            # TODO: what to do here?
            #ts_vector = zeros(time_steps[end])
            multiplier = 0.0
        end
    end

    parameter_container = add_param_container!(
        container,
        param,
        D,
        ts_type,
        base_ts_name,
        collect(keys(initial_values)),
        device_names,
        string.(sub_comp_type),
        time_steps,
    )
    set_time_series_multiplier_id!(get_attributes(parameter_container), time_series_mult_id)
    jump_model = get_jump_model(container)

    for (ts_uuid, ts_values) in initial_values
        for step in time_steps
            set_parameter!(parameter_container, jump_model, ts_values[step], ts_uuid, step)
        end
    end

    for device in devices, comp_type in sub_comp_type
        name = PSY.get_name(device)
        if does_subcomponent_exist(device, comp_type)
            multiplier = get_multiplier_value(T(), device, comp_type, W())
            sub_comp = get_subcomponent(device, comp_type)
            ts_name = PSY.make_subsystem_time_series_name(sub_comp, base_ts_name)
            ts_uuid = get_time_series_uuid(ts_type, device, ts_name)
            add_component_name!(get_attributes(parameter_container), name, ts_uuid)
        else
            multiplier = 0.0
        end
        for step in time_steps
            set_multiplier!(parameter_container, multiplier, name, string(comp_type), step)
        end
    end
    return
end

########################## Add constraint Calls ############################################
function _add_lower_bound_range_constraints!(
    container::OptimizationContainer,
    T::Type{ComponentActivePowerVariableLimitsConstraint},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
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
            get_jump_model(container),
            array[ci_name, subcomp_key, t] >= limits.min
        )
    end
end

function _add_upper_bound_range_constraints!(
    container::OptimizationContainer,
    T::Type{ComponentActivePowerVariableLimitsConstraint},
    array,
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
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
            get_jump_model(container),
            array[ci_name, subcomp_key, t] <= limits.max
        )
    end
end

function _add_parameterized_upper_bound_range_constraints!(
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

    param_container = get_parameter(container, P(), V)
    parameter_values = get_parameter_values(param_container)
    multiplier = get_parameter_multiplier_array(container, P(), V)
    for device in devices, t in time_steps
        !does_subcomponent_exist(device, PSY.RenewableGen) && continue
        subcomp_key = string(PSY.RenewableGen)
        name = PSY.get_name(device)
        constraint[name, t] = JuMP.@constraint(
            get_jump_model(container),
            array[name, subcomp_key, t] <=
            multiplier[name, subcomp_key, t] * parameter_values[name, subcomp_key, t]
        )
    end
end

function _add_range_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ComponentActivePowerVariableLimitsConstraint,
    U <: VariableType,
    V <: PSY.HybridSystem,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    array = get_variable(container, U(), V)
    _add_lower_bound_range_constraints_impl!(container, T, array, devices, model)
    _add_upper_bound_range_constraints_impl!(container, T, array, devices, model)
    _add_parameterized_upper_bound_range_constraints_impl!(
        container,
        T,
        array,
        ActivePowerTimeSeriesParameter(),
        devices,
        model,
    )
    return
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
    _add_lower_bound_range_constraints!(container, T, array, devices, model)
    _add_upper_bound_range_constraints!(container, T, array, devices, model)
    _add_parameterized_upper_bound_range_constraints!(
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
    ::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    array = get_expression(container, U(), V)
    _add_lower_bound_range_constraints!(container, T, array, devices, model)
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{ComponentActivePowerVariableLimitsConstraint},
    U::Type{<:RangeConstraintUBExpressions},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    array = get_expression(container, U(), V)
    _add_upper_bound_range_constraints!(container, T, array, devices, model)
    _add_parameterized_upper_bound_range_constraints!(
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
    ::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    time_steps = get_time_steps(container)
    var = get_variable(container, ComponentReactivePowerVariable(), V)
    device_names = [PSY.get_name(d) for d in devices]
    subcomp_types = SUB_COMPONENT_TYPES

    constraint_ub = add_constraints_container!(
        container,
        ComponentReactivePowerVariableLimitsConstraint(),
        V,
        device_names,
        subcomp_types,
        time_steps;
        meta="ub",
        sparse=true,
    )
    constraint_lb = add_constraints_container!(
        container,
        ComponentReactivePowerVariableLimitsConstraint(),
        V,
        device_names,
        subcomp_types,
        time_steps;
        meta="lb",
        sparse=true,
    )

    for d in devices, (ix, subcomp) in enumerate(SUB_COMPONENT_TYPES)
        !does_subcomponent_exist(d, subcomp) && continue
        name = PSY.get_name(d)
        limits = get_min_max_limits(d, subcomp, T, W)
        for t in time_steps
            constraint_ub[name, subcomp, t] = JuMP.@constraint(
                get_jump_model(container),
                var[name, SUB_COMPONENT_KEYS[ix], t] <= limits.max
            )
            constraint_lb[name, subcomp, t] = JuMP.@constraint(
                get_jump_model(container),
                var[name, SUB_COMPONENT_KEYS[ix], t] >= limits.min
            )
        end
    end
    return
end
######################## Energy balance constraints ############################
function add_constraints!(
    container::OptimizationContainer,
    ::Type{EnergyBalanceConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    initial_conditions = get_initial_condition(container, ComponentInitialEnergyLevel(), V)
    energy_var = get_variable(container, ComponentEnergyVariable(), V, "storage")
    names = axes(energy_var)[1]
    powerin_var = get_variable(container, ComponentInputActivePowerVariable(), V)
    powerout_var = get_variable(container, ComponentOutputActivePowerVariable(), V)

    constraint = add_constraints_container!(
        container,
        EnergyBalanceConstraint(),
        V,
        names,
        time_steps,
    )

    for ic in initial_conditions
        device = get_component(ic)
        does_subcomponent_exist(device, PSY.Storage) && continue
        storage_device = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage_device)
        name = PSY.get_name(device)
        constraint[name, 1] = JuMP.@constraint(
            get_jump_model(container),
            energy_var[name, 1] ==
            get_value(ic) +
            (
                powerin_var[name, "Storage", 1] * efficiency.in -
                (powerout_var[name, "Storage", 1] / efficiency.out)
            ) * fraction_of_hour
        )

        for t in time_steps[2:end]
            constraint[name, t] = JuMP.@constraint(
                get_jump_model(container),
                energy_var[name, t] ==
                energy_var[name, t - 1] +
                (
                    powerin_var[name, "Storage", t] * efficiency.in -
                    (powerout_var[name, "Storage", t] / efficiency.out)
                ) * fraction_of_hour
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{DeviceNetActivePowerConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, D},
    ::Type{X},
) where {V <: PSY.HybridSystem, D <: AbstractHybridFormulation, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    name_index = [PSY.get_name(d) for d in devices]

    var_sub_in = get_variable(container, ComponentInputActivePowerVariable(), V)
    var_sub_out = get_variable(container, ComponentOutputActivePowerVariable(), V)
    var_out = get_variable(container, ActivePowerOutVariable(), V)
    var_in = get_variable(container, ActivePowerInVariable(), V)

    constraint_in = add_constraints_container!(
        container,
        DeviceNetActivePowerConstraint(),
        V,
        name_index,
        time_steps,
        meta="in",
    )
    constraint_out = add_constraints_container!(
        container,
        DeviceNetActivePowerConstraint(),
        V,
        name_index,
        time_steps,
        meta="out",
    )

    for d in devices
        name = PSY.get_name(d)
        for t in time_steps
            total_power_in = JuMP.AffExpr()
            total_power_out = JuMP.AffExpr()
            for subcomp in _OUTPUT_TYPES
                !does_subcomponent_exist(d, subcomp) && continue
                JuMP.add_to_expression!(
                    total_power_out,
                    var_sub_out[name, string(subcomp), t],
                )
            end
            for subcomp in _INPUT_TYPES
                !does_subcomponent_exist(d, subcomp) && continue
                JuMP.add_to_expression!(
                    total_power_in,
                    var_sub_in[name, string(subcomp), t],
                )
            end
            constraint_out[name, t] = JuMP.@constraint(
                get_jump_model(container),
                var_out[name, t] - total_power_out == 0.0
            )
            constraint_in[name, t] = JuMP.@constraint(
                get_jump_model(container),
                var_in[name, t] - total_power_in == 0.0
            )
        end
    end

    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{DeviceNetReactivePowerConstraint},
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
        DeviceNetReactivePowerConstraint(),
        V,
        name_index,
        time_steps,
    )

    for d in devices
        name = PSY.get_name(d)
        for t in time_steps
            net_reactive_power = JuMP.AffExpr()
            for subcomp in SUB_COMPONENT_TYPES
                !does_subcomponent_exist(d, subcomp) && continue
                if subcomp <: PSY.ElectricLoad
                    JuMP.add_to_expression!(
                        net_reactive_power,
                        var_sub_q[name, string(subcomp), t],
                        -1.0,
                    )
                else
                    JuMP.add_to_expression!(
                        net_reactive_power,
                        var_sub_q[name, string(subcomp), t],
                    )
                end
            end
            constraint[name, t] = JuMP.@constraint(
                get_jump_model(container),
                var_q[name, t] - net_reactive_power == 0.0
            )
        end
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
    var_p_in = get_variable(container, ActivePowerInVariable(), V)
    var_p_out = get_variable(container, ActivePowerOutVariable(), V)

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
            get_jump_model(container),
            rating^2 == var_q[name, t]^2 + var_p_in[name, t]^2 + var_p_out[name, t]^2
        )
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{ComponentReservationConstraint},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, D},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.HybridSystem, D <: AbstractHybridFormulation}
    time_steps = get_time_steps(container)
    var_in = get_variable(container, ComponentInputActivePowerVariable(), T)
    var_out = get_variable(container, ComponentOutputActivePowerVariable(), T)
    reserve = get_variable(container, ReservationVariable(), T)
    names = [PSY.get_name(x) for x in devices if does_subcomponent_exist(x, PSY.Storage)]
    con_in = add_constraints_container!(
        container,
        ComponentReservationConstraint(),
        T,
        names,
        time_steps;
        meta="in",
    )
    con_out = add_constraints_container!(
        container,
        ReserveEnergyCoverageConstraint(),
        T,
        names,
        time_steps;
        meta="out",
    )

    for d in devices
        !does_subcomponent_exist(d, PSY.Storage) && continue
        name = PSY.get_name(d)
        out_limits = PSY.get_output_active_power_limits(d)
        in_limits = PSY.get_input_active_power_limits(d)
        for t in time_steps
            con_in[name, t] = JuMP.@constraint(
                get_jump_model(container),
                var_in[name, "Storage", t] <= in_limits.max * (1 - reserve[name, t])
            )
            con_out[name, t] = JuMP.@constraint(
                get_jump_model(container),
                var_out[name, "Storage", t] <= out_limits.max * reserve[name, t]
            )
        end
    end
    return
end

#=
function add_constraints!(
    container::OptimizationContainer,
    ::Type{ReserveEnergyCoverageConstraint},
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
        ReserveEnergyCoverageConstraint(),
        T,
        names,
        time_steps,
        meta="up",
    )
    con_dn = add_constraints_container!(
        container,
        ReserveEnergyCoverageConstraint(),
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
            get_jump_model(container),
            r_up[name, t] <= (var_e[name, t] - limits.min) * efficiency.out
        )
        con_dn[name, t] = JuMP.@constraint(
            get_jump_model(container),
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
            get_jump_model(container),
            r_up[name, t] <= var_in[name, t] + (out_limits.max - var_out[name, t])
        )
        con_dn[name, t] = JuMP.@constraint(
            get_jump_model(container),
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
            get_jump_model(container),
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
            get_jump_model(container),
            sub_expr_dn[name, t] == sum(
                sub_r_dn[name, string(sub_comp_type), t] for
                sub_comp_type in [PSY.ThermalGen, PSY.RenewableGen, PSY.Storage]
            )
        )
    end
    return
end
=#
########################## Make initial Conditions for a Model #############################
function initial_conditions!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{D},
    formulation::AbstractHybridFormulation,
) where {D <: PSY.HybridSystem}
    add_initial_condition!(container, devices, formulation, ComponentInitialEnergyLevel())
    return
end

########################### Cost Function Calls#############################################
function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.HybridSystem, U <: AbstractHybridFormulation}
    add_variable_cost!(container, ActivePowerInVariable(), devices, U())
    add_variable_cost!(container, ActivePowerOutVariable(), devices, U())
    add_proportional_cost!(container, OnVariable(), devices, U())
    return
end
