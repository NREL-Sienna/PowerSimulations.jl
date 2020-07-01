abstract type AbstractReservesFormulation <: AbstractServiceFormulation end
struct RangeReserve <: AbstractReservesFormulation end
struct StepwiseCostReserve <: AbstractReservesFormulation end
############################### Reserve Variables` #########################################
"""
This function add the variables for reserves to the model
"""
function activeservice_variables!(
    psi_container::PSIContainer,
    service::SR,
    contributing_devices::Vector{<:PSY.Device},
) where {SR <: PSY.Reserve}
    add_variable(
        psi_container,
        [device for device ∈ contributing_devices if PSY.get_available(device)],
        variable_name(PSY.get_name(service), SR),
        false;
        lb_value = d -> 0,
    )
    return
end

function activerequirement_variables!(
    psi_container::PSIContainer,
    services::IS.FlattenIteratorWrapper{PSY.ReserveDemandCurve{D}},
) where {D <: PSY.ReserveDirection}
    add_variable(
        psi_container,
        services,
        variable_name(SERVICE_REQUIREMENT, PSY.ReserveDemandCurve{D}),
        false;
        lb_value = x -> 0.0,
    )
    return
end

################################## Reserve Requirement Constraint ##########################
# This function can be generalized later for any constraint of type Sum(req_var) >= requirement,
# it will only need to be specific to the names and get forecast string.
function service_requirement_constraint!(
    psi_container::PSIContainer,
    service::SR,
    ::ServiceModel{SR, RangeReserve},
) where {SR <: PSY.Reserve}
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    initial_time = model_initial_time(psi_container)
    @debug initial_time
    time_steps = model_time_steps(psi_container)
    name = PSY.get_name(service)
    constraint = get_constraint(psi_container, constraint_name(REQUIREMENT, SR))
    reserve_variable = get_variable(psi_container, variable_name(name, SR))
    use_slacks = get_services_slack_variables(psi_container.settings)

    if use_forecast_data
        ts_vector = TS.values(PSY.get_data(PSY.get_forecast(
            PSY.Deterministic,
            service,
            initial_time,
            "get_requirement",
            length(time_steps),
        )))
    else
        ts_vector = ones(time_steps[end])
    end

    use_slacks && (slack_vars = reserve_slacks(psi_container, name))

    requirement = PSY.get_requirement(service)
    if parameters
        param = get_parameter_array(
            psi_container,
            UpdateRef{SR}(SERVICE_REQUIREMENT, "get_requirement"),
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

function cost_function!(
    psi_container::PSIContainer,
    service::SR,
    ::ServiceModel{SR, RangeReserve},
) where {SR <: PSY.Reserve}
    reserve = get_variable(psi_container, variable_name(PSY.get_name(service), SR))
    for r in reserve
        JuMP.add_to_expression!(psi_container.cost_function, r, 1.0)
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
    constraint = get_constraint(psi_container, constraint_name(REQUIREMENT, SR))
    reserve_variable = get_variable(psi_container, variable_name(name, SR))
    requirement_variable =
        get_variable(psi_container, variable_name(SERVICE_REQUIREMENT, SR))

    for t in time_steps
        constraint[name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            sum(reserve_variable[:, t]) >= requirement_variable[name, t]
        )
    end

    return
end

function cost_function!(
    psi_container::PSIContainer,
    service::SR,
    ::Type{StepwiseCostReserve},
) where {SR <: PSY.Reserve}

    use_forecast_data = model_uses_forecasts(psi_container)
    initial_time = model_initial_time(psi_container)
    @debug initial_time
    time_steps = model_time_steps(psi_container)

    function pwl_reserve_cost(
        psi_container::PSIContainer,
        variable::JV,
        cost_component::Vector{NTuple{2, Float64}},
    ) where {JV <: JuMP.AbstractVariableRef}
        return _pwlgencost_sos(psi_container, variable, cost_component)
    end

    if use_forecast_data
        ts_vector = _convert_to_variablecost(PSY.get_data(PSY.get_forecast(
            PSY.PiecewiseFunction,
            service,
            initial_time,
            "get_variable",
            length(time_steps),
        )))

    else
        ts_vector = repeat(PSY.get_variable(PSY.get_op_cost(service)), time_steps[end])
    end

    resolution = model_resolution(psi_container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    variable = get_variable(psi_container, variable_name(SERVICE_REQUIREMENT, SR))
    gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(psi_container)}()
    time_steps = model_time_steps(psi_container)
    name = PSY.get_name(service)
    container = add_var_container!(
        psi_container,
        variable_name("$(name)_pwl_cost_vars", SR),
        [name],
        time_steps,
        1:length(ts_vector[1]);
        sparse = true,
    )
    for (t, var) in enumerate(variable[name, :])
        c, pwlvars = pwl_reserve_cost(psi_container, var, ts_vector[t])
        for (ix, v) in enumerate(pwlvars)
            container[(name, t, ix)] = v
        end
        JuMP.add_to_expression!(gen_cost, c)
    end

    cost_expression = gen_cost * dt
    T_ce = typeof(cost_expression)
    T_cf = typeof(psi_container.cost_function)
    if T_cf <: JuMP.GenericAffExpr && T_ce <: JuMP.GenericQuadExpr
        psi_container.cost_function += cost_expression
    else
        JuMP.add_to_expression!(psi_container.cost_function, cost_expression)
    end
    return
end

function _convert_to_variablecost(val::TS.TimeArray)
    cost_col = Vector{Symbol}()
    load_col = Vector{Symbol}()
    variable_costs = Vector{Array{NTuple{2, Float64}}}()
    col_names = TS.colnames(val)
    for c in col_names
        if occursin("cost_bp", String(c))
            push!(cost_col, c)
        elseif occursin("load_bp", String(c))
            push!(load_col, c)
        end
    end
    for row in DataFrames.eachrow(DataFrames.DataFrame(val))
        push!(variable_costs, [Tuple(row[[c, l]]) for (c, l) in zip(cost_col, load_col)])
    end
    return variable_costs
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
            constraint_name(PSY.get_name(service), SR),
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
            constraint_name(PSY.get_name(service), SR),
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
                        constraint_name(PSY.get_name(service), service_model.service_type),
                    )
                end
            elseif service_model.service_type <: PSY.Reserve{PSY.ReserveUp}
                for service in services
                    push!(
                        constraint_data_out.additional_terms_ub,
                        constraint_name(PSY.get_name(service), service_model.service_type),
                    )
                end
            end
        end
    end
    return
end
