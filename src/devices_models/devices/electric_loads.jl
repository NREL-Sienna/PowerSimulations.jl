#! format: off
########################### ElectricLoad ####################################

get_variable_multiplier(_, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = -1.0

########################### ActivePowerVariable, ElectricLoad ####################################

get_variable_binary(::ActivePowerVariable, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = false
get_variable_lower_bound(::ActivePowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = 0.0
get_variable_upper_bound(::ActivePowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = PSY.get_max_active_power(d)

########################### ReactivePowerVariable, ElectricLoad ####################################

get_variable_binary(::ReactivePowerVariable, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = false

get_variable_lower_bound(::ReactivePowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = 0.0
get_variable_upper_bound(::ReactivePowerVariable, d::PSY.ElectricLoad, ::AbstractLoadFormulation) = PSY.get_max_reactive_power(d)

########################### ReactivePowerVariable, ElectricLoad ####################################

get_variable_binary(::OnVariable, ::Type{<:PSY.ElectricLoad}, ::AbstractLoadFormulation) = true

########################### Parameters, ElectricLoad ####################################

get_multiplier_value(::TimeSeriesParameter, d::PSY.ElectricLoad, ::StaticPowerLoad) = -1*PSY.get_max_active_power(d)
get_multiplier_value(::ReactivePowerTimeSeriesParameter, d::PSY.ElectricLoad, ::StaticPowerLoad) = -1*PSY.get_max_reactive_power(d)
get_multiplier_value(::TimeSeriesParameter, d::PSY.ElectricLoad, ::AbstractControllablePowerLoadFormulation) = PSY.get_max_active_power(d)
get_multiplier_value(::TimeSeriesParameter, d::PSY.ShiftablePowerLoad, ::PowerLoadShift) = -1*PSY.get_max_active_power(d)

# To avoid ambiguity with default_interface_methods.jl:
get_multiplier_value(::AbstractPiecewiseLinearBreakpointParameter, ::PSY.ElectricLoad, ::StaticPowerLoad) = 1.0
get_multiplier_value(::AbstractPiecewiseLinearBreakpointParameter, ::PSY.ElectricLoad, ::AbstractControllablePowerLoadFormulation) = 1.0


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
    ::Type{<:PSY.ShiftablePowerLoad},
    ::Type{<:PowerLoadShift},
)
    return Dict{Type{<:TimeSeriesParameter}, String}(
        ActivePowerTimeSeriesParameter => "active_power",
        UpperBoundActivePowerTimeSeriesParameter => "upper_bound_active_power",
        LowerBoundActivePowerTimeSeriesParameter => "lower_bound_active_power",
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

function get_default_time_series_names(
    ::Type{<:PSY.MotorLoad},
    ::Type{<:Union{FixedOutput, AbstractLoadFormulation}},
)
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

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
    network_model::NetworkModel{X},
) where {
    V <: PSY.ElectricLoad,
    W <: AbstractControllablePowerLoadFormulation,
    X <: PM.AbstractPowerModel,
}
    time_steps = get_time_steps(container)
    constraint = add_constraints_container!(
        container,
        T(),
        V,
        PSY.get_name.(devices),
        time_steps,
    )
    jump_model = get_jump_model(container)
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(atan((PSY.get_max_reactive_power(d) / PSY.get_max_active_power(d))))
        reactive = get_variable(container, U(), V)[name, t]
        real = get_variable(container, ActivePowerVariable(), V)[name, t]
        constraint[name, t] = JuMP.@constraint(jump_model, reactive == real * pf)
    end
end

"""
Add reactive power constraints for [`PowerLoadShift`](@ref) formulation

Assume constant power factor based on `max_active_power` and `max_reactive_power`.
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:ReactivePowerVariableLimitsConstraint},
    U::Type{<:ReactivePowerVariable},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    network_model::NetworkModel{X},
) where {V <: PSY.ShiftablePowerLoad, W <: PowerLoadShift, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    param_array_activepower = get_parameter_array(container, ActivePowerTimeSeriesParameter(), V)
    param_multiplier_activepower = get_parameter_multiplier_array(container, ActivePowerTimeSeriesParameter(), V)
    constraint = add_constraints_container!(
        container,
        T(),
        V,
        PSY.get_name.(devices),
        time_steps,
    )
    jump_model = get_jump_model(container)
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(atan((PSY.get_max_reactive_power(d) / PSY.get_max_active_power(d))))
        reactive = get_variable(container, U(), V)[name, t]
        real_shift = get_variable(container, ShiftedActivePowerVariable(), V)[name, t]
        constraint[name, t] = JuMP.@constraint(jump_model, reactive == (real_shift + param_array_activepower[name, t] * param_multiplier_activepower[name, t]) * pf)
    end
end

####################################### Active Power Constraints #########################
function add_constraints!(
    container::OptimizationContainer,
    ::Type{ActivePowerVariableLimitsConstraint},
    U::Type{<:VariableType},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::NetworkModel{X},
) where {V <: PSY.ControllableLoad, W <: PowerLoadDispatch, X <: PM.AbstractPowerModel}
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
    ::NetworkModel{X},
) where {V <: PSY.ControllableLoad, W <: PowerLoadInterruption, X <: PM.AbstractPowerModel}
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
    U::Type{OnVariable},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
    ::NetworkModel{X},
) where {V <: PSY.ControllableLoad, W <: PowerLoadInterruption, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    constraint = add_constraints_container!(
        container,
        T(),
        V,
        PSY.get_name.(devices),
        time_steps;
        meta = "binary",
    )
    on_variable = get_variable(container, U(), V)
    power = get_variable(container, ActivePowerVariable(), V)
    jump_model = get_jump_model(container)
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pmax = PSY.get_max_active_power(d)
        constraint[name, t] =
            JuMP.@constraint(jump_model, power[name, t] <= on_variable[name, t] * pmax)
    end
    return
end

"""
Add [`ShiftedActivePowerBalanceConstraint`](@ref) for [`PowerLoadShift`](@ref) formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:ShiftedActivePowerBalanceConstraint},
    U::Type{<:ShiftedActivePowerVariable},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::NetworkModel{X},
) where {V <: PSY.ShiftablePowerLoad, W <: PowerLoadShift, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    num_time_steps = length(time_steps)
    resolution = get_resolution(container)
    # Don't use constraints container because each device could have its own load balance time horizon (variable dimensions)
    jump_model = get_jump_model(container)
    p_shift = get_variable(container, U(), V)
    for d in devices
        name = PSY.get_name(d)
        Tb = round(Int, get_load_balance_time_horizon(d)/resolution)
        for k in 1:ceil(num_time_steps/Tb)
            JuMP.@constraint(jump_model, sum(p_shift[name, t] for t in (k-1)*Tb+1:minimum(k*Tb,num_time_steps)) == 0.0)
        end
    end
    return
end

"""
Add [`ShiftedActivePowerVariableLimitsConstraint`](@ref) for [`PowerLoadShift`](@ref) formulation
    
Assumes the user has provided time series parameters for the active power load.
Only non-negative loads are allowed (i.e., both the requested active power and lower bound
active power must be ``\\ge 0``).
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:ShiftedActivePowerVariableLimitsConstraint},
    U::Type{<:ShiftedActivePowerVariable},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::NetworkModel{X},
) where {V <: PSY.ShiftablePowerLoad, W <: PowerLoadShift, X <: PM.AbstractPowerModel}
    time_steps = get_time_steps(container)
    jump_model = get_jump_model(container)
    p_shift = get_variable(container, U(), V)

    param_array_activepower = get_parameter_array(container, ActivePowerTimeSeriesParameter(), V)
    param_multiplier_activepower = get_parameter_multiplier_array(container, ActivePowerTimeSeriesParameter(), V)

    param_array_lb = get_parameter_array(container, LowerBoundActivePowerTimeSeriesParameter(), V)
    param_multiplier_lb = get_parameter_multiplier_array(container, LowerBoundActivePowerTimeSeriesParameter(), V)

    param_array_ub = get_parameter_array(container, UpperBoundActivePowerTimeSeriesParameter(), V)
    param_multiplier_ub = get_parameter_multiplier_array(container, UpperBoundActivePowerTimeSeriesParameter(), V)

    lower_bound_constraint = add_constraints_container!(
        container,
        T(),
        V,
        PSY.get_name.(devices),
        time_steps; 
        meta = "lb"
    )
    upper_bound_constraint = add_constraints_container!(
        container,
        T(),
        V,
        PSY.get_name.(devices),
        time_steps; 
        meta = "ub"
    )
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        if param_array_activepower[name, t] < 0.0
            error("Device $d has a negative active power load of $(param_array_activepower[name, t]) at time $t.")
        elseif param_array_lb[name, t] < 0.0
            error("Device $d has a negative lower bound of $(param_array_lb[name, t]) for the active power load at time $t.")
        end
        lower_bound_constraint[name, t] = JuMP.@constraint(jump_model, p_shift[name, t] >= param_array_lb[name,t] * param_multiplier_lb[name, t] - param_array_activepower[name, t] * param_multiplier_activepower[name, t])
        upper_bound_constraint[name, t] = JuMP.@constraint(jump_model, p_shift[name, t] <= param_array_ub[name,t] * param_multiplier_ub[name, t] - param_array_activepower[name, t] * param_multiplier_activepower[name, t])
    end
    return
end

"""
Add [`ShiftedActivePowerForwardConstraint`](@ref) for [`PowerLoadShift`](@ref) formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:ShiftedActivePowerForwardConstraint},
    U::Type{<:ShiftedActivePowerVariable},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::NetworkModel{X},
) where {V <: PSY.ShiftablePowerLoad, W <: PowerLoadShift, X <: PM.AbstractPowerModel}

    jump_model = get_jump_model(container)
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    num_time_steps = length(time_steps)
    p_shift = get_variable(container, U(), V)

    constraint = add_constraints_container!(
        container,
        T(),
        V,
        PSY.get_name.(devices),
        time_steps; 
        meta = "shift_load_forward_only"
    )
    
    for d in devices
        name = PSY.get_name(d)
        Tb = round(Int, get_load_balance_time_horizon(d)/resolution)
        for k in 1:ceil(num_time_steps/Tb)
            for t in (k-1)*Tb+1:minimum(k*Tb,num_time_steps)
                if t==(k-1)*Tb+1
                    constraint[name, t] = JuMP.@constraint(jump_model, p_shift[name, t] <= 0.0)
                else
                    constraint[name, t] = JuMP.@constraint(jump_model, p_shift[name, t] <= sum(p_shift[name, i] for i in (k-1)*Tb+1:t-1))
                end
            end
        end
    end
    return
end

############################## FormulationControllable Load Cost ###########################
function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ControllableLoad, U <: PowerLoadDispatch}
    add_variable_cost!(container, ActivePowerVariable(), devices, U())
    return
end

function objective_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.ControllableLoad, U <: PowerLoadInterruption}
    add_variable_cost!(container, ActivePowerVariable(), devices, U())
    add_proportional_cost!(container, OnVariable(), devices, U())
    return
