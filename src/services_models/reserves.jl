#! format: off
############################### Reserve Variables #########################################

get_variable_multiplier(_, ::Type{<:PSY.Reserve}, ::AbstractReservesFormulation) = NaN
############################### ActivePowerReserveVariable, Reserve #########################################

get_variable_binary(::ActivePowerReserveVariable, ::Type{<:PSY.Reserve}, ::AbstractReservesFormulation) = false
get_variable_upper_bound(::ActivePowerReserveVariable, ::PSY.Reserve, d::PSY.Component, _) = PSY.get_max_active_power(d)
get_variable_upper_bound(::ActivePowerReserveVariable, ::PSY.Reserve, d::PSY.Storage, _) =  PSY.get_output_active_power_limits(d).max
get_variable_lower_bound(::ActivePowerReserveVariable, ::PSY.Reserve, ::PSY.Component, _) = 0.0

############################### ActivePowerReserveVariable, ReserveNonSpinning #########################################

get_variable_binary(::ActivePowerReserveVariable, ::Type{<:PSY.ReserveNonSpinning}, ::AbstractReservesFormulation) = false
get_variable_upper_bound(::ActivePowerReserveVariable, ::PSY.ReserveNonSpinning, d::PSY.Component, _) = PSY.get_max_active_power(d)
get_variable_upper_bound(::ActivePowerReserveVariable, ::PSY.ReserveNonSpinning, d::PSY.Storage, _) =  PSY.get_output_active_power_limits(d).max
get_variable_lower_bound(::ActivePowerReserveVariable, ::PSY.ReserveNonSpinning, ::PSY.Component, _) = 0.0


############################### ServiceRequirementVariable, ReserveDemandCurve ################################

get_variable_binary(::ServiceRequirementVariable, ::Type{<:PSY.ReserveDemandCurve}, ::AbstractReservesFormulation) = false
get_variable_upper_bound(::ServiceRequirementVariable, ::PSY.ReserveDemandCurve, d::PSY.Component, ::AbstractReservesFormulation) = PSY.get_max_active_power(d)
get_variable_lower_bound(::ServiceRequirementVariable, ::PSY.ReserveDemandCurve, ::PSY.Component, ::AbstractReservesFormulation) = 0.0

get_multiplier_value(::RequirementTimeSeriesParameter, d::PSY.Reserve, ::AbstractReservesFormulation) = PSY.get_requirement(d)
get_multiplier_value(::RequirementTimeSeriesParameter, d::PSY.ReserveNonSpinning, ::AbstractReservesFormulation) = PSY.get_requirement(d)

get_parameter_multiplier(::VariableValueParameter, d::Type{<:PSY.AbstractReserve}, ::AbstractReservesFormulation) = 1.0
get_initial_parameter_value(::VariableValueParameter, d::Type{<:PSY.AbstractReserve}, ::AbstractReservesFormulation) = 1.0

objective_function_multiplier(::ServiceRequirementVariable, ::StepwiseCostReserve) = 1.0
sos_status(::PSY.ReserveDemandCurve, ::StepwiseCostReserve)=SOSStatusVariable.NO_VARIABLE
uses_compact_power(::PSY.ReserveDemandCurve, ::StepwiseCostReserve)=false
#! format: on

function get_default_time_series_names(
    ::Type{<:PSY.Reserve},
    ::Type{T},
) where {T <: Union{RangeReserve, RampReserve}}
    return Dict{Type{<:TimeSeriesParameter}, String}(
        RequirementTimeSeriesParameter => "requirement",
    )
end

function get_default_time_series_names(
    ::Type{<:PSY.ReserveNonSpinning},
    ::Type{NonSpinningReserve},
)
    return Dict{Type{<:TimeSeriesParameter}, String}(
        RequirementTimeSeriesParameter => "requirement",
    )
end

function get_default_time_series_names(
    ::Type{<:PSY.Service},
    ::Type{<:AbstractServiceFormulation},
)
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

function get_default_attributes(::Type{<:PSY.Service}, ::Type{<:AbstractServiceFormulation})
    return Dict{String, Any}()
end

