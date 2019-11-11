abstract type AbstractReservesFormulation<:AbstractServiceFormulation end

abstract type AbstractRegulationReserveFormulation<:AbstractReservesFormulation end

struct RampLimitedReserve<:AbstractReservesFormulation end

struct LoadProportionalReserve<:AbstractReservesFormulation end


########################### Reserve constraints ######################################

"""
This function add the variables for reserves to the model
"""
function activereserve_variables!(canonical_model::Canonical,
                                  S::SR,
                                  devices::Vector{T}) where {SR<:PSY.Service, T<:PSY.ThermalGen}

    add_variable(canonical_model,
                 devices,
                 Symbol("R_$(PSY.get_name(S))_$(T)"),
                 false;
                 ub_value = d -> d.tech.activepowerlimits.max,
                 lb_value = d -> 0 )

end

"""
This function add the variables for reserves to the model
"""
function activereserve_variables!(canonical_model::Canonical,
                                  service::S,
                                  devices::Vector{H}) where {S<:PSY.Service, H<:PSY.HydroGen}

    add_variable(canonical_model,
                 devices,
                 Symbol("R_$(PSY.get_name(S))_$(H)"),
                 false;
                 ub_value = d -> d.tech.activepowerlimits.max,
                 lb_value = d -> 0 )

end

"""
This function add the variables for reserves to the model
"""
function activereserve_variables!(canonical_model::Canonical,
                                  service::S,
                                  devices::Vector{R}) where {S<:PSY.Service, R<:PSY.RenewableGen}

    add_variable(canonical_model,
                 devices,
                 Symbol("R_$(PSY.get_name(S))_$(R)"),
                 false;
                 ub_value = d -> d.tech.activepowerlimits.max,
                 lb_value = d -> 0 )

end

