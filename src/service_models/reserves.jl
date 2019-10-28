########################### Reserve constraints ######################################

"""
This function add the variables for reserves to the model
"""
function activereserve_variables!(canonical_model::CanonicalModel,
                                service::S) where { S<:PSY.Service}

    devices = service.contributingdevices
    expression = Symbol(service.name,"_","balance")
    add_variable(canonical_model,
                 devices,
                 Symbol("R_$(service.name)"),
                 false,
                 expression;
                 ub_value = d -> d.tech.activepowerlimits.max,
                 lb_value = d -> 0 )

end


"""
This function adds the active power limits of generators when there are CommitmentVariables
"""

function activereserve_constraints!(canonical_model::CanonicalModel,
                                    service::S,
                                    formulations::Type{F}) where {S<:PSY.Service,
                                                            F<:AbstractServiceFormulation}
    
    name = Symbol("activerange")
    devices = service.contributingdevices
    expression = exp(canonical_model, name)
    if isnothing(expression)
        @error("Failed to find Constraint expression for ActiveRange Constraint")
    end
    device_range_expression!(canonical_model,
                        devices,
                        name,
                        Symbol("R_$(service.name)")
                        )

    return

end

########################### Ramp/Rate of Change constraints ################################

"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function reserve_ramp_constraints!(canonical_model::CanonicalModel,
                                    service::S,
                                    formulations::Type{F}) where {S<:PSY.Service,
                                                            F<:AbstractServiceFormulation}

    name = Symbol("ramp_up")
    devices = service.contributingdevices
    expression = exp(canonical_model, name)
    if isnothing(expression)
        @error("Failed to find Constraint expression for ActiveRange Constraint")
    end
    device_rateofchange!(canonical_model,
                        devices,
                        name,
                        Symbol("R_$(service.name)"))

    return

end

############################################## Time Series ###################################

function _get_time_series(canonical::CanonicalModel,
                          service::L) where L<:PSY.Service

    initial_time = model_initial_time(canonical)
    forecast = model_uses_forecasts(canonical)
    time_steps = model_time_steps(canonical)
    ts_data = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, 1)

    name = PSY.get_name(service)
    requirement = forecast ? PSY.get_requirement(service) : 0.0
    bus_number = PSY.get_number(PSY.get_bus(service.contributingdevices[1]))
    if forecast
        ts_vector = TS.values(PSY.get_data(PSY.get_forecast(PSY.Deterministic,
                                                            service,
                                                            initial_time,
                                                            "requirement")))
    else
        ts_vector = ones(time_steps[end])
    end
    ts_data[1] = (name, bus_number, requirement, ts_vector)

    return ts_data

end

function nodal_expression!(canonical::CanonicalModel,
                           service::L,
                           system_formulation::Type{<:PM.AbstractActivePowerModel}) where L<:PSY.Service


    parameters = model_has_parameters(canonical)
    ts_data = _get_time_series(canonical, service)

    if parameters
        include_parameters(canonical,
                        ts_data,
                        UpdateRef{L}(:requirement),
                        Symbol(service.name,"_","balance"),
                        -1.0)
        return
    end

    for t in model_time_steps(canonical), device_value in ts_data
        _add_to_expression!(canonical.expressions[Symbol(service.name,"_","balance")],
                            device_value[2],
                            t,
                            -device_value[3]*device_value[4][t])
    end

    return
end


"""
This function adds the active power limits of generators when there are CommitmentVariables
"""

function service_balance(canonical_model::CanonicalModel, service::S) where {S<:PSY.Service}

    time_steps = model_time_steps(canonical_model)
    name = Symbol(service.name,"_","balance")
    expression = PSI.exp(canonical_model, name)
    canonical_model.constraints[name] = JuMPConstraintArray(undef, time_steps)
    _remove_undef!(expression)

    for t in time_steps
        canonical_model.constraints[name][t] = JuMP.@constraint(canonical_model.JuMPmodel, sum(expression.data[1:end, t]) >= 0)
    end

    return

end