################################## Reserve Requirement Constraint ##########################
function add_constraints!(
    container::OptimizationContainer,
    T::Type{RequirementConstraint},
    service::SR,
    ::U,
    model::ServiceModel{SR, V},
) where {
    SR <: PSY.AbstractReserve,
    V <: AbstractReservesFormulation,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.Component}
    parameters = built_for_recurrent_solves(container)
    initial_time = get_initial_time(container)

    time_steps = get_time_steps(container)
    service_name = PSY.get_name(service)
    # TODO: Add a method for services that handles this better
    constraint = add_constraints_container!(
        container,
        T(),
        SR,
        [service_name],
        time_steps;
        meta=service_name,
    )
    reserve_variable =
        get_variable(container, ActivePowerReserveVariable(), SR, service_name)
    use_slacks = get_use_slacks(model)

    ts_vector = get_time_series(container, service, "requirement")

    use_slacks && (slack_vars = reserve_slacks(container, service))
    requirement = PSY.get_requirement(service)
    jump_model = get_jump_model(container)
    if parameters
        container =
            get_parameter(container, RequirementTimeSeriesParameter(), SR, service_name)
        param = get_parameter_array(container)
        for t in time_steps
            if use_slacks
                resource_expression = sum(reserve_variable[:, t]) + slack_vars[t]
            else
                resource_expression = sum(reserve_variable[:, t])
            end
            constraint[service_name, t] = JuMP.@constraint(
                jump_model,
                resource_expression >= param[service_name, t] * requirement
            )
        end
    else
        for t in time_steps
            if use_slacks
                resource_expression = sum(reserve_variable[:, t]) + slack_vars[t]
            else
                resource_expression = sum(reserve_variable[:, t])
            end
            constraint[service_name, t] = JuMP.@constraint(
                jump_model,
                resource_expression >= ts_vector[t] * requirement
            )
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{RequirementConstraint},
    service::SR,
    ::U,
    model::ServiceModel{SR, V},
) where {
    SR <: PSY.StaticReserve,
    V <: AbstractReservesFormulation,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.Component}
    time_steps = get_time_steps(container)
    service_name = PSY.get_name(service)
    # TODO: The constraint addition is still not clean enough
    constraint = add_constraints_container!(
        container,
        T(),
        SR,
        [service_name],
        time_steps;
        meta=service_name,
    )
    reserve_variable =
        get_variable(container, ActivePowerReserveVariable(), SR, service_name)
    use_slacks = get_use_slacks(model)
    use_slacks && (slack_vars = reserve_slacks(container, service))

    requirement = PSY.get_requirement(service)
    jump_model = get_jump_model(container)
    for t in time_steps
        resource_expression = JuMP.GenericAffExpr{Float64, JuMP.VariableRef}()
        JuMP.add_to_expression!(resource_expression, sum(reserve_variable[:, t]))
        if use_slacks
            resource_expression += slack_vars[t]
        end
        constraint[service_name, t] =
            JuMP.@constraint(jump_model, resource_expression >= requirement)
    end

    return
end

function objective_function!(
    container::OptimizationContainer,
    service::SR,
    ::ServiceModel{SR, T},
) where {SR <: PSY.AbstractReserve, T <: AbstractReservesFormulation}
    add_proportional_cost!(container, ActivePowerReserveVariable(), service, T())
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{RequirementConstraint},
    service::SR,
    ::U,
    ::ServiceModel{SR, StepwiseCostReserve},
) where {
    SR <: PSY.ReserveDemandCurve,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.Component}
    time_steps = get_time_steps(container)
    service_name = PSY.get_name(service)
    constraint = add_constraints_container!(
        container,
        T(),
        SR,
        [service_name],
        time_steps;
        meta=service_name,
    )
    reserve_variable =
        get_variable(container, ActivePowerReserveVariable(), SR, service_name)
    requirement_variable = get_variable(container, ServiceRequirementVariable(), SR)
    jump_model = get_jump_model(container)
    for t in time_steps
        constraint[service_name, t] = JuMP.@constraint(
            jump_model,
            sum(reserve_variable[:, t]) >= requirement_variable[service_name, t]
        )
    end

    return
end

_get_ramp_limits(::PSY.Component) = nothing
_get_ramp_limits(d::PSY.ThermalGen) = PSY.get_ramp_limits(d)
_get_ramp_limits(d::PSY.HydroGen) = PSY.get_ramp_limits(d)