"""
This function add the variables for reserves to the model
"""
function activereserve_variables!(canonical_model::Canonical,
                                  service::S,
                                  devices::Vector{ST}) where {S<:PSY.Service,
                                                            ST<:PSY.Storage}

    add_variable(canonical_model,
                 devices,
                 Symbol("R_$(PSY.get_name(S))_$(ST)"),
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

#=
##################
These models still need to be rewritten for the new infrastructure in PowerSimulations
##################


function reservevariables!(m::JuMP.AbstractModel, devices::Array{NamedTuple{(:device, :formulation), Tuple{R, DataType}}}, time_periods::Int64) where {R<:PSY.Device}

    on_set = [d.device.name for d in devices]

    t = 1:time_periods

    p_rsv = JuMP.@variable(m, p_rsv[on_set, t] >= 0)

    return p_rsv

end

# headroom constraints
function make_pmax_rsv_constraint!(m::JuMP.AbstractModel, t::Int64, device::G, formulation::Type{D}) where {G<:PSY.ThermalGen, D<:AbstractThermalDispatchFormulation}
    return JuMP.@constraint(m, m[:p_th][device.name, t] + m[:p_rsv][device.name, t]  <= device.tech.activepowerlimits.max)
end

function make_pmax_rsv_constraint!(m::JuMP.AbstractModel, t::Int64, device::G, formulation::Type{D}) where {G<:PSY.ThermalGen, D<:AbstractThermalFormulation}
    return JuMP.@constraint(m, m[:p_th][device.name, t] + m[:p_rsv][device.name, t] <= device.tech.activepowerlimits.max * m[:on_th][device.name, t])
end

function make_pmax_rsv_constraint!(m::JuMP.AbstractModel, t::Int64, device::G, formulation::Type{D}) where {G<:PSY.RenewableGen, D<:AbstractRenewableDispatchFormulation}
    return JuMP.@constraint(m, m[:p_re][device.name, t] + m[:p_rsv][device.name, t] <= device.tech.rating * values(device.scalingfactor)[t])
end

function make_pmax_rsv_constraint!(m::JuMP.AbstractModel, t::Int64, device::G, formulation::Type{D}) where {G<:PSY.InterruptibleLoad, D<:InterruptiblePowerLoad}
    return JuMP.@constraint(m, m[:p_cl][device.name, t] + m[:p_rsv][device.name, t] <= device.maxactivepower * values(device.scalingfactor)[t])
end

# ramp constraints
function make_pramp_rsv_constraint!(m::JuMP.AbstractModel, t::Int64, device::G, formulation::Type{D}, timeframe) where {G<:PSY.ThermalGen, D<:AbstractThermalFormulation}
    rmax = device.tech.ramplimits != nothing  ? device.tech.ramplimits.up : device.tech.activepowerlimits.max
    return JuMP.@constraint(m, m[:p_rsv][device.name, t] <= rmax/60 * timeframe)
end

function make_pramp_rsv_constraint!(m::JuMP.AbstractModel, t::Int64, device::G, formulation::Type{D}, timeframe) where {G<:PSY.RenewableGen, D<:AbstractRenewableDispatchFormulation}
    return
end
function make_pramp_rsv_constraint!(m::JuMP.AbstractModel, t::Int64, device::G, formulation::Type{D}, timeframe) where {G<:PSY.InterruptibleLoad, D<:InterruptiblePowerLoad}
    #rmax =  device.maxactivepower * values(device.scalingfactor)[t] #nominally setting load ramp limit to full range within 1 min
    #return JuMP.@constraint(m, m[:p_rsv][device.name, t] <= rmax/60 * timeframe)
    return
end


function reserves(m::JuMP.AbstractModel, devices::Array{NamedTuple{(:device, :formulation), Tuple{R, DataType}}}, service::PSY.StaticReserve, time_periods::Int64) where {R<:PSY.Device}

    p_rsv = m[:p_rsv]
    time_index = m[:p_rsv].axes[2]
    name_index = m[:p_rsv].axes[1]

    (length(time_index) != time_periods) ? @error("Length of time dimension inconsistent") : true

    pmin_rsv = JuMP.Containers.DenseAxisArray(Array{JuMP.ConstraintRef}(undef, length(time_index)), time_index) #minimum system reserve provision
    pmax_rsv = JuMP.Containers.DenseAxisArray(Array{JuMP.ConstraintRef}(undef, length.(JuMP.axes(p_rsv))), name_index, time_index) #maximum generator reserve provision


    for t in time_index
        pmin_rsv[t] = JuMP.@constraint(m, sum([p_rsv[name, t] for name in name_index]) >= service.requirement)

        for (ix, name) in enumerate(name_index)
            if name == devices[ix].device.name
                pmax_rsv[name, t] = make_pmax_rsv_constraint!(m, t, devices[ix].device, devices[ix].formulation)
            else
                @error "Gen name in Array and variable do not match"
            end
        end

    end

    rmp_devices = [d for d in devices if d.formulation<:PowerSimulations.ThermalDispatch]
    rmp_name_index = [d.device.name for d in rmp_devices]

    pramp_rsv = JuMP.Containers.DenseAxisArray(Array{JuMP.ConstraintRef}(undef, (length(rmp_name_index), length(time_index))), rmp_name_index, time_index) #maximum generator reserve provision

    for t in time_index
        # TODO: check the units of ramplimits
        for (ix, name) in enumerate(rmp_name_index)
            if name == rmp_devices[ix].device.name
                pramp_rsv[name, t] = make_pramp_rsv_constraint!(m, t, rmp_devices[ix].device, rmp_devices[ix].formulation, service.timeframe)
            else
                @error "Gen name in Array and variable do not match"
            end
        end

    end

    JuMP.register_object(m, :RsvProvisionMin, pmin_rsv)
    JuMP.register_object(m, :RsvProvisionMax, pmax_rsv)
    JuMP.register_object(m, :RsvProvisionRamp, pramp_rsv)

    return m

end
=#
