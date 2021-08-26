#! format: off

abstract type AbstractLoadFormulation <: AbstractDeviceFormulation end
abstract type AbstractControllablePowerLoadFormulation <: AbstractLoadFormulation end
struct StaticPowerLoad <: AbstractLoadFormulation end
struct InterruptiblePowerLoad <: AbstractControllablePowerLoadFormulation end
struct DispatchablePowerLoad <: AbstractControllablePowerLoadFormulation end

########################### ElectricLoad ####################################

get_variable_sign(_, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = -1.0

########################### ActivePowerVariable, ElectricLoad ####################################

get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = false

get_variable_expression_name(::ActivePowerVariable, ::Type{<:PSY.ElectricLoad}) = :nodal_balance_active

get_variable_lower_bound(::ActivePowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = 0.0
get_variable_upper_bound(::ActivePowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = PSY.get_active_power(d)

########################### ReactivePowerVariable, ElectricLoad ####################################

get_variable_binary(::ReactivePowerVariable, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = false

get_variable_expression_name(::ReactivePowerVariable, ::Type{<:PSY.ElectricLoad}) = :nodal_balance_reactive

get_variable_lower_bound(::ReactivePowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = 0.0
get_variable_upper_bound(::ReactivePowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = PSY.get_reactive_power(d)

########################### ReactivePowerVariable, ElectricLoad ####################################

get_variable_binary(::OnVariable, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = true

#! format: on

####################################### Reactive Power Constraints #########################
"""
Reactive Power Constraints on Controllable Loads Assume Constant power_factor
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:ReactivePowerVariableLimitsConstraint},
    U::Type{<:ReactivePowerVariable},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {V <: PSY.ElectricLoad, W <: AbstractControllablePowerLoadFormulation}
    time_steps = get_time_steps(container)
    constraint = add_cons_container!(
        container,
        EqualityConstraint(),
        V,
        [PSY.get_name(d) for d in devices],
        time_steps,
    )
    jump_model = get_jump_model(container)
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(atan((PSY.get_max_reactive_power(d) / PSY.get_max_active_power(d))))
        reactive = get_variable(container, ActivePowerVariable(), V)[name, t]
        real = get_variable(container, ActivePowerVariable(), V)[name, t] * pf
        constraint[name, t] = JuMP.@constraint(jump_model, reactive == real)
    end
end

function DeviceRangeConstraintSpec(
    ::Type{<:ActivePowerVariableLimitsConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:DispatchablePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
) where {T <: PSY.ElectricLoad}
    return DeviceRangeConstraintSpec(;
        timeseries_range_constraint_spec = TimeSeriesConstraintSpec(
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

function DeviceRangeConstraintSpec(
    ::Type{<:ActivePowerVariableLimitsConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:InterruptiblePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
) where {T <: PSY.ElectricLoad}
    return DeviceRangeConstraintSpec(;
        timeseries_range_constraint_spec = TimeSeriesConstraintSpec(
            constraint_type = ActivePowerVariableLimitsConstraint(),
            variable_type = ActivePowerVariable(),
            bin_variable_type = OnVariable(),
            parameter = ActivePowerTimeSeriesParameter(
                PSY.Deterministic,
                "max_active_power",
            ),
            multiplier_func = x -> PSY.get_max_active_power(x),
            constraint_func = use_parameters ? device_timeseries_ub_bigM! :
                              device_timeseries_ub_bin!,
            component_type = T,
        ),
    )
end

########################## Addition to the nodal balances ##################################
function NodalExpressionSpec(
    ::Type{T},
    parameter::ReactivePowerTimeSeriesParameter,
) where {T <: PSY.ElectricLoad}
    return NodalExpressionSpec(
        parameter,
        T,
        x -> PSY.get_max_reactive_power(x),
        -1.0,
        :nodal_balance_reactive,
    )
end

function NodalExpressionSpec(
    ::Type{T},
    parameter::ActivePowerTimeSeriesParameter,
) where {T <: PSY.ElectricLoad}
    return NodalExpressionSpec(
        parameter,
        T,
        x -> PSY.get_max_active_power(x),
        -1.0,
        :nodal_balance_active,
    )
end

############################## FormulationControllable Load Cost ###########################
function AddCostSpec(
    ::Type{T},
    ::Type{DispatchablePowerLoad},
    ::OptimizationContainer,
) where {T <: PSY.ControllableLoad}
    cost_function = x -> (x === nothing ? 1.0 : PSY.get_variable(x))
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        variable_cost = cost_function,
        multiplier = OBJECTIVE_FUNCTION_NEGATIVE,
    )
end

function AddCostSpec(
    ::Type{T},
    ::Type{InterruptiblePowerLoad},
    ::OptimizationContainer,
) where {T <: PSY.ControllableLoad}
    cost_function = x -> (x === nothing ? 1.0 : PSY.get_fixed(x))
    return AddCostSpec(;
        variable_type = OnVariable,
        component_type = T,
        fixed_cost = cost_function,
        multiplier = OBJECTIVE_FUNCTION_NEGATIVE,
    )
end
