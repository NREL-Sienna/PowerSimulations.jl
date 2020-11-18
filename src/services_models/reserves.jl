abstract type AbstractReservesFormulation <: AbstractServiceFormulation end
struct RangeReserve <: AbstractReservesFormulation end
struct StepwiseCostReserve <: AbstractReservesFormulation end
############################### Reserve Variables` #########################################


############################### ActiveServiceVariable, Reserve #########################################

get_variable_binary(::ActiveServiceVariable, ::Type{<:PSY.Reserve}) = false
get_variable_lower_bound(::ActiveServiceVariable, d::PSY.Reserve, _) = 0.0

############################### ServiceRequirementVariable, ReserveDemandCurve ################################

get_variable_binary(::ServiceRequirementVariable, ::Type{<:PSY.ReserveDemandCurve}) = false
get_variable_lower_bound(::ServiceRequirementVariable, d::PSY.ReserveDemandCurve, _) = 0.0

################################## Reserve Requirement Constraint ##########################
function service_requirement_constraint!(
    psi_container::PSIContainer,
    service::SR,
    ::ServiceModel{SR, T},
) where {SR <: PSY.Reserve, T <: AbstractReservesFormulation}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    initial_time = model_initial_time(psi_container)
    @debug initial_time
    time_steps = model_time_steps(psi_container)
    name = PSY.get_name(service)
    constraint = get_constraint(psi_container, make_constraint_name(REQUIREMENT, SR))
    reserve_variable = get_variable(psi_container, name, SR)
    use_slacks = get_services_slack_variables(psi_container.settings)

    ts_vector = get_time_series(psi_container, service, "requirement")

    use_slacks && (slack_vars = reserve_slacks(psi_container, name))

    requirement = PSY.get_requirement(service)
    if parameters
        param = get_parameter_array(
            psi_container,
            UpdateRef{SR}(SERVICE_REQUIREMENT, "requirement"),
        )
        for t in time_steps
            param[name, t] = PJ.add_parameter(psi_container.JuMPmodel, ts_vector[t])
            if use_slacks
                resource_expression = sum(reserve_variable[:, t]) + slack_vars[t]
            else
                resource_expression = sum(reserve_variable[:, t])
            end
            constraint[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                resource_expression >= param[name, t] * requirement
            )
        end
    else
        for t in time_steps
            constraint[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                sum(reserve_variable[:, t]) >= ts_vector[t] * requirement
            )
        end
    end
    return
end

function service_requirement_constraint!(
    psi_container::PSIContainer,
    service::SR,
    ::ServiceModel{SR, T},
) where {SR <: PSY.StaticReserve, T <: AbstractReservesFormulation}
    parameters = model_has_parameters(psi_container)
    initial_time = model_initial_time(psi_container)
    @debug initial_time
    time_steps = model_time_steps(psi_container)
    name = PSY.get_name(service)
    constraint = get_constraint(psi_container, make_constraint_name(REQUIREMENT, SR))
    reserve_variable = get_variable(psi_container, name, SR)
    use_slacks = get_services_slack_variables(psi_container.settings)

    use_slacks && (slack_vars = reserve_slacks(psi_container, name))

    requirement = PSY.get_requirement(service)
    for t in time_steps
        resource_expression = JuMP.GenericAffExpr{Float64, JuMP.VariableRef}()
        JuMP.add_to_expression!(resource_expression, sum(reserve_variable[:, t]))
        if use_slacks
            resource_expression += slack_vars[t]
        end
        constraint[name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, resource_expression >= requirement)
    end

    return
end

function cost_function!(
    psi_container::PSIContainer,
    service::SR,
    ::ServiceModel{SR, T},
) where {SR <: PSY.Reserve, T <: AbstractReservesFormulation}
    reserve = get_variable(psi_container, PSY.get_name(service), SR)
    for r in reserve
        JuMP.add_to_expression!(psi_container.cost_function, r, DEFAULT_RESERVE_COST)
    end
    return
end

function service_requirement_constraint!(
    psi_container::PSIContainer,
    service::SR,
    ::ServiceModel{SR, StepwiseCostReserve},
) where {SR <: PSY.Reserve}
    initial_time = model_initial_time(psi_container)
    @debug initial_time
    time_steps = model_time_steps(psi_container)
    name = PSY.get_name(service)
    constraint = get_constraint(psi_container, make_constraint_name(REQUIREMENT, SR))
    reserve_variable = get_variable(psi_container, name, SR)
    requirement_variable = get_variable(psi_container, SERVICE_REQUIREMENT, SR)

    for t in time_steps
        constraint[name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            sum(reserve_variable[:, t]) >= requirement_variable[name, t]
        )
    end

    return
end

function AddCostSpec(
    ::Type{T},
    ::Type{StepwiseCostReserve},
    psi_container::PSIContainer,
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
        sos_status = NO_VARIABLE,
    )
end

function add_to_cost!(
    psi_container::PSIContainer,
    spec::AddCostSpec,
    service::SR,
    component_name::String,
) where {SR <: PSY.Reserve}
    time_steps = model_time_steps(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    if !use_forecast_data
        error("StepwiseCostReserve is only supported with forecast")
    end
    variable_cost_forecast = get_time_series(psi_container, service, "variable_cost")
    variable_cost_forecast = map(PSY.VariableCost, variable_cost_forecast)
    for t in time_steps
        variable_cost!(psi_container, spec, component_name, variable_cost_forecast[t], t)
    end
    return
end

function cost_function!(
    psi_container::PSIContainer,
    service::SR,
    model::ServiceModel{SR, StepwiseCostReserve},
) where {SR <: PSY.ReserveDemandCurve}
    spec = AddCostSpec(SR, model.formulation, psi_container)
    @debug SR, spec
    add_to_cost!(psi_container, spec, service, PSY.get_name(service))
    return
end

function modify_device_model!(
    devices_template::Dict{Symbol, DeviceModel},
    service_model::ServiceModel{<:PSY.Reserve, <:AbstractReservesFormulation},
    contributing_devices::Vector{<:PSY.Device},
)
    device_types = unique(typeof.(contributing_devices))
    for dt in device_types
        for (device_model_name, device_model) in devices_template
            # add message here when it exists
            device_model.device_type != dt && continue
            service_model in device_model.services && continue
            push!(device_model.services, service_model)
        end
    end

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
    for (ix, service) in enumerate(services)
        push!(
            constraint_info.additional_terms_ub,
            make_constraint_name(PSY.get_name(service), SR),
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
    for (ix, service) in enumerate(services)
        push!(
            constraint_info.additional_terms_lb,
            make_constraint_name(PSY.get_name(service), SR),
        )
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
        if PSY.has_service(device, service_model.service_type)
            services =
                (s for s in PSY.get_services(device) if isa(s, service_model.service_type))
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
        if PSY.has_service(device, service_model.service_type)
            services =
                (s for s in PSY.get_services(device) if isa(s, service_model.service_type))
            @assert !isempty(services)
            if service_model.service_type <: PSY.Reserve{PSY.ReserveDown}
                for service in services
                    push!(
                        constraint_data_in.additional_terms_ub,
                        make_constraint_name(
                            PSY.get_name(service),
                            service_model.service_type,
                        ),
                    )
                end
            elseif service_model.service_type <: PSY.Reserve{PSY.ReserveUp}
                for service in services
                    push!(
                        constraint_data_out.additional_terms_ub,
                        make_constraint_name(
                            PSY.get_name(service),
                            service_model.service_type,
                        ),
                    )
                end
            end
        end
    end
    return
end
