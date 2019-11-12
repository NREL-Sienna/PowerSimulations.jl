abstract type AbstractReservesFormulation <: AbstractServiceFormulation end

struct SpinningReserve <: AbstractReservesFormulation end

struct RampLimitedSpinningReserve <: AbstractReservesFormulation end

########################### Reserve constraints ######################################

"""
This function add the variables for reserves to the model
"""
function activereserve_variables!(canonical_model::Canonical,
                                  S::SR,
                                  devices::Vector{PSD}) where {SR<:PSY.Service, PSD<:PSY.Device}

    add_variable(canonical_model,
                 devices,
                 Symbol("R_$(PSY.get_name(S))_$(PSD)"),
                 false;
                 ub_value = d -> d.tech.activepowerlimits.max,
                 lb_value = d -> 0 )

end

########################### Active Reserve constraints ################################

"""
This function adds the reserve variable to active power limits constraint for ThermalGen devices
"""

function activereserve_constraints!(canonical_model::Canonical,
                                    devices::Vector{T},
                                    S::SR,
                                    formulation::Type{F}) where {T<:PSY.ThermalGen,
                                                                SR<:PSY.Service,
                                                                F<:AbstractServiceFormulation}

    name = Symbol("service_$(T)")
    expression = exp(canonical_model, name)
    add_to_service_expression!(canonical_model,
                            devices,
                            name,
                            Symbol("R_$(PSY.get_name(S))_$(T)")
                            )

    return

end

"""
This function adds the reserve variable to active power limits constraint for HydroGen devices
"""

function activereserve_constraints!(canonical_model::Canonical,
                                    devices::Vector{H},
                                    S::SR,
                                    formulation::Type{F}) where {H<:PSY.HydroGen,
                                                                SR<:PSY.Service,
                                                                F<:AbstractServiceFormulation}

    name = Symbol("service_$(H)")
    expression = exp(canonical_model, name)
    add_to_service_expression!(canonical_model,
                            devices,
                            name,
                            Symbol("R_$(PSY.get_name(S))_$(H)")
                            )

    return

end

"""
This function adds the reserve variable to active power limits constraint for RenewableGen devices
"""

function activereserve_constraints!(canonical_model::Canonical,
                                    devices::Vector{R},
                                    S::SR,
                                    formulation::Type{F}) where {R<:PSY.RenewableGen,
                                                                SR<:PSY.Service,
                                                                F<:AbstractServiceFormulation}

    name = Symbol("service_$(R)")
    expression = exp(canonical_model, name)
    add_to_service_expression!(canonical_model,
                            devices,
                            name,
                            Symbol("R_$(PSY.get_name(S))_$(R)")
                            )

    return

end

"""
This function adds the reserve variable to active power limits constraint for Storage devices
"""

function activereserve_constraints!(canonical_model::Canonical,
                                    devices::Vector{ST},
                                    S::SR,
                                    formulation::Type{F}) where {ST<:PSY.Storage,
                                                                SR<:PSY.Service,
                                                                F<:AbstractServiceFormulation}

    name = Symbol("service_$(ST)")
    expression = exp(canonical_model, name)
    add_to_service_expression!(canonical_model,
                            devices,
                            name,
                            Symbol("R_$(PSY.get_name(S))_$(ST)")
                            )

    return

end

################################## Time Series Constraints ###################################

function _get_time_series(canonical::Canonical,
                          service::L) where L<:PSY.Service

    initial_time = model_initial_time(canonical)
    forecast = model_uses_forecasts(canonical)
    time_steps = model_time_steps(canonical)
    ts_data = Vector{Tuple{String, Float64, Vector{Float64}}}(undef, 1)

    name = PSY.get_name(service)
    requirement = forecast ? PSY.get_requirement(service) : 0.0
    if forecast
        ts_vector = TS.values(PSY.get_data(PSY.get_forecast(PSY.Deterministic,
                                                            service,
                                                            initial_time,
                                                            "requirement")))
    else
        ts_vector = ones(time_steps[end])
    end
    ts_data[1] = (name, requirement, ts_vector)

    return ts_data

end

################################## Reserve Balance Constraint ###################################

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""

function service_balance_constraint!(canonical::Canonical, S::SR) where {SR<:PSY.Service}

    time_steps = model_time_steps(canonical)
    parameters = model_has_parameters(canonical)
    V = JuMP.variable_type(canonical.JuMPmodel)
    ts_data = _get_time_series(canonical, S)

    name = Symbol(PSY.get_name(S),"_","balance")
    constraint = _add_cons_container!(canonical, name, time_steps)

    expr = zero(JuMP.GenericAffExpr{Float64, V})

    for (T,devices) in _get_devices_bytype(PSY.get_contributingdevices(S))
        expr = expr + sum(var(canonical,Symbol("R_$(PSY.get_name(S))_$(T)")))
    end
    if parameters
        param = _add_param_container!(canonical, UpdateRef{L}(:requirement), time_steps)
        for t in time_steps
            param[t] = PJ.add_parameter(canonical.JuMPmodel, ts_data[3][t])
            constraint[t] = JuMP.@constraint(canonical.JuMPmodel, sum(expr) >= param[t]*ts_data[2])
        end
    else
        for t in time_steps
            constraint[t] = JuMP.@constraint(canonical.JuMPmodel, sum(expr) >= ts_data[2]*ts_data[3][t])
        end
    end
    return

end

################################## Utils ###################################

function add_to_service_expression!(canonical::Canonical,
                    devices::Vector{T},
                    exp_name::Symbol,
                    var_name::Symbol) where {T<:PSY.Component}

    time_steps = model_time_steps(canonical)
    var = PSI.var(canonical, var_name)
    expression_cont = exp(canonical, exp_name)
    for t in time_steps , d in devices
        name = PSY.get_name(d)
        if isassigned(expression_cont, name, t)
            JuMP.add_to_expression!(expression_cont[name, t], 1.0, var[name, t])
        else
            expression_cont[name, t] = zero(eltype(expression_cont)) + 1.0*var[name, t];
        end
    end

    return
end
