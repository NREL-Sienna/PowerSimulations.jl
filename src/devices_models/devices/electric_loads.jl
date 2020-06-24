abstract type AbstractLoadFormulation <: AbstractDeviceFormulation end
abstract type AbstractControllablePowerLoadFormulation <: AbstractLoadFormulation end
struct StaticPowerLoad <: AbstractLoadFormulation end
struct InterruptiblePowerLoad <: AbstractControllablePowerLoadFormulation end
struct DispatchablePowerLoad <: AbstractControllablePowerLoadFormulation end

########################### dispatchable load variables ####################################
function make_variable_inputs(
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::PSIContainer,
) where {T <: PSY.ElectricLoad}
    return AddVariableInputs(;
        variable_name = make_variable_name(ACTIVE_POWER, T),
        binary = false,
        expression_name = :nodal_balance_active,
        sign = -1.0,
        lb_value_func = x -> 0.0,
        ub_value_func = x -> PSY.get_maxactivepower(x),
    )
end

function make_variable_inputs(
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::PSIContainer,
) where {T <: PSY.ElectricLoad}
    return AddVariableInputs(;
        variable_name = make_variable_name(REACTIVE_POWER, T),
        binary = false,
        expression_name = :nodal_balance_reactive,
        sign = -1.0,
        lb_value_func = x -> 0.0,
        ub_value_func = x -> PSY.get_maxreactivepower(x),
    )
end

function make_variable_inputs(
    ::Type{CommitmentVariable},
    ::Type{T},
    ::PSIContainer,
) where {T <: PSY.ElectricLoad}
    return AddVariableInputs(; variable_name = make_variable_name(ON, T), binary = true)
end

####################################### Reactive Power Constraints #########################
"""
Reactive Power Constraints on Controllable Loads Assume Constant PowerFactor
"""
function make_reactive_power_constraints_inputs(
    ::Type{<:PSY.ElectricLoad},
    ::Type{<:AbstractControllablePowerLoadFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
)
    return DeviceRangeConstraintInputs(;
        custom_psi_container_func = custom_reactive_power_constraints!,
    )
end

function custom_reactive_power_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{<:AbstractControllablePowerLoadFormulation},
) where {T <: PSY.ElectricLoad}
    time_steps = model_time_steps(psi_container)
    constraint = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)
    assign_constraint!(psi_container, REACTIVE, T, constraint)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(atan((PSY.get_maxreactivepower(d) / PSY.get_maxactivepower(d))))
        reactive = get_variable(psi_container, REACTIVE_POWER, T)[name, t]
        real = get_variable(psi_container, ACTIVE_POWER, T)[name, t] * pf
        constraint[name, t] = JuMP.@constraint(psi_container.JuMPmodel, reactive == real)
    end
end

function make_active_power_constraints_inputs(
    ::Type{<:PSY.ElectricLoad},
    ::Type{<:DispatchablePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
)
    if (!use_parameters && !use_forecasts)
        return DeviceRangeConstraintInputs(;
            range_constraint_inputs = [RangeConstraintInputs(;
                constraint_name = ACTIVE_RANGE,
                variable_name = ACTIVE_POWER,
                limits_func = x -> (min = 0.0, max = PSY.get_activepower(x)),
                constraint_func = device_range,
            )],
        )
    end

    return DeviceRangeConstraintInputs(;
        timeseries_range_constraint_inputs = [TimeSeriesConstraintInputs(
            constraint_name = ACTIVE,
            variable_name = ACTIVE_POWER,
            parameter_name = use_parameters ? ACTIVE_POWER : nothing,
            forecast_label = "get_maxactivepower",
            multiplier_func = x -> PSY.get_maxactivepower(x),
            constraint_func = use_parameters ? device_timeseries_param_ub :
                              device_timeseries_ub,
        )],
    )
end

function make_active_power_constraints_inputs(
    ::Type{<:PSY.ElectricLoad},
    ::Type{<:InterruptiblePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
)
    if (!use_parameters && !use_forecasts)
        return DeviceRangeConstraintInputs(;
            range_constraint_inputs = [RangeConstraintInputs(;
                constraint_name = ACTIVE_RANGE,
                variable_name = ACTIVE_POWER,
                bin_variable_name = ON,
                limits_func = x -> (min = 0.0, max = PSY.get_activepower(x)),
                constraint_func = device_semicontinuousrange,
            )],
        )
    end

    return DeviceRangeConstraintInputs(;
        timeseries_range_constraint_inputs = [TimeSeriesConstraintInputs(
            constraint_name = ACTIVE,
            variable_name = ACTIVE_POWER,
            bin_variable_name = ON,
            parameter_name = use_parameters ? ON : nothing,
            forecast_label = "get_maxactivepower",
            multiplier_func = x -> PSY.get_maxactivepower(x),
            constraint_func = use_parameters ? device_timeseries_ub_bigM :
                              device_timeseries_ub_bin,
        )],
    )
end

########################## Addition to the nodal balances ##################################

function make_nodal_expression_inputs(
    ::Type{T},
    ::Type{<:PM.AbstractPowerModel},
    use_forecasts::Bool,
) where {T <: PSY.ElectricLoad}
    return NodalExpressionInputs(
        "get_maxactivepower",
        REACTIVE_POWER,
        use_forecasts ? x -> PSY.get_maxreactivepower(x) : x -> PSY.get_reactivepower(x),
        -1.0,
        T,
    )
end

function make_nodal_expression_inputs(
    ::Type{T},
    ::Type{<:PM.AbstractActivePowerModel},
    use_forecasts::Bool,
) where {T <: PSY.ElectricLoad}
    return NodalExpressionInputs(
        "get_maxactivepower",
        ACTIVE_POWER,
        use_forecasts ? x -> PSY.get_maxactivepower(x) : x -> PSY.get_activepower(x),
        -1.0,
        T,
    )
end

############################## FormulationControllable Load Cost ###########################
function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
    ::Type{DispatchablePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
) where {L <: PSY.ControllableLoad}
    add_to_cost(
        psi_container,
        devices,
        make_variable_name(ACTIVE_POWER, L),
        :variable,
        -1.0,
    )
    return
end

function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
    ::Type{InterruptiblePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
) where {L <: PSY.ControllableLoad}
    add_to_cost(psi_container, devices, make_variable_name(ON, L), :fixed, -1.0)
    return
end
