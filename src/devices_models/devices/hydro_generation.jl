#! format: off
requires_initialization(::AbstractHydroFormulation) = false
requires_initialization(::AbstractHydroUnitCommitment) = true

get_variable_multiplier(_, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = 1.0
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.HydroGen}, ::Type{<:PSY.Reserve{PSY.ReserveUp}}) = ActivePowerRangeExpressionUB
get_expression_type_for_reserve(::ActivePowerReserveVariable, ::Type{<:PSY.HydroGen}, ::Type{<:PSY.Reserve{PSY.ReserveDown}}) = ActivePowerRangeExpressionLB

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
get_variable_warm_start_value(::ReactivePowerVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_reactive_power(d)
get_variable_lower_bound(::ReactivePowerVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_reactive_power_limits(d).min
get_variable_upper_bound(::ReactivePowerVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_reactive_power_limits(d).max

############## OnVariable, HydroGen ####################
get_variable_binary(::OnVariable, ::Type{<:PSY.HydroGen}, ::AbstractHydroFormulation) = true
get_variable_warm_start_value(::OnVariable, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_active_power(d) > 0 ? 1.0 : 0.0

########################### Parameter related set functions ################################
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
initial_condition_default(::InitialTimeDurationOn, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_status(d) ? PSY.get_time_at_status(d) :  0.0
initial_condition_variable(::InitialTimeDurationOn, d::PSY.HydroGen, ::AbstractHydroFormulation) = OnVariable()
initial_condition_default(::InitialTimeDurationOff, d::PSY.HydroGen, ::AbstractHydroFormulation) = PSY.get_status(d) ? 0.0 : PSY.get_time_at_status(d)
initial_condition_variable(::InitialTimeDurationOff, d::PSY.HydroGen, ::AbstractHydroFormulation) = OnVariable()

########################Objective Function##################################################
proportional_cost(cost::Nothing, ::PSY.HydroGen, ::ActivePowerVariable, ::AbstractHydroFormulation)=0.0
proportional_cost(cost::PSY.OperationalCost, ::OnVariable, ::PSY.HydroGen, ::AbstractHydroFormulation)=PSY.get_fixed(cost)

objective_function_multiplier(::ActivePowerVariable, ::AbstractHydroFormulation)=OBJECTIVE_FUNCTION_POSITIVE
objective_function_multiplier(::ActivePowerOutVariable, ::AbstractHydroFormulation)=OBJECTIVE_FUNCTION_POSITIVE
objective_function_multiplier(::OnVariable, ::AbstractHydroFormulation)=OBJECTIVE_FUNCTION_POSITIVE

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

function get_default_time_series_names(
    ::Type{<:PSY.HydroGen},
    ::Type{<:Union{FixedOutput, HydroDispatchRunOfRiver, HydroCommitmentRunOfRiver}},
)
    return Dict{Type{<:TimeSeriesParameter}, String}(
        ActivePowerTimeSeriesParameter => "max_active_power",
        ReactivePowerTimeSeriesParameter => "max_active_power",
    )
end

function get_default_attributes(
    ::Type{T},
    ::Type{D},
) where {T <: PSY.HydroGen, D <: Union{FixedOutput, AbstractHydroFormulation}}
    return Dict{String, Any}("reservation" => false)
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
    ::NetworkModel{X},
) where {V <: PSY.HydroGen, W <: HydroDispatchRunOfRiver, X <: PM.AbstractPowerModel}
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
    ::NetworkModel{X},
) where {V <: PSY.HydroGen, W <: HydroDispatchRunOfRiver, X <: PM.AbstractPowerModel}
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
    ::NetworkModel{X},
) where {V <: PSY.HydroGen, W <: HydroCommitmentRunOfRiver, X <: PM.AbstractPowerModel}
    add_semicontinuous_range_constraints!(container, T, U, devices, model, X)
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{ActivePowerVariableLimitsConstraint},
    U::Type{<:Union{VariableType, ExpressionType}},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::NetworkModel{X},
) where {V <: PSY.HydroGen, W <: HydroCommitmentRunOfRiver, X <: PM.AbstractPowerModel}
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
    return (min = 0.0, max = PSY.get_max_active_power(x))
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
    ::NetworkModel{X},
) where {V <: PSY.HydroGen, W <: AbstractHydroUnitCommitment, X <: PM.AbstractPowerModel}
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
    ::NetworkModel{X},
) where {
    V <: PSY.HydroGen,
    W <: AbstractHydroDispatchFormulation,
    X <: PM.AbstractPowerModel,
}
    if !has_semicontinuous_feedforward(model, U)
        add_range_constraints!(container, T, U, devices, model, X)
    end
    return
end

##################################### Auxillary Variables ############################
function _calculate_aux_variable_value!(
    container::OptimizationContainer,
    ::AuxVarKey{EnergyOutput, T},
    system::PSY.System,
    p_variable_results::JuMPVariableArray,
) where {T <: PSY.HydroGen}
    devices = axes(p_variable_results, 1)
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR
    aux_variable_container = get_aux_variable(container, EnergyOutput(), T)
    for name in devices, t in time_steps
        aux_variable_container[name, t] =
            jump_value(p_variable_results[name, t]) * fraction_of_hour
    end

    return
end

function calculate_aux_variable_value!(
    container::OptimizationContainer,
    aux_key::AuxVarKey{EnergyOutput, T},
    system::PSY.System,
) where {T <: PSY.HydroGen}
    p_variable_results = get_variable(container, ActivePowerVariable(), T)
    _calculate_aux_variable_value!(
        container,
        aux_key,
        system,
        p_variable_results,
    )
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
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.HydroGen, U <: AbstractHydroDispatchFormulation}
    add_variable_cost!(container, ActivePowerVariable(), devices, U())
    return
end
