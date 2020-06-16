abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end
abstract type AbstractRenewableDispatchFormulation <: AbstractRenewableFormulation end
struct RenewableFullDispatch <: AbstractRenewableDispatchFormulation end
struct RenewableConstantPowerFactor <: AbstractRenewableDispatchFormulation end

########################### renewable generation variables #################################
function activepower_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{R},
) where {R <: PSY.RenewableGen}
    add_variable(
        psi_container,
        devices,
        variable_name(ACTIVE_POWER, R),
        false,
        :nodal_balance_active;
        lb_value = x -> 0.0,
        ub_value = x -> PSY.get_rating(x),
    )
    return
end

function reactivepower_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{R},
) where {R <: PSY.RenewableGen}
    add_variable(
        psi_container,
        devices,
        variable_name(REACTIVE_POWER, R),
        false,
        :nodal_balance_reactive,
    )
    return
end

####################################### Reactive Power constraint_infos #########################
function make_reactive_power_constraints_inputs(
    ::Type{<:PSY.RenewableGen},
    ::Type{<:AbstractDeviceFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
)
    return DeviceRangeConstraintInputs(;
        range_constraint_inputs = [RangeConstraintInputs(;
            constraint_name = REACTIVE_RANGE,
            variable_name = REACTIVE_POWER,
            limits_func = x -> PSY.get_reactivepowerlimits(x),
            constraint_func = device_range,
        )],
    )
end

function make_reactive_power_constraints_inputs(
    ::Type{<:PSY.RenewableGen},
    ::Type{<:RenewableConstantPowerFactor},
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
    ::Type{RenewableConstantPowerFactor},
) where {T <: PSY.RenewableGen}
    names = (PSY.get_name(d) for d in devices)
    time_steps = model_time_steps(psi_container)
    p_var = get_variable(psi_container, ACTIVE_POWER, T)
    q_var = get_variable(psi_container, REACTIVE_POWER, T)
    constraint_val = JuMPConstraintArray(undef, names, time_steps)
    assign_constraint!(psi_container, REACTIVE_RANGE, T, constraint_val)
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(acos(PSY.get_powerfactor(d)))
        constraint_val[name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, q_var[name, t] == p_var[name, t] * pf)
    end
    return
end

function make_active_power_constraints_inputs(
    ::Type{<:PSY.RenewableGen},
    ::Type{<:AbstractRenewableDispatchFormulation},
    ::Type{<:PM.AbstractPowerModel},
    _::Union{Nothing, AbstractAffectFeedForward},
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
        timeseries_range_constraint_inputs = [TimeSeriesConstraintInputs(;
            constraint_name = ACTIVE,
            variable_name = ACTIVE_POWER,
            parameter_name = use_parameters ? ACTIVE_POWER : nothing,
            forecast_label = "get_rating",
            multiplier_func = x -> PSY.get_rating(x),
            constraint_func = use_parameters ? device_timeseries_param_ub :
                              device_timeseries_ub,
        )],
    )
end

########################## Addition to the nodal balances ##################################

function make_nodal_expression_inputs(
    ::Type{T},
    ::Type{<:PM.AbstractPowerModel},
    use_forecasts::Bool,
) where {T <: PSY.RenewableGen}
    return NodalExpressionInputs(
        "get_rating",
        REACTIVE_POWER,
        use_forecasts ? x -> PSY.get_rating(x) * sin(acos(PSY.get_powerfactor(x))) :
        x -> PSY.get_reactivepower(x),
        1.0,
        T,
    )
end

function make_nodal_expression_inputs(
    ::Type{T},
    ::Type{<:PM.AbstractActivePowerModel},
    use_forecasts::Bool,
) where {T <: PSY.RenewableGen}
    return NodalExpressionInputs(
        "get_rating",
        ACTIVE_POWER,
        use_forecasts ? x -> PSY.get_rating(x) * PSY.get_powerfactor(x) :
        x -> PSY.get_activepower(x),
        1.0,
        T,
    )
end

##################################### renewable generation cost ############################
function cost_function(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.RenewableDispatch},
    ::Type{D},
    ::Type{<:PM.AbstractPowerModel},
) where {D <: AbstractRenewableDispatchFormulation}
    add_to_cost(
        psi_container,
        devices,
        variable_name(ACTIVE_POWER, PSY.RenewableDispatch),
        :fixed,
        -1.0,
    )
    return
end
