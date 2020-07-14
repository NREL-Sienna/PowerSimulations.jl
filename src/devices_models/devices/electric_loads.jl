abstract type AbstractLoadFormulation <: AbstractDeviceFormulation end
abstract type AbstractControllablePowerLoadFormulation <: AbstractLoadFormulation end
struct StaticPowerLoad <: AbstractLoadFormulation end
struct InterruptiblePowerLoad <: AbstractControllablePowerLoadFormulation end
struct DispatchablePowerLoad <: AbstractControllablePowerLoadFormulation end

########################### dispatchable load variables ####################################
function AddVariableSpec(
    ::Type{T},
    ::Type{U},
    ::PSIContainer,
) where {T <: ActivePowerVariable, U <: PSY.ElectricLoad}
    return AddVariableSpec(;
        variable_name = make_name(T, U),
        binary = false,
        expression_name = :nodal_balance_active,
        sign = -1.0,
        lb_value_func = x -> 0.0,
        ub_value_func = x -> PSY.get_max_active_power(x),
    )
end

function AddVariableSpec(
    ::Type{T},
    ::Type{U},
    ::PSIContainer,
) where {T <: ReactivePowerVariable, U <: PSY.ElectricLoad}
    return AddVariableSpec(;
        variable_name = make_name(T, U),
        binary = false,
        expression_name = :nodal_balance_reactive,
        sign = -1.0,
        lb_value_func = x -> 0.0,
        ub_value_func = x -> PSY.get_max_reactive_power(x),
    )
end

function AddVariableSpec(
    ::Type{T},
    ::Type{U},
    ::PSIContainer,
) where {T <: OnVariable, U <: PSY.ElectricLoad}
    return AddVariableSpec(; variable_name = make_name(T, U), binary = true)
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
        pf = sin(atan((PSY.get_max_reactive_power(d) / PSY.get_max_active_power(d))))
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
                limits_func = x -> (min = 0.0, max = PSY.get_active_power(x)),
                constraint_func = device_range,
                constraint_struct = DeviceRangeConstraintInfo,
            )],
        )
    end

    return DeviceRangeConstraintInputs(;
        timeseries_range_constraint_inputs = [TimeSeriesConstraintInputs(
            constraint_name = ACTIVE,
            variable_name = ACTIVE_POWER,
            parameter_name = use_parameters ? ACTIVE_POWER : nothing,
            forecast_label = "get_max_active_power",
            multiplier_func = x -> PSY.get_max_active_power(x),
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
                bin_variable_names = [ON],
                limits_func = x -> (min = 0.0, max = PSY.get_active_power(x)),
                constraint_func = device_semicontinuousrange,
                constraint_struct = DeviceRangeConstraintInfo,
            )],
        )
    end

    return DeviceRangeConstraintInputs(;
        timeseries_range_constraint_inputs = [TimeSeriesConstraintInputs(
            constraint_name = ACTIVE,
            variable_name = ACTIVE_POWER,
            bin_variable_name = ON,
            parameter_name = use_parameters ? ON : nothing,
            forecast_label = "get_max_active_power",
            multiplier_func = x -> PSY.get_max_active_power(x),
            constraint_func = use_parameters ? device_timeseries_ub_bigM :
                              device_timeseries_ub_bin,
        )],
    )
end

########################## Addition to the nodal balances ##################################

function NodalExpressionSpec(
    ::Type{T},
    ::Type{<:PM.AbstractPowerModel},
    use_forecasts::Bool,
) where {T <: PSY.ElectricLoad}
    return NodalExpressionSpec(
        "get_max_active_power",
        REACTIVE_POWER,
        use_forecasts ? x -> PSY.get_max_reactive_power(x) : x -> PSY.get_reactive_power(x),
        -1.0,
        T,
    )
end

function NodalExpressionSpec(
    ::Type{T},
    ::Type{<:PM.AbstractActivePowerModel},
    use_forecasts::Bool,
) where {T <: PSY.ElectricLoad}
    return NodalExpressionSpec(
        "get_max_active_power",
        ACTIVE_POWER,
        use_forecasts ? x -> PSY.get_max_active_power(x) : x -> PSY.get_active_power(x),
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
