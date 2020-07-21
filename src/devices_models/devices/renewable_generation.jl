abstract type AbstractRenewableFormulation <: AbstractDeviceFormulation end
abstract type AbstractRenewableDispatchFormulation <: AbstractRenewableFormulation end
struct RenewableFullDispatch <: AbstractRenewableDispatchFormulation end
struct RenewableConstantPowerFactor <: AbstractRenewableDispatchFormulation end

########################### renewable generation variables #################################
function AddVariableSpec(
    ::Type{T},
    ::Type{U},
    ::PSIContainer,
) where {T <: ActivePowerVariable, U <: PSY.RenewableGen}
    return AddVariableSpec(;
        variable_name = make_variable_name(T, U),
        binary = false,
        expression_name = :nodal_balance_active,
        lb_value_func = x -> 0.0,
        ub_value_func = x -> PSY.get_max_active_power(x),
    )
end

function AddVariableSpec(
    ::Type{T},
    ::Type{U},
    ::PSIContainer,
) where {T <: ReactivePowerVariable, U <: PSY.RenewableGen}
    return AddVariableSpec(;
        variable_name = make_variable_name(T, U),
        binary = false,
        expression_name = :nodal_balance_reactive,
    )
end

####################################### Reactive Power constraint_infos #########################
function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractDeviceFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.RenewableGen}
    return DeviceRangeConstraintSpec(;
        range_constraint_spec = RangeConstraintSpec(;
            constraint_name = make_constraint_name(
                RangeConstraint,
                ReactivePowerVariable,
                T,
            ),
            variable_name = make_variable_name(ReactivePowerVariable, T),
            limits_func = x -> PSY.get_reactive_power_limits(x),
            constraint_func = device_range,
            constraint_struct = DeviceRangeConstraintInfo,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::Type{<:RenewableConstantPowerFactor},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.RenewableGen}
    return DeviceRangeConstraintSpec(;
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
        pf = sin(acos(PSY.get_power_factor(d)))
        constraint_val[name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, q_var[name, t] == p_var[name, t] * pf)
    end
    return
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:AbstractRenewableDispatchFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.RenewableGen}
    if !use_parameters && !use_forecasts
        return DeviceRangeConstraintSpec(;
            range_constraint_spec = RangeConstraintSpec(;
                constraint_name = make_constraint_name(
                    RangeConstraint,
                    ActivePowerVariable,
                    T,
                ),
                variable_name = make_variable_name(ActivePowerVariable, T),
                limits_func = x -> (min = 0.0, max = PSY.get_active_power(x)),
                constraint_func = device_range,
                constraint_struct = DeviceRangeConstraintInfo,
            ),
        )
    end

    return DeviceRangeConstraintSpec(;
        timeseries_range_constraint_spec = TimeSeriesConstraintSpec(;
            constraint_name = make_constraint_name(RangeConstraint, ActivePowerVariable, T),
            variable_name = make_variable_name(ActivePowerVariable, T),
            parameter_name = use_parameters ? ACTIVE_POWER : nothing,
            forecast_label = "get_max_active_power",
            multiplier_func = x -> PSY.get_max_active_power(x),
            constraint_func = use_parameters ? device_timeseries_param_ub! :
                              device_timeseries_ub!,
        ),
    )
end

########################## Addition to the nodal balances ##################################

function NodalExpressionSpec(
    ::Type{T},
    ::Type{<:PM.AbstractPowerModel},
    use_forecasts::Bool,
) where {T <: PSY.RenewableGen}
    return NodalExpressionSpec(
        "get_max_active_power",
        REACTIVE_POWER,
        use_forecasts ? x -> PSY.get_max_reactive_power(x) :
        x -> PSY.get_reactive_power(x),
        1.0,
        T,
    )
end

function NodalExpressionSpec(
    ::Type{T},
    ::Type{<:PM.AbstractActivePowerModel},
    use_forecasts::Bool,
) where {T <: PSY.RenewableGen}
    return NodalExpressionSpec(
        "get_max_active_power",
        ACTIVE_POWER,
        use_forecasts ? x -> PSY.get_max_active_power(x) :
        x -> PSY.get_active_power(x),
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
    add_to_cost!(
        psi_container,
        devices,
        make_variable_name(ACTIVE_POWER, PSY.RenewableDispatch),
        :fixed,
        -1.0,
    )
    return
end
