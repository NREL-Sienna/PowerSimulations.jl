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

function _nodal_expression_fixed!(canonical_model::CanonicalModel,
                                forecasts::Vector{PSY.Deterministic{L}},
                                ::Type{S}) where {L<:PSY.Reserve,
                                                S<:PM.AbstractActivePowerModel}

    time_steps = model_time_steps(canonical_model)

    for f in forecasts
        service = PSY.get_component(f)
        # bus_number = PSY.get_bus(d) |> PSY.get_number
        name = Symbol(service.name,"_","balance")
        expression = PSI.exp(canonical_model, name)
        if isnothing(expression)
            @error("Balance Constraint expression for $(service.name) not created")
        end
        reserve_factor = PSY.get_requirement(service)
        time_series_vector = values(PSY.get_data(f))
        for t in time_steps
            _add_to_expression!(expression,
                                1,  # TODO: needs to be actual bus numbers 
                                t,
                                -1 * time_series_vector[t] * reserve_factor)
        end
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
