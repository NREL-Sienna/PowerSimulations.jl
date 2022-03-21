#! format: off
########################### ElectricLoad ####################################

get_variable_multiplier(_, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = -1.0

########################### ActivePowerVariable, ElectricLoad ####################################

get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = false
get_variable_lower_bound(::ActivePowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = 0.0
get_variable_upper_bound(::ActivePowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = PSY.get_active_power(d)

########################### ReactivePowerVariable, ElectricLoad ####################################

get_variable_binary(::ReactivePowerVariable, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = false

get_variable_lower_bound(::ReactivePowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = 0.0
get_variable_upper_bound(::ReactivePowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = PSY.get_reactive_power(d)

########################### ReactivePowerVariable, ElectricLoad ####################################

get_variable_binary(::OnVariable, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = true

get_multiplier_value(::TimeSeriesParameter, d::PSY.ElectricLoad, ::StaticPowerLoad) = -1*PSY.get_max_active_power(d)
get_multiplier_value(::ReactivePowerTimeSeriesParameter, d::PSY.ElectricLoad, ::StaticPowerLoad) = -1*PSY.get_max_reactive_power(d)
get_multiplier_value(::TimeSeriesParameter, d::PSY.ElectricLoad, ::AbstractControllablePowerLoadFormulation) = PSY.get_max_active_power(d)


########################Objective Function##################################################
proportional_cost(cost::Nothing, ::OnVariable, ::PSY.ElectricLoad, ::AbstractControllablePowerLoadFormulation)=1.0
proportional_cost(cost::PSY.OperationalCost, ::OnVariable, ::PSY.ElectricLoad, ::AbstractControllablePowerLoadFormulation)=PSY.get_fixed(cost)

objective_function_multiplier(::VariableType, ::AbstractControllablePowerLoadFormulation)=OBJECTIVE_FUNCTION_NEGATIVE

variable_cost(::Nothing, ::PSY.ElectricLoad, ::ActivePowerVariable, ::AbstractControllablePowerLoadFormulation)=1.0
variable_cost(cost::PSY.OperationalCost, ::ActivePowerVariable, ::PSY.ElectricLoad, ::AbstractControllablePowerLoadFormulation)=PSY.get_variable(cost)

#! format: on

function get_default_time_series_names(
    ::Type{<:PSY.ElectricLoad},
    ::Type{<:Union{FixedOutput, AbstractLoadFormulation}},
)
    return Dict{Type{<:TimeSeriesParameter}, String}(
        ActivePowerTimeSeriesParameter => "max_active_power",
        ReactivePowerTimeSeriesParameter => "max_active_power",
    )
end

function get_default_attributes(
    ::Type{U},
    ::Type{V},
) where {U <: PSY.ElectricLoad, V <: Union{FixedOutput, AbstractLoadFormulation}}
    return Dict{String, Any}()
end

get_initial_conditions_device_model(
    ::OperationModel,
    ::DeviceModel{T, <:AbstractLoadFormulation},
) where {T <: PSY.ElectricLoad} = DeviceModel(T, StaticPowerLoad)

####################################### Reactive Power Constraints #########################
"""
Reactive Power Constraints on Controllable Loads Assume Constant power_factor
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:ReactivePowerVariableLimitsConstraint},
    U::Type{<:ReactivePowerVariable},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.ElectricLoad, W <: AbstractControllablePowerLoadFormulation}
    time_steps = get_time_steps(container)
    constraint = add_constraints_container!(
        container,
        T(),
        V,
        [PSY.get_name(d) for d in devices],
        time_steps,
    )
    jump_model = get_jump_model(container)
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(atan((PSY.get_max_reactive_power(d) / PSY.get_max_active_power(d))))
        reactive = get_variable(container, U(), V)[name, t]
        real = get_variable(container, ActivePowerVariable(), V)[name, t] * pf
        constraint[name, t] = JuMP.@constraint(jump_model, reactive == real)
    end
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{ActivePowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.ControllableLoad, W <: DispatchablePowerLoad}
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
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.ControllableLoad, W <: InterruptiblePowerLoad}
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

############################## FormulationControllable Load Cost ###########################
function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ControllableLoad, U <: DispatchablePowerLoad}
    add_variable_cost!(container, ActivePowerVariable(), devices, U())
    return
end

function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ControllableLoad, U <: InterruptiblePowerLoad}
    add_proportional_cost!(container, OnVariable(), devices, U())
    return
end
