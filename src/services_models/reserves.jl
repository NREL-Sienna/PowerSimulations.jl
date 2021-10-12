#! format: off
struct RangeReserve <: AbstractReservesFormulation end
struct StepwiseCostReserve <: AbstractReservesFormulation end
struct RampReserve <: AbstractReservesFormulation end
struct NonSpinningReserve <: AbstractReservesFormulation end
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
    contributing_devices::U,
    model::ServiceModel{SR, V},
) where {
    SR <: PSY.AbstractReserve,
    V <: AbstractReservesFormulation,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.Component}
    parameters = built_for_recurrent_solves(container)
    initial_time = get_initial_time(container)
    @debug initial_time
    time_steps = get_time_steps(container)
    names = [PSY.get_name(s) for s in [service]]
    name = PSY.get_name(service)
    constraint = add_cons_container!(container, T(), SR, names, time_steps; meta = name)
    reserve_variable = get_variable(container, ActivePowerReserveVariable(), SR, name)
    use_slacks = get_use_slacks(model)

    ts_vector = get_time_series(container, service, "requirement")

    use_slacks && (slack_vars = reserve_slacks(container, service))

    requirement = PSY.get_requirement(service)
    if parameters
        container =
            get_parameter(container, RequirementTimeSeriesParameter(), SR; meta = name)
        param = get_parameter_array(container)
        multiplier = get_multiplier_array(container)
        for t in time_steps
            if use_slacks
                resource_expression = sum(reserve_variable[:, t]) + slack_vars[t]
            else
                resource_expression = sum(reserve_variable[:, t])
            end
            constraint[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                resource_expression >= param[name, t] * requirement
            )
        end
    else
        for t in time_steps
            if use_slacks
                resource_expression = sum(reserve_variable[:, t]) + slack_vars[t]
            else
                resource_expression = sum(reserve_variable[:, t])
            end
            constraint[name, t] = JuMP.@constraint(
                container.JuMPmodel,
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
    contributing_devices::U,
    model::ServiceModel{SR, V},
) where {
    SR <: PSY.StaticReserve,
    V <: AbstractReservesFormulation,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.Component}
    initial_time = get_initial_time(container)
    @debug initial_time
    time_steps = get_time_steps(container)
    names = [PSY.get_name(s) for s in [service]]
    name = PSY.get_name(service)
    constraint = add_cons_container!(container, T(), SR, names, time_steps; meta = name)
    reserve_variable = get_variable(container, ActivePowerReserveVariable(), SR, name)
    use_slacks = get_use_slacks(model)
    use_slacks && (slack_vars = reserve_slacks(container, service))

    requirement = PSY.get_requirement(service)
    for t in time_steps
        resource_expression = JuMP.GenericAffExpr{Float64, JuMP.VariableRef}()
        JuMP.add_to_expression!(resource_expression, sum(reserve_variable[:, t]))
        if use_slacks
            resource_expression += slack_vars[t]
        end
        constraint[name, t] =
            JuMP.@constraint(container.JuMPmodel, resource_expression >= requirement)
    end

    return
end

function cost_function!(
    container::OptimizationContainer,
    service::SR,
    ::ServiceModel{SR, T},
) where {SR <: PSY.AbstractReserve, T <: AbstractReservesFormulation}
    reserve =
        get_variable(container, ActivePowerReserveVariable(), SR, PSY.get_name(service))
    for r in reserve
        JuMP.add_to_expression!(container.cost_function, r, DEFAULT_RESERVE_COST)
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{RequirementConstraint},
    service::SR,
    contributing_devices::U,
    model::ServiceModel{SR, StepwiseCostReserve},
) where {
    SR <: PSY.ReserveDemandCurve,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.Component}
    initial_time = get_initial_time(container)
    @debug initial_time
    time_steps = get_time_steps(container)
    names = [PSY.get_name(s) for s in [service]]
    name = PSY.get_name(service)
    constraint = add_cons_container!(container, T(), SR, names, time_steps; meta = name)
    reserve_variable = get_variable(container, ActivePowerReserveVariable(), SR, name)
    requirement_variable = get_variable(container, ServiceRequirementVariable(), SR)

    for t in time_steps
        constraint[name, t] = JuMP.@constraint(
            container.JuMPmodel,
            sum(reserve_variable[:, t]) >= requirement_variable[name, t]
        )
    end

    return
end

_get_ramp_limits(::PSY.Component) = nothing
_get_ramp_limits(d::PSY.ThermalGen) = PSY.get_ramp_limits(d)
_get_ramp_limits(d::PSY.HydroGen) = PSY.get_ramp_limits(d)

