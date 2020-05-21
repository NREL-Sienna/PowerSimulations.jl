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
function reactivepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{R},
    model::DeviceModel{R, RenewableFullDispatch},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {R <: PSY.RenewableGen}
    constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        if isnothing(PSY.get_reactivepowerlimits(d))
            lims = (min = 0.0, max = 0.0)
            @warn("Reactive Power Limits of $(lims) are nothing. Q_$(lims) is set to 0.0")
        else
            lims = PSY.get_reactivepowerlimits(d)
        end
        constraint_infos[ix] = DeviceRangeConstraintInfo(name, lims)
    end
    device_range(
        psi_container,
        RangeConstraintInputs(
            constraint_infos,
            constraint_name(REACTIVE_RANGE, R),
            variable_name(REACTIVE_POWER, R),
        ),
    )
    return
end

function reactivepower_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{R},
    model::DeviceModel{R, RenewableConstantPowerFactor},
    system_formulation::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {R <: PSY.RenewableGen}
    names = (PSY.get_name(d) for d in devices)
    time_steps = model_time_steps(psi_container)
    p_var = get_variable(psi_container, ACTIVE_POWER, R)
    q_var = get_variable(psi_container, REACTIVE_POWER, R)
    constraint_val = JuMPConstraintArray(undef, names, time_steps)
    assign_constraint!(psi_container, REACTIVE_RANGE, R, constraint_val)
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(acos(PSY.get_powerfactor(d)))
        constraint_val[name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, q_var[name, t] == p_var[name, t] * pf)
    end
    return
end

function ActivePowerConstraintsInputs(
    ::Type{T},
    ::Type{U},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.RenewableGen, U <: AbstractRenewableDispatchFormulation}
    return ActivePowerConstraintsInputs(;
        limits = x -> (min = 0.0, max = PSY.get_activepower(x)),
        range_constraint = device_range,
        multiplier = x -> PSY.get_rating(x),
        timeseries_func = use_parameters ? device_timeseries_param_ub :
                          device_timeseries_ub,
        parameter_name = use_parameters ? ACTIVE_POWER : nothing,
        constraint_name = use_forecasts ? ACTIVE : ACTIVE_RANGE,
        variable_name = ACTIVE_POWER,
        bin_variable_name = nothing,
        forecast_label = "get_rating",
    )
end

########################## Addition to the nodal balances ##################################

function NodalExpressionInputs(
    ::Type{<:PSY.RenewableGen},
    ::Type{<:PM.AbstractPowerModel},
    use_forecasts::Bool,
)
    return NodalExpressionInputs(
        "get_rating",
        REACTIVE_POWER,
        use_forecasts ? x -> PSY.get_rating(x) * sin(acos(PSY.get_powerfactor(x))) :
        x -> PSY.get_reactivepower(x),
        1.0,
    )
end

function NodalExpressionInputs(
    ::Type{<:PSY.RenewableGen},
    ::Type{<:PM.AbstractActivePowerModel},
    use_forecasts::Bool,
)
    return NodalExpressionInputs(
        "get_rating",
        ACTIVE_POWER,
        use_forecasts ? x -> PSY.get_rating(x) * PSY.get_powerfactor(x) :
        x -> PSY.get_activepower(x),
        1.0,
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
