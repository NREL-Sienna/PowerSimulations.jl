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

function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
    model::DeviceModel{L, DispatchablePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {L <: PSY.ElectricLoad}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    @assert !(parameters && !use_forecast_data)

    if !parameters && !use_forecast_data
        constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
        for (ix, d) in enumerate(devices)
            name = PSY.get_name(d)
            ub = PSY.get_activepower(d)
            limits = (min = 0.0, max = ub)
            constraint_info = DeviceRangeConstraintInfo(name, limits)
            add_device_services!(constraint_info, d, model)
            constraint_infos[ix] = constraint_info
        end
        device_range(
            psi_container,
            constraint_infos,
            constraint_name(ACTIVE_RANGE, L),
            variable_name(ACTIVE_POWER, L),
        )
        return
    end

    forecast_label = "get_maxactivepower"
    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        constraint_info =
            DeviceTimeSeriesConstraintInfo(d, x -> PSY.get_maxactivepower(x), ts_vector)
        add_device_services!(constraint_info.range, d, model)
        constraint_infos[ix] = constraint_info
    end

    if parameters
        device_timeseries_param_ub(
            psi_container,
            constraint_infos,
            constraint_name(ACTIVE, L),
            UpdateRef{L}(ACTIVE_POWER, forecast_label),
            variable_name(ACTIVE_POWER, L),
        )
    else
        device_timeseries_ub(
            psi_container,
            constraint_infos,
            constraint_name(ACTIVE, L),
            variable_name(ACTIVE_POWER, L),
        )
    end
    return
end

function activepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{L},
    model::DeviceModel{L, InterruptiblePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {L <: PSY.ElectricLoad}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)

    if !parameters && !use_forecast_data
        constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
        for (ix, d) in enumerate(devices)
            name = PSY.get_name(d)
            ub = PSY.get_active(d)
            limits = (min = 0.0, max = ub)
            constraint_info = DeviceRangeConstraintInfo(name, limits)
            add_device_services!(constraint_info, d, model)
            constraint_infos[ix] = constraint_info
        end
        device_semicontinuousrange(
            psi_container,
            constraint_infos,
            constraint_name(ACTIVE_RANGE, L),
            variable_name(ACTIVE_POWER, L),
            variable_name(ON, L),
        )
        return
    end

    forecast_label = "get_maxactivepower"
    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        constraint_info =
            DeviceTimeSeriesConstraintInfo(d, x -> PSY.get_maxactivepower(x), ts_vector)
        add_device_services!(constraint_info.range, d, model)
        constraint_infos[ix] = constraint_info
    end

    if parameters
        device_timeseries_ub_bigM(
            psi_container,
            constraint_infos,
            constraint_name(ACTIVE, L),
            variable_name(ACTIVE_POWER, L),
            UpdateRef{L}(ON, forecast_label),
            constraint_name(ON, L),
        )
    else
        device_timeseries_ub_bin(
            psi_container,
            constraint_infos,
            constraint_name(ACTIVE, L),
            variable_name(ACTIVE_POWER, L),
            variable_name(ON, L),
        )
    end
    return
end

########################## Addition to the nodal balances ##################################

function NodalExpressionInputs(
    ::Type{T},
    ::Type{<:PM.AbstractPowerModel},
    use_forecasts::Bool,
) where T <:PSY.ElectricLoad
    return NodalExpressionInputs(
        "get_maxactivepower",
        REACTIVE_POWER,
        use_forecasts ? x -> PSY.get_maxreactivepower(x) : x -> PSY.get_reactivepower(x),
        -1.0,
        T
    )
end

function NodalExpressionInputs(
    ::Type{T},
    ::Type{<:PM.AbstractActivePowerModel},
    use_forecasts::Bool,
) where T <: PSY.ElectricLoad
    return NodalExpressionInputs(
        "get_maxactivepower",
        ACTIVE_POWER,
        use_forecasts ? x -> PSY.get_maxactivepower(x) : x -> PSY.get_activepower(x),
        -1.0,
        T
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