function _get_data_for_ramp_limit(
    container::OptimizationContainer,
    service::SR,
    contributing_devices::U,
) where {
    SR <: PSY.Reserve,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.Component}
    time_frame = PSY.get_time_frame(service)
    resolution = get_resolution(container)
    if resolution > Dates.Minute(1)
        minutes_per_period = Dates.value(Dates.Minute(resolution))
    else
        @warn("Not all formulations support under 1-minute resolutions. Exercise caution.")
        minutes_per_period = Dates.value(Dates.Second(resolution)) / 60
    end
    lenght_contributing_devices = length(contributing_devices)
    idx = 0
    data = Vector{ServiceRampConstraintInfo}(undef, lenght_contributing_devices)

    for d in contributing_devices
        name = PSY.get_name(d)
        ramp_limits = _get_ramp_limits(d)
        if !(ramp_limits === nothing)
            p_lims = PSY.get_active_power_limits(d)
            max_rate = abs(p_lims.min - p_lims.max) / time_frame
            if (ramp_limits.up >= max_rate) & (ramp_limits.down >= max_rate)
                @debug "Generator $(name) has a nonbinding ramp limits. Constraints Skipped"
                continue
            else
                idx += 1
            end
            ramp = (up = ramp_limits.up * time_frame, down = ramp_limits.down * time_frame)
            data[idx] = ServiceRampConstraintInfo(name, ramp)
        end
    end
    if idx < lenght_contributing_devices
        deleteat!(data, (idx + 1):lenght_contributing_devices)
    end
    return data
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{RampConstraint},
    service::SR,
    contributing_devices::U,
    model::ServiceModel{SR, V},
) where {
    SR <: PSY.Reserve{PSY.ReserveUp},
    V <: AbstractReservesFormulation,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.Component}
    rate_data = _get_data_for_ramp_limit(container, service, contributing_devices)
    service_name = PSY.get_name(service)
    if !isempty(rate_data)
        time_steps = get_time_steps(container)
        variable = get_variable(container, ActivePowerReserveVariable(), SR, service_name)
        set_name = [get_component_name(r) for r in rate_data]
        con_up = add_cons_container!(
            container,
            T(),
            SR,
            set_name,
            time_steps,
            meta = service_name,
        )
        for r in rate_data, t in time_steps
            name = get_component_name(r)
            con_up[name, t] =
                JuMP.@constraint(container.JuMPmodel, variable[name, t] <= r.ramp_limits.up)
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
    contributing_devices::U,
    model::ServiceModel{SR, V},
) where {
    SR <: PSY.Reserve{PSY.ReserveDown},
    V <: AbstractReservesFormulation,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.Component}
    rate_data = _get_data_for_ramp_limit(container, service, contributing_devices)
    service_name = PSY.get_name(service)
    if !isempty(rate_data)
        time_steps = get_time_steps(container)
        variable = get_variable(container, ActivePowerReserveVariable(), SR, service_name)
        set_name = [get_component_name(r) for r in rate_data]
        con_down = add_cons_container!(
            container,
            T(),
            SR,
            set_name,
            time_steps,
            meta = service_name,
        )
        for r in rate_data, t in time_steps
            name = get_component_name(r)
            con_down[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                variable[name, t] <= r.ramp_limits.down
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
    constraint_type = T()
    resolution = get_resolution(container)
    if resolution > Dates.Minute(1)
        minutes_per_period = Dates.value(Dates.Minute(resolution))
    else
        @warn("Not all formulations support under 1-minute resolutions. Exercise caution.")
        minutes_per_period = Dates.value(Dates.Second(resolution)) / 60
    end

    cons = add_cons_container!(
        container,
        constraint_type,
        SR,
        [PSY.get_name(d) for d in contributing_devices],
        time_steps,
    )
    var_r = get_variable(container, ActivePowerReserveVariable(), SR, PSY.get_name(service))
    reserve_response_time = PSY.get_time_frame(service)
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
                container.JuMPmodel,
                var_r[name, t] <= (1 - varstatus[name, t]) * reserve_limit
            )
        end
    end
    return
end

function AddCostSpec(
    ::Type{T},
    ::Type{StepwiseCostReserve},
    container::OptimizationContainer,
) where {T <: PSY.Reserve}
    return AddCostSpec(;
        variable_type = ServiceRequirementVariable,
        component_type = T,
        has_status_variable = false,
        has_status_parameter = false,
        variable_cost = PSY.get_variable,
        start_up_cost = nothing,
        shut_down_cost = nothing,
        fixed_cost = nothing,
        sos_status = SOSStatusVariable.NO_VARIABLE,
    )
end

function add_to_cost!(
    container::OptimizationContainer,
    spec::AddCostSpec,
    service::SR,
    component_name::String,
) where {SR <: PSY.Reserve}
    time_steps = get_time_steps(container)
    variable_cost_forecast = get_time_series(container, service, "variable_cost")
    variable_cost_forecast = map(PSY.VariableCost, variable_cost_forecast)
    for t in time_steps
        variable_cost!(container, spec, component_name, variable_cost_forecast[t], t)
    end
    return
end

