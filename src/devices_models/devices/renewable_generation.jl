#! format: off

abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end
abstract type AbstractRenewableDispatchFormulation <: AbstractRenewableFormulation end
struct RenewableFullDispatch <: AbstractRenewableDispatchFormulation end
struct RenewableConstantPowerFactor <: AbstractRenewableDispatchFormulation end

get_variable_multiplier(_, ::Type{<:PSY.RenewableGen}, ::AbstractRenewableFormulation) = 1.0
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.RenewableGen}, ::Type{<:PSY.Reserve{PSY.ReserveUp}}) = ActivePowerRangeExpressionUB
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.RenewableGen}, ::Type{<:PSY.Reserve{PSY.ReserveDown}}) = ActivePowerRangeExpressionLB
########################### ActivePowerVariable, RenewableGen #################################

get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.RenewableGen}, ::AbstractRenewableFormulation) = false

get_variable_lower_bound(::ActivePowerVariable, d::PSY.RenewableGen, ::AbstractRenewableFormulation) = 0.0
get_variable_upper_bound(::ActivePowerVariable, d::PSY.RenewableGen, ::AbstractRenewableFormulation) = PSY.get_max_active_power(d)

########################### ReactivePowerVariable, RenewableGen #################################

get_variable_binary(::ReactivePowerVariable, ::Type{<:PSY.RenewableGen}, ::AbstractRenewableFormulation) = false

get_multiplier_value(::TimeSeriesParameter, d::PSY.RenewableGen, ::FixedOutput) = PSY.get_max_active_power(d)
get_multiplier_value(::TimeSeriesParameter, d::PSY.RenewableGen, ::AbstractRenewableFormulation) = PSY.get_max_active_power(d)
#! format: on

get_initial_conditions_device_model(
    ::DeviceModel{T, <:AbstractRenewableFormulation},
) where {T <: PSY.RenewableGen} = DeviceModel(T, RenewableFullDispatch)

get_initial_conditions_device_model(
    ::DeviceModel{T, FixedOutput},
) where {T <: PSY.RenewableGen} = DeviceModel(T, FixedOutput)

function get_min_max_limits(
    device,
    ::Type{ReactivePowerVariableLimitsConstraint},
    ::Type{<:AbstractRenewableFormulation},
)
    PSY.get_reactive_power_limits(device)
end

function get_default_time_series_names(
    ::Type{<:PSY.RenewableGen},
    ::Type{<:Union{FixedOutput, AbstractRenewableFormulation}},
)
    return Dict{Type{<:TimeSeriesParameter}, String}(
        ActivePowerTimeSeriesParameter => "max_active_power",
        ReactivePowerTimeSeriesParameter => "max_active_power",
    )
end

function get_default_attributes(
    ::Type{<:PSY.RenewableGen},
    ::Type{<:Union{FixedOutput, AbstractRenewableFormulation}},
)
    return Dict{String, Any}()
end

####################################### Reactive Power constraint_infos #########################

function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:ReactivePowerVariableLimitsConstraint},
    U::Type{<:ReactivePowerVariable},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.RenewableGen, W <: AbstractDeviceFormulation}
    add_range_constraints!(container, T, U, devices, model, X)
end

"""
Reactive Power Constraints on Renewable Gen Constant power_factor
"""
function add_constraints!(
    container::OptimizationContainer,
    ::Type{<:ReactivePowerVariableLimitsConstraint},
    ::Type{<:ReactivePowerVariable},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.RenewableGen, W <: RenewableConstantPowerFactor}
    names = [PSY.get_name(d) for d in devices]
    time_steps = get_time_steps(container)
    p_var = get_variable(container, ActivePowerVariable(), V)
    q_var = get_variable(container, ReactivePowerVariable(), V)
    jump_model = get_jump_model(container)
    constraint =
        add_constraints_container!(container, EqualityConstraint(), V, names, time_steps)
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(acos(PSY.get_power_factor(d)))
        constraint[name, t] =
            JuMP.@constraint(jump_model, q_var[name, t] == p_var[name, t] * pf)
    end
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{ActivePowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.RenewableGen, W <: AbstractRenewableDispatchFormulation}
    add_parameterized_upper_bound_range_constraints(
        container,
        ActivePowerVariableTimeSeriesLimitsConstraint,
        U,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        X,
    )
end

##################################### renewable generation cost ############################
function AddCostSpec(
    ::Type{T},
    ::Type{U},
    ::OptimizationContainer,
) where {T <: PSY.RenewableDispatch, U <: AbstractRenewableDispatchFormulation}
    # TODO: remove once cost_function is required
    cost_function = x -> (x === nothing ? 1.0 : PSY.get_variable(x))
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        variable_cost = cost_function,
        multiplier = OBJECTIVE_FUNCTION_NEGATIVE,
    )
end
