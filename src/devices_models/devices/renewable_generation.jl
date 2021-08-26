#! format: off

abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end
abstract type AbstractRenewableDispatchFormulation <: AbstractRenewableFormulation end
struct RenewableFullDispatch <: AbstractRenewableDispatchFormulation end
struct RenewableConstantPowerFactor <: AbstractRenewableDispatchFormulation end

get_variable_sign(_, ::Type{<:PSY.RenewableGen}, ::AbstractRenewableFormulation) = 1.0
########################### ActivePowerVariable, RenewableGen #################################

get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.RenewableGen}, ::AbstractRenewableFormulation) = false

get_variable_expression_name(::ActivePowerVariable, ::Type{<:PSY.RenewableGen}) = ExpressionKey(ActivePowerBalance, PSY.Bus)

get_variable_lower_bound(::ActivePowerVariable, d::PSY.RenewableGen, ::AbstractRenewableFormulation) = 0.0
get_variable_upper_bound(::ActivePowerVariable, d::PSY.RenewableGen, ::AbstractRenewableFormulation) = PSY.get_max_active_power(d)

########################### ReactivePowerVariable, RenewableGen #################################

get_variable_binary(::ReactivePowerVariable, ::Type{<:PSY.RenewableGen}, ::AbstractRenewableFormulation) = false

get_variable_expression_name(::ReactivePowerVariable, ::Type{<:PSY.RenewableGen}) = ExpressionKey(ReactivePowerBalance, PSY.Bus)

get_multiplier_value(::TimeSeriesParameter, d::PSY.ElectricLoad, ::FixedOutput) = PSY.get_max_active_power(d)

#! format: on

####################################### Reactive Power constraint_infos #########################
function get_min_max_limits(
    device,
    ::Type{ReactivePowerVariableLimitsConstraint},
    ::Type{<:AbstractRenewableFormulation},
)
    PSY.get_reactive_power_limits(device)
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:ReactivePowerVariableLimitsConstraint},
    U::Type{<:ReactivePowerVariable},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.RenewableGen, W <: AbstractDeviceFormulation}
    add_range_constraints!(container, T, U, devices, model, X, feedforward)
end

"""
Reactive Power Constraints on Renewable Gen Constant power_factor
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:ReactivePowerVariableLimitsConstraint},
    U::Type{<:ReactivePowerVariable},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.RenewableGen, W <: RenewableConstantPowerFactor}
    names = [PSY.get_name(d) for d in devices]
    time_steps = get_time_steps(container)
    p_var = get_variable(container, ActivePowerVariable(), V)
    q_var = get_variable(container, ReactivePowerVariable(), V)
    jump_model = get_jump_model(container)
    constraint = add_cons_container!(container, EqualityConstraint(), V, names, time_steps)
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(acos(PSY.get_power_factor(d)))
        constraint[name, t] =
            JuMP.@constraint(jump_model, q_var[name, t] == p_var[name, t] * pf)
    end
end

function DeviceRangeConstraintSpec(
    ::Type{<:ActivePowerVariableLimitsConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractRenewableDispatchFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
) where {T <: PSY.RenewableGen}
    return DeviceRangeConstraintSpec(;
        timeseries_range_constraint_spec = TimeSeriesConstraintSpec(;
            constraint_type = ActivePowerVariableLimitsConstraint(),
            variable_type = ActivePowerVariable(),
            parameter = ActivePowerTimeSeriesParameter(
                PSY.Deterministic,
                "max_active_power",
            ),
            multiplier_func = x -> PSY.get_max_active_power(x),
            constraint_func = use_parameters ? device_timeseries_param_ub! :
                              device_timeseries_ub!,
            component_type = T,
        ),
    )
end

########################## Addition to the nodal balances ##################################
function NodalExpressionSpec(
    ::Type{T},
    parameter::ReactivePowerTimeSeriesParameter,
) where {T <: PSY.RenewableGen}
    return NodalExpressionSpec(
        parameter,
        T,
        x -> PSY.get_max_reactive_power(x),
        1.0,
        ExpressionKey(ReactivePowerBalance, PSY.Bus),
    )
end

function NodalExpressionSpec(
    ::Type{T},
    parameter::ActivePowerTimeSeriesParameter,
) where {T <: PSY.RenewableGen}
    return NodalExpressionSpec(
        parameter,
        T,
        x -> PSY.get_max_active_power(x),
        1.0,
        ExpressionKey(ActivePowerBalance, PSY.Bus),
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