function cost_function!(
    container::OptimizationContainer,
    service::SR,
    model::ServiceModel{SR, StepwiseCostReserve},
) where {SR <: PSY.ReserveDemandCurve}
    spec = AddCostSpec(SR, get_formulation(model), container)
    @debug SR, spec
    add_to_cost!(container, spec, service, PSY.get_name(service))
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
    device_types = unique(typeof.(contributing_devices))
    for dt in device_types
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

function include_service!(
    constraint_info::T,
    services,
    ::ServiceModel{SR, <:AbstractReservesFormulation},
) where {
    T <: Union{AbstractRangeConstraintInfo, AbstractRampConstraintInfo},
    SR <: PSY.Reserve{PSY.ReserveUp},
}
    for service in services
        push!(
            constraint_info.additional_terms_ub,
            VariableKey(ActivePowerReserveVariable, SR, PSY.get_name(service)),
        )
    end
    return
end

function include_service!(
    constraint_info::T,
    services,
    ::ServiceModel{SR, <:AbstractReservesFormulation},
) where {
    T <: Union{AbstractRangeConstraintInfo, AbstractRampConstraintInfo},
    SR <: PSY.Reserve{PSY.ReserveDown},
}
    for service in services
        push!(
            constraint_info.additional_terms_lb,
            VariableKey(ActivePowerReserveVariable, SR, PSY.get_name(service)),
        )
    end
    return
end

function include_service!(
    ::T,
    services,
    ::ServiceModel{SR, RampReserve},
) where {T <: AbstractRampConstraintInfo, SR <: PSY.Reserve{PSY.ReserveDown}}
    return
end

function include_service!(
    constraint_info::ReserveRangeConstraintInfo,
    services,
    ::ServiceModel{SR, RampReserve},
) where {SR <: PSY.Reserve{PSY.ReserveUp}}
    for service in services
        key = VariableKey(ActivePowerReserveVariable, SR, get_name(service))
        push!(constraint_info.additional_terms_up, key)
        set_time_frame!(constraint_info, (key => PSY.get_time_frame(service)))
    end
    return
end

function include_service!(
    constraint_info::ReserveRangeConstraintInfo,
    services,
    ::ServiceModel{SR, RampReserve},
) where {SR <: PSY.Reserve{PSY.ReserveDown}}
    for service in services
        key = VariableKey(ActivePowerReserveVariable, SR, PSY.get_name(service))
        push!(constraint_info.additional_terms_dn, key)
        set_time_frame!(constraint_info, (key => PSY.get_time_frame(service)))
    end
    return
end

function add_device_services!(
    constraint_info::T,
    device::D,
    model::DeviceModel,
) where {
    T <: Union{AbstractRangeConstraintInfo, AbstractRampConstraintInfo},
    D <: PSY.Device,
}
    for service_model in get_services(model)
        service_type = get_component_type(service_model)
        if PSY.has_service(device, service_type)
            services = (s for s in PSY.get_services(device) if isa(s, service_type))
            @assert !isempty(services)
            include_service!(constraint_info, services, service_model)
        end
    end
    return
end

function add_device_services!(
    constraint_info::T,
    device::D,
    model::DeviceModel{D, BatteryAncillaryServices},
) where {
    T <: Union{AbstractRangeConstraintInfo, AbstractRampConstraintInfo},
    D <: PSY.Storage,
}
    return
end

function add_device_services!(
    constraint_info::ReserveRangeConstraintInfo,
    device::D,
    model::DeviceModel{D, BatteryAncillaryServices},
) where {D <: PSY.Storage}
    for service_model in get_services(model)
        service_type = get_component_type(service_model)
        if PSY.has_service(device, service_type)
            services = (s for s in PSY.get_services(device) if isa(s, service_type))
            @assert !isempty(services)
            include_service!(constraint_info, services, service_model)
        end
    end
    return
end

function add_device_services!(
    constraint_data_in::AbstractRangeConstraintInfo,
    constraint_data_out::AbstractRangeConstraintInfo,
    device::D,
    model::DeviceModel{D, <:AbstractStorageFormulation},
) where {D <: PSY.Storage}
    for service_model in get_services(model)
        service_type = get_component_type(service_model)
        if PSY.has_service(device)
            services = (s for s in PSY.get_services(device) if isa(s, service_type))
            @assert !isempty(services)
            if service_type <: PSY.Reserve{PSY.ReserveDown}
                for service in services
                    push!(
                        constraint_data_in.additional_terms_ub,
                        VariableKey(
                            ActivePowerReserveVariable,
                            service_type,
                            PSY.get_name(service),
                        ),
                    )
                end
            elseif service_type <: PSY.Reserve{PSY.ReserveUp}
                for service in services
                    push!(
                        constraint_data_out.additional_terms_ub,
                        VariableKey(
                            ActivePowerReserveVariable,
                            service_type,
                            PSY.get_name(service),
                        ),
                    )
                end
            end
        end
    end
    return
end
