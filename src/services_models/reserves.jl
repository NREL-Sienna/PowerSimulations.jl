abstract type AbstractReservesFormulation <: AbstractServiceFormulation end
struct RangeUpwardReserve <: AbstractReservesFormulation end
############################### Reserve Variables` #########################################
"""
This function add the variables for reserves to the model
"""
function activeservice_variables!(canonical::Canonical,
                                  service::SR,
                                  devices::Vector{<:PSY.Device}) where SR<:PSY.Reserve
    add_variable(canonical,
                 devices,
                 Symbol("R$(PSY.get_name(service))_$SR"),
                 false;
                 ub_value = d -> d.tech.activepowerlimits.max,
                 lb_value = d -> 0 )
    return
end

################################## Reserve Requirement Constraint ##########################
# This function can be generalized later for any constraint of type Sum(req_var) >= requirement,
# it will only need to be specific to the names and get forecast string.
function service_requirement_constraint!(canonical::Canonical,
                                         service::SR) where {SR<:PSY.Reserve}
    time_steps = model_time_steps(canonical)
    parameters = model_has_parameters(canonical)
    forecast = model_uses_forecasts(canonical)
    initial_time = model_initial_time(canonical)
    reserve_variable = get_variable(canonical, Symbol("R$(PSY.get_name(service))_$SR"))
    constraint_name = Symbol(PSY.get_name(service), "_requirement_$SR")
    constraint = add_cons_container!(canonical, constraint_name, time_steps)
    requirement = PSY.get_requirement(service)
    if forecast
        ts_vector = TS.values(PSY.get_data(PSY.get_forecast(PSY.Deterministic,
                                                            service,
                                                            initial_time,
                                                            "get_requirement")))
    else
        ts_vector = ones(time_steps[end])
    end
    if parameters
        param = include_parameters(canonical, ts_vector,
                                   UpdateRef{SR}("get_requirement"), time_steps)
        for t in time_steps
            constraint[t] = JuMP.@constraint(canonical.JuMPmodel,
                                         sum(reserve_variable[:,t]) >= param[t]*requirement)
        end
    else
        for t in time_steps
            constraint[t] = JuMP.@constraint(canonical.JuMPmodel,
                                    sum(reserve_variable[:,t]) >= ts_vector[t]*requirement)
        end
    end
    return
end

# This function can also be generalized.
function add_to_service_expression!(canonical::Canonical,
                                    model::ServiceModel{SR, RangeUpwardReserve},
                                    service::SR,
                                    expression_list::Vector{Symbol}) where {SR<:PSY.Reserve}
    # Container
    time_steps = model_time_steps(canonical)
    devices = PSY.get_contributingdevices(service)
    var_type = JuMP.variable_type(canonical.JuMPmodel)
    expression = :upward_reserve
    expression ∉ expression_list && push!(expression, expression_list)
    expression_dict = get_expression!(canonical,
                                      expression,
                                      Dict{ServiceExpressionKey, Array{GAE{var_type}}}())
    reserve_variable = get_variable(canonical, Symbol("R$(PSY.get_name(service))_$SR"))
    #fill container
    for d in devices
        T = typeof(d)
        name = PSY.get_name(d)
        expressions = get!(expression_dict,
                           ServiceExpressionKey(name, T),
                           get_variable(canonical, Symbol("P_$(T)"))[name, :].data)
        for t in time_steps
            expressions[t] = JuMP.add_to_expression!(expressions[t], reserve_variable[name, t])
        end
    end
    return
end

function add_device_constraints!(canonical::Canonical,
                                 sys::System,
                                 expression_list::Vector{Symbol})
    for service_expression in expression_list
        expression_dictionary = get_expression(canonical, service_expression)
        for (k, v) in expression_dictionary
            device = get_component(k.device_type, sys, k.name)
            service_constraints(device, v, )
        end
    end
    return
end