function _get_ramp_constraint_contributing_devices(
    service::PSY.Reserve,
    contributing_devices::Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
) where {D <: PSY.Component}
    time_frame = PSY.get_time_frame(service)
    filtered_device = Vector{D}()
    for d in contributing_devices
        ramp_limits = _get_ramp_limits(d)
        if ramp_limits !== nothing
            p_lims = PSY.get_active_power_limits(d)
            max_rate = abs(p_lims.min - p_lims.max) / time_frame
            if (ramp_limits.up >= max_rate) & (ramp_limits.down >= max_rate)
                @debug "Generator $(name) has a nonbinding ramp limits. Constraints Skipped"
                continue
            else
                push!(filtered_device, d)
            end
        end
    end
    return filtered_device
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{RampConstraint},
    service::SR,
    contributing_devices::Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    ::ServiceModel{SR, V},
) where {
    SR <: PSY.Reserve{PSY.ReserveUp},
    V <: AbstractReservesFormulation,
    D <: PSY.Component,
}
    ramp_devices = _get_ramp_constraint_contributing_devices(service, contributing_devices)
    service_name = PSY.get_name(service)
    if !isempty(ramp_devices)
        jump_model = get_jump_model(container)
        time_steps = get_time_steps(container)
        time_frame = PSY.get_time_frame(service)
        variable = get_variable(container, ActivePowerReserveVariable(), SR, service_name)
        set_name = [PSY.get_name(d) for d in ramp_devices]
        con_up = add_constraints_container!(
            container,
            T(),
            SR,
            set_name,
            time_steps;
            meta=service_name,
        )
        for d in ramp_devices, t in time_steps
            name = PSY.get_name(d)
            ramp_limits = PSY.get_ramp_limits(d)
            con_up[name, t] = JuMP.@constraint(
                jump_model,
                variable[name, t] <= ramp_limits.up * time_frame
            )
        end
    else
        @warn "Data doesn't contain contributing devices with ramp limits for service $service_name, consider adjusting your formulation"
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{RampConstraint},
    service::SR,
    contributing_devices::Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    ::ServiceModel{SR, V},
) where {
    SR <: PSY.Reserve{PSY.ReserveDown},
    V <: AbstractReservesFormulation,
    D <: PSY.Component,
}
    ramp_devices = _get_ramp_constraint_contributing_devices(service, contributing_devices)
    service_name = PSY.get_name(service)
    if !isempty(ramp_devices)
        jump_model = get_jump_model(container)
        time_steps = get_time_steps(container)
        time_frame = PSY.get_time_frame(service)
        variable = get_variable(container, ActivePowerReserveVariable(), SR, service_name)
        set_name = [PSY.get_name(d) for d in ramp_devices]
        con_down = add_constraints_container!(
            container,
            T(),
            SR,
            set_name,
            time_steps;
            meta=service_name,
        )
        for d in ramp_devices, t in time_steps
            name = PSY.get_name(d)
            ramp_limits = PSY.get_ramp_limits(d)
            con_down[name, t] = JuMP.@constraint(
                jump_model,
                variable[name, t] <= ramp_limits.down * time_frame
            )
        end
    else
        @warn "Data doesn't contain contributing devices with ramp limits for service $service_name, consider adjusting your formulation"
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{ReservePowerConstraint},
    service::SR,
    contributing_devices::U,
    ::ServiceModel{SR, V},
) where {
    SR <: PSY.VariableReserveNonSpinning,
    V <: AbstractReservesFormulation,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.Component}
    time_steps = get_time_steps(container)
    resolution = get_resolution(container)
    if resolution > Dates.Minute(1)
        minutes_per_period = Dates.value(Dates.Minute(resolution))
    else
        @warn("Not all formulations support under 1-minute resolutions. Exercise caution.")
        minutes_per_period = Dates.value(Dates.Second(resolution)) / 60
    end
    service_name = PSY.get_name(service)
    cons = add_constraints_container!(
        container,
        T(),
        SR,
        [PSY.get_name(d) for d in contributing_devices],
        time_steps;
        meta=service_name,
    )
    var_r = get_variable(container, ActivePowerReserveVariable(), SR, service_name)
    reserve_response_time = PSY.get_time_frame(service)
    jump_model = get_jump_model(container)
    for d in contributing_devices
        component_type = typeof(d)
        name = PSY.get_name(d)
        varstatus = get_variable(container, OnVariable(), component_type)
        startup_time = PSY.get_time_limits(d).up
        ramp_limits = _get_ramp_limits(d)
        if reserve_response_time > startup_time
            reserve_limit =
                PSY.get_active_power_limits(d).min +
                (reserve_response_time - startup_time) * minutes_per_period * ramp_limits.up
        else
            reserve_limit = 0
        end
        for t in time_steps
            cons[name, t] = JuMP.@constraint(
                jump_model,
                var_r[name, t] <= (1 - varstatus[name, t]) * reserve_limit
            )
        end
    end
    return
end

function objective_function!(
    container::OptimizationContainer,
    service::PSY.ReserveDemandCurve{T},
    ::ServiceModel{PSY.ReserveDemandCurve{T}, SR},
) where {T <: PSY.ReserveDirection, SR <: StepwiseCostReserve}
    add_variable_cost!(container, ServiceRequirementVariable(), service, SR())
    return
end

function add_services_to_device_model!(template)
    service_models = get_service_models(template)
    devices_template = get_device_models(template)
    for (service_key, service_model) in service_models
        S = get_component_type(service_model)
        (S <: PSY.AGC || S <: PSY.StaticReserveGroup) && continue
        contributing_devices = get_contributing_devices(service_model)
        isempty(contributing_devices) && continue
        modify_device_model!(devices_template, service_model, contributing_devices)
    end
    return
end

function modify_device_model!(
    devices_template::Dict{Symbol, DeviceModel},
    service_model::ServiceModel{<:PSY.Reserve, <:AbstractReservesFormulation},
    contributing_devices::Vector{<:PSY.Component},
)
    for dt in unique(typeof.(contributing_devices))
        for device_model in values(devices_template)
            # add message here when it exists
            get_component_type(device_model) != dt && continue
            service_model in device_model.services && continue
            push!(device_model.services, service_model)
        end
    end

    return
end

function modify_device_model!(
    devices_template::Dict{Symbol, DeviceModel},
    service_model::ServiceModel{<:PSY.ReserveNonSpinning, <:AbstractReservesFormulation},
    contributing_devices::Vector{<:PSY.Component},
)
    return
end