end

# code repetition: basically copy-paste from thermal_generation.jl, just change types
# and incremental to decremental.
function proportional_cost(
    container::OptimizationContainer,
    cost::PSY.LoadCost,
    S::OnVariable,
    T::PSY.ControllableLoad,
    U::PowerLoadInterruption,
    t::Int,
)
    return onvar_cost(container, cost, S, T, U, t) +
           PSY.get_constant_term(PSY.get_vom_cost(PSY.get_variable(cost))) +
           PSY.get_fixed(cost)
end

function onvar_cost(
    container::OptimizationContainer,
    cost::PSY.LoadCost,
    ::OnVariable,
    d::PSY.ControllableLoad,
    ::PowerLoadInterruption,
    t::Int,
)
    return _onvar_cost(container, PSY.get_variable(cost), d, t)
end

is_time_variant_term(
    ::OptimizationContainer,
    ::PSY.LoadCost,
    ::OnVariable,
    ::PSY.ControllableLoad,
    ::AbstractLoadFormulation,
    ::Int,
) = false

is_time_variant_term(
    ::OptimizationContainer,
    cost::PSY.MarketBidCost,
    ::OnVariable,
    ::PSY.ControllableLoad,
    ::PowerLoadInterruption,
    ::Int,
) =
    is_time_variant(PSY.get_decremental_initial_input(cost))

proportional_cost(
    container::OptimizationContainer,
    cost::PSY.MarketBidCost,
    ::OnVariable,
    comp::PSY.ControllableLoad,
    ::PowerLoadInterruption,
    t::Int,
) =
    _lookup_maybe_time_variant_param(container, comp, t,
        Val(is_time_variant(PSY.get_decremental_initial_input(cost))),
        PSY.get_initial_input ∘ PSY.get_decremental_offer_curves ∘ PSY.get_operation_cost,
        DecrementalCostAtMinParameter())
