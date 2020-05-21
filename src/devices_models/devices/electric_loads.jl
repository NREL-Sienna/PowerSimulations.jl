abstract type AbstractLoadFormulation <: AbstractDeviceFormulation end
abstract type AbstractControllablePowerLoadFormulation <: AbstractLoadFormulation end
struct StaticPowerLoad <: AbstractLoadFormulation end
struct InterruptiblePowerLoad <: AbstractControllablePowerLoadFormulation end
struct DispatchablePowerLoad <: AbstractControllablePowerLoadFormulation end

########################### dispatchable load variables ####################################
function activepower_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
) where {L <: PSY.ElectricLoad}
    add_variable(
        psi_container,
        devices,
        variable_name(ACTIVE_POWER, L),
        false,
        :nodal_balance_active,
        -1.0;
        ub_value = x -> PSY.get_maxactivepower(x),
        lb_value = x -> 0.0,
    )
    return
end

function reactivepower_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
) where {L <: PSY.ElectricLoad}
    add_variable(
        psi_container,
        devices,
        variable_name(REACTIVE_POWER, L),
        false,
        :nodal_balance_reactive,
        -1.0;
        ub_value = x -> PSY.get_maxreactivepower(x),
        lb_value = x -> 0.0,
    )
    return
end

function commitment_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
) where {L <: PSY.ElectricLoad}
    add_variable(psi_container, devices, variable_name(ON, L), true)
    return
end

####################################### Reactive Power Constraints #########################
"""
Reactive Power Constraints on Controllable Loads Assume Constant PowerFactor
"""
function reactivepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
    model::DeviceModel{L, <:AbstractControllablePowerLoadFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {L <: PSY.ElectricLoad}
    time_steps = model_time_steps(psi_container)
    constraint = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)
    assign_constraint!(psi_container, REACTIVE, L, constraint)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(atan((PSY.get_maxreactivepower(d) / PSY.get_maxactivepower(d))))
        reactive = get_variable(psi_container, REACTIVE_POWER, L)[name, t]
        real = get_variable(psi_container, ACTIVE_POWER, L)[name, t] * pf
        constraint[name, t] = JuMP.@constraint(psi_container.JuMPmodel, reactive == real)
    end
    return
end

function ActivePowerConstraintsInputs(
    ::Type{T},
    ::Type{U},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.ElectricLoad, U <: DispatchablePowerLoad}
    return ActivePowerConstraintsInputs(;
        limits = x -> (min = 0.0, max = PSY.get_active(x)),
        range_constraint = device_range,
        multiplier = x -> PSY.get_maxactivepower(x),
        timeseries_func = use_parameters ? device_timeseries_param_ub :
                          device_timeseries_ub,
        parameter_name = use_parameters ? ACTIVE_POWER : nothing,
        constraint_name = use_forecasts ? ACTIVE : ACTIVE_RANGE,
        variable_name = ACTIVE_POWER,
        bin_variable_name = nothing,
        forecast_label = "get_maxactivepower",
    )
end

function ActivePowerConstraintsInputs(
    ::Type{T},
    ::Type{U},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.ElectricLoad, U <: InterruptiblePowerLoad}
    return ActivePowerConstraintsInputs(;
        limits = x -> (min = 0.0, max = PSY.get_active(x)),
        range_constraint = device_semicontinuousrange,
        multiplier = x -> PSY.get_maxactivepower(x),
        timeseries_func = use_parameters ? device_timeseries_ub_bigM :
                          device_timeseries_ub_bin,
        parameter_name = use_parameters ? ON : nothing,
        constraint_name = use_forecasts ? ACTIVE : ACTIVE_RANGE,
        variable_name = ACTIVE_POWER,
        bin_variable_name = ON,
        forecast_label = "get_maxactivepower",
    )
end

########################## Addition to the nodal balances ##################################

function NodalExpressionInputs(
    ::Type{<:PSY.ElectricLoad},
    ::Type{<:PM.AbstractPowerModel},
    use_forecasts::Bool,
)
    return NodalExpressionInputs(
        "get_maxactivepower",
        REACTIVE_POWER,
        use_forecasts ? x -> PSY.get_maxreactivepower(x) : x -> PSY.get_reactivepower(x),
        -1.0,
    )
end

function NodalExpressionInputs(
    ::Type{<:PSY.ElectricLoad},
    ::Type{<:PM.AbstractActivePowerModel},
    use_forecasts::Bool,
)
    return NodalExpressionInputs(
        "get_maxactivepower",
        ACTIVE_POWER,
        use_forecasts ? x -> PSY.get_maxactivepower(x) : x -> PSY.get_activepower(x),
        -1.0,
    )
end

############################## FormulationControllable Load Cost ###########################
function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
    ::Type{DispatchablePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
) where {L <: PSY.ControllableLoad}
    add_to_cost(psi_container, devices, variable_name(ACTIVE_POWER, L), :variable, -1.0)
    return
end

function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
    ::Type{InterruptiblePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
) where {L <: PSY.ControllableLoad}
    add_to_cost(psi_container, devices, variable_name(ON, L), :fixed, -1.0)
    return
end
