#! format: off
########################### ElectricLoad ####################################

get_variable_multiplier(_, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = -1.0

########################### ActivePowerVariable, ElectricLoad ####################################

get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = false
get_variable_lower_bound(::ActivePowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = 0.0
get_variable_upper_bound(::ActivePowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = PSY.get_active_power(d)

############################ DeltaPowerVariable and DeferedChargeVariable ############################
get_variable_binary(::DeltaPowerVariable, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = false
get_variable_lower_bound(::DeltaPowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = PSY.get_delta_power_min()
get_variable_upper_bound(::DeltaPowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = PSY.get_delta_power_max()

get_variable_binary(::DeferedChargeVariable, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = false
get_variable_lower_bound(::DeferedChargeVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = PSY.get_delta_charge_min()
get_variable_upper_bound(::DeferedChargeVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = 0.0

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

function get_default_time_series_names(
    ::Type{<:PSY.ElectricLoad},
    ::Type{DispatchableEVLoad},
)
    #TODO: replace with new names
    return Dict{Type{<:TimeSeriesParameter}, String}(
        PowerBaseParameter => "baseload",
        DeltaStateChargeMinParameter => "min_deferebale_charge",
        DeltaPowerMaxParameter => "Max_charge_power",
        DeltaPowerMinParameter => "Min_charge_power",
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

# Constraint for bounding DeltaPowerVariable
function add_constraints!(
    container::OptimizationContainer,
    T::Type{DeltaPowerBoundsConstraint},
    U::Type{DeltaPowerVariable},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.ControllableLoad, W <: DispatchablePowerLoad}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]

    constraint_lb = add_constraints_container!(container, T(), V, names, time_steps, meta="lb")
    constraint_ub = add_constraints_container!(container, T(), V, names, time_steps, meta="ub")
    variable = get_variable(container, DeltaPowerVariable(), V)
    parameter_min = get_parameter_array(container, DeltaPowerMinParameter(), V)
    parameter_max = get_parameter_array(container, DeltaPowerMaxParameter(), V)
    multiplier_min = get_parameter_multiplier_array(container, DeltaPowerMinParameter(), V)
    multiplier_max = get_parameter_multiplier_array(container, DeltaPowerMaxParameter(), V)
    jump_model = get_jump_model(container)
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        constraint_lb[name, t] = JuMP.@constraint(
            jump_model,
            variable[name, t] >= multiplier_min[name, t] * parameter_min[name, t]
        )

        constraint_ub[name, t] = JuMP.@constraint(
            jump_model,
            variable[name, t] <= multiplier_max[name, t] * parameter_max[name, t]
        )
    end
    return
end

# Constraint for bounding DeferedChargeVariable
function add_constraints!(
    container::OptimizationContainer,
    T::Type{DeltaStateChargeBoundsConstraint},
    U::Type{DeferedChargeVariable},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.ControllableLoad, W <: DispatchablePowerLoad}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]

    constraint_lb = add_constraints_container!(container, T(), V, names, time_steps, meta="lb")
    constraint_ub = add_constraints_container!(container, T(), V, names, time_steps, meta="ub")
    variable = get_variable(container, DeferedChargeVariable(), V)
    parameter_min = get_parameter_array(container, DeltaStateChargeMinParameter(), V)
    multiplier = get_parameter_multiplier_array(container, DeltaStateChargeMinParameter(), V)
    jump_model = get_jump_model(container)
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        constraint_lb[name, t] = JuMP.@constraint(
            jump_model,
            variable[name, t] >= multiplier[name, t] * parameter_min[name, t]
        )

        constraint_ub[name, t] = JuMP.@constraint(
            jump_model,
            variable[name, t] <= 0.0
        )
    end
    return
end

# Constraint for calculating defered charge in each time step
function add_constraints!(
    container::OptimizationContainer,
    T::Type{EnergyBalanceConstraint},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    X::Type{<:PM.AbstractPowerModel},
) where {V <: PSY.ControllableLoad, W <: DispatchablePowerLoad}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]

    resolution = get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / MINUTES_IN_HOUR

    constraint= add_constraints_container!(container, T(), V, names, time_steps, meta="defered")
    variable_S = get_variable(container, DeferedChargeVariable(), V)
    variable_P = get_variable(container, DeltaPowerVariable(), V)
    multiplier_S = get_parameter_multiplier_array(container, DeferedChargeVariable(), V)
    multiplier_P = get_parameter_multiplier_array(container, DeltaPowerVariable(), V)
    jump_model = get_jump_model(container)
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        if t == 1
            constraint_lb[name, t] = JuMP.@constraint(
                jump_model,
                variable_S[name, t] = multiplier_P[name, t] * variable_P[name, t] * fraction_of_hour
            )
        else
            constraint_ub[name, t] = JuMP.@constraint(
                jump_model,
                variable_S[name, t] = multiplier_S[name, t-1] * variable_S[name, t-1] + multiplier_P[name, t] * variable_P[name, t] * fraction_of_hour
            )
    end
    return
end


# function add_constraints!(
#     container::OptimizationContainer,
#     T::Type{EVLoadBalanceConstraint},
#     devices::IS.FlattenIteratorWrapper{V},
#     model::DeviceModel{V, W},
#     X::Type{<:PM.AbstractPowerModel},
# ) where {V <: PSY.ControllableLoad, W <: DispatchablePowerLoad}
#     time_steps = get_time_steps(container)
#     names = [PSY.get_name(d) for d in devices]
#     #TODO: Juliette this is an example of how you would have to add new constraints
#     # in this case I'm adding the ev load balance constraint. this is a type 2 constraint call
#     # where we are only passing the constraint type as it will use multiple different variables
#     # that are called within the function.
#     constraint_a = add_constraints_container!(container, T(), V, names, time_steps,)
#     # you can create more than one constraint using passing unique meta String like this
#     constraint_b = add_constraints_container!(container, T(), V, names, time_steps, meta="ub")
#     variable_p = get_variable(container, ActivePowerVariable(), V)
#     variable_def = get_variable(container, DeferedChargeVariable(), V)
#     variable_c_def = get_variable(container, CumulativeDefferedChargeVariable(), V)
#     # you can also call parameters in here if needed
#     parameter = get_parameter_array(container, MaximumDefferedChargingTimeSeriesParameter(), V)
#     multiplier = get_parameter_multiplier_array(container, MaximumDefferedChargingTimeSeriesParameter(), V)
#     jump_model = get_jump_model(container)
#     for device in devices, t in time_steps
#         name = PSY.get_name(device)
#         constraint_a[name, t] = JuMP.@constraint(
#             jump_model,
#             # this is an example and not the real constraint
#             variable_c_def[name, t] == variable_c_def[name, t-1] + variable_def[name, t]
#         )
#         constraint_b[name, t] = JuMP.@constraint(
#             jump_model,
#             # this is an example and not the real constraint
#             variable_c_def[name, t] <= multiplier[name, t] * parameter[name, t]
#         )
#     end
#     return
# end

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
