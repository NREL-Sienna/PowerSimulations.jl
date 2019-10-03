########################### Reserve constraints ######################################

"""
This function add the variables for reserves to the model
"""
function activereserve_variables!(canonical_model::CanonicalModel,
                           devices::Vector{T}) where {T<:PSY.ThermalGen}

    add_variable(canonical_model,
                 devices,
                 Symbol("R_$(T)"),
                 false,
                 :reserve_balance_active;
                 ub_value = d -> d.tech.activepowerlimits.max,
                 lb_value = d -> 0 )

    return

end

"""
This function add the variables for reserves to the model
"""
function activereserve_variables!(canonical_model::CanonicalModel,
                           devices::Vector{H}) where {H<:PSY.HydroGen}

    return

end

"""
This function add the variables for reserves to the model
"""
function activereserve_variables!(canonical_model::CanonicalModel,
                           devices::Vector{R}) where {R<:PSY.RenewableGen}

    add_variable(canonical_model,
                 devices,
                 Symbol("R_$(T)"),
                 false,
                 :reserve_balance_active;
                 ub_value = d -> d.tech.activepowerlimits.max,
                 lb_value = 0 )

    return

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""

function activereserve_constraints!(canonical_model::CanonicalModel,
                                 devices::Vector{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                     D<:AbstractThermalDispatchForm,
                                                                     S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_activepowerlimits) for g in devices]

    reserve_device_range(canonical_model,
                 range_data,
                 Symbol("activerange_$(T)"),
                 (Symbol("P_$(T)"),
                 Symbol("R_$(T)"))
                 )
    return

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""

function activereserve_constraints!(canonical_model::CanonicalModel,
                                 devices::Vector{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                     D<:AbstractThermalUnitCommitment,
                                                                     S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_activepowerlimits) for g in devices]

    reserve_device_semicontinuousrange(canonical_model,
                 range_data,
                 Symbol("activerange_$(T)"),
                 (Symbol("P_$(T)"),
                 Symbol("R_$(T)")),
                 Symbol("ON_$(T)"))
    return

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""

function activereserve_constraints!(canonical_model::CanonicalModel,
                                 devices::Vector{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T<:PSY.HydroGen,
                                                                     D<:AbstractThermalUnitCommitment,
                                                                     S<:PM.AbstractPowerFormulation}

    return

end

######################## output constraints without Time Series ###################################

function activereserve_constraints!(canonical_model::CanonicalModel,
                                devices::Vector{R},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                         D<:AbstractRenewableDispatchForm,
                                                         S<:PM.AbstractPowerFormulation}

    parameters = model_has_parameters(canonical_model)

    if parameters
        time_steps = model_time_steps(canonical_model)
        reserve_device_timeseries_ub(canonical_model,
                            _get_time_series(devices, time_steps),
                            Symbol("activerange_$(R)"),
                            UpdateRef{R}(Symbol("P_$(R)")),
                            Symbol("P_$(R)"),
                            Symbol("R_$(R)"))

    else
        range_data = [(PSY.get_name(d), (min = 0.0, max = PSY.get_tech(d) |> PSY.get_rating)) for d in devices]
        reserve_device_range(canonical_model,
                    range_data,
                    Symbol("activerange_$(R)"),
                    Symbol("P_$(R)"),
                    Symbol("R_$(R)"))
    end

    return

end

######################### output constraints with Time Series ##############################################

function activereserve_constraints!(canonical_model::CanonicalModel,
                                 forecasts::Vector{PSY.Deterministic{R}},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                     D<:AbstractRenewableDispatchForm,
                                                                     S<:PM.AbstractPowerFormulation}

    if model_has_parameters(canonical_model)
        reserve_device_timeseries_param_ub(canonical_model,
                                   _get_time_series(forecasts),
                                   Symbol("activerange_$(R)"),
                                   UpdateRef{R}(Symbol("P_$(R)")),
                                   Symbol("P_$(R)"),
                                   Symbol("R_$(R)"))
    else
        reserve_device_timeseries_ub(canonical_model,
                            _get_time_series(forecasts),
                            Symbol("activerange_$(R)"),
                            Symbol("P_$(R)"),
                            Symbol("R_$(R)"))
    end

    return

end

########################### Ramp/Rate of Change constraints ################################

"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function reserve_ramp_constraints!(canonical_model::CanonicalModel,
                           devices::Vector{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                    D<:AbstractThermalUnitCommitment,
                                                    S<:PM.AbstractPowerFormulation}
    key = ICKey(DevicePower, T)

    if !(key in keys(canonical_model.initial_conditions))
        error("Initial Conditions for $(T) Rate of Change Constraints not in the model")
    end

    time_steps = model_time_steps(canonical_model)
    resolution = model_resolution(canonical_model)
    initial_conditions = get_ini_cond(canonical_model, key)
    rate_data = _get_data_for_rocc(initial_conditions, resolution)
    ini_conds, ramp_params, minmax_params = _get_data_for_rocc(initial_conditions, resolution)

    if !isempty(ini_conds)
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        reserve_device_mixedinteger_rateofchange(canonical_model,
                                         (ramp_params, minmax_params),
                                         ini_conds,
                                         Symbol("ramp_$(T)"),
                                         (Symbol("P_$(T)"),
                                         Symbol("START_$(T)"),
                                         Symbol("STOP_$(T)"),
                                         Symbol("R_$(T)"))
                                        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end

function reserve_ramp_constraints!(canonical_model::CanonicalModel,
                          devices::Vector{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                   D<:AbstractThermalDispatchForm,
                                                   S<:PM.AbstractPowerFormulation}

    key = ICKey(DevicePower, T)

    if !(key in keys(canonical_model.initial_conditions))
        error("Initial Conditions for $(T) Rate of Change Constraints not in the model")
    end

    time_steps = model_time_steps(canonical_model)
    resolution = model_resolution(canonical_model)
    initial_conditions = get_ini_cond(canonical_model, key)
    rate_data = _get_data_for_rocc(initial_conditions, resolution)
    ini_conds, ramp_params, minmax_params = _get_data_for_rocc(initial_conditions, resolution)

    if !isempty(ini_conds)
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        reseve_device_linear_rateofchange(canonical_model,
                                  ramp_params,
                                  ini_conds,
                                   Symbol("ramp_$(T)"),
                                   Symbol("P_$(T)"),
                                   Symbol("R_$(T)"))
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end

function reserve_ramp_constraints!(canonical_model::CanonicalModel,
                           devices::Vector{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S}) where {T<:PSY.HydroGen,
                                                    D<:AbstractThermalFormulation,
                                                    S<:PM.AbstractPowerFormulation}
    return

end

function reserve_ramp_constraints!(canonical_model::CanonicalModel,
                           devices::Vector{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S}) where {T<:PSY.RenewableGen,
                                                    D<:AbstractThermalFormulation,
                                                    S<:PM.AbstractPowerFormulation}
    return

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""
# function reserve_constraints!(canonical_model::CanonicalModel,
#                                 service::G,
#                                 device_formulation::Type{D},
#                                 service_formulation::Type{R},
#                                 system_formulation::Type{S}) where {G<:PSY.Reserve,
#                                                                     D<:AbstractThermalFormulation,
#                                                                     R<:AbstractReservesForm,
#                                                                     S<:PM.AbstractPowerFormulation}

#     requirement = service.requirement
#     devices = service.contributingdevices
#     reserve_constraint(canonical_model,
#                         requirement,
#                         Symbol("P_$(T)"),
#                         Symbol("ON_$(T)"))

#     return

# end


#=
##################
These models still need to be rewritten for the new infrastructure in PowerSimulations
##################


function reservevariables(m::JuMP.AbstractModel, devices::Array{NamedTuple{(:device, :formulation), Tuple{R, DataType}}}, time_periods::Int64) where {R<:PSY.Device}

    on_set = [d.device.name for d in devices]

    t = 1:time_periods

    p_rsv = JuMP.@variable(m, p_rsv[on_set, t] >= 0)

    return p_rsv

end

# headroom constraints
function make_pmax_rsv_constraint(m::JuMP.AbstractModel, t::Int64, device::G, formulation::Type{D}) where {G<:PSY.ThermalGen, D<:AbstractThermalDispatchForm}
    return JuMP.@constraint(m, m[:p_th][device.name, t] + m[:p_rsv][device.name, t]  <= device.tech.activepowerlimits.max)
end

function make_pmax_rsv_constraint(m::JuMP.AbstractModel, t::Int64, device::G, formulation::Type{D}) where {G<:PSY.ThermalGen, D<:AbstractThermalFormulation}
    return JuMP.@constraint(m, m[:p_th][device.name, t] + m[:p_rsv][device.name, t] <= device.tech.activepowerlimits.max * m[:on_th][device.name, t])
end

function make_pmax_rsv_constraint(m::JuMP.AbstractModel, t::Int64, device::G, formulation::Type{D}) where {G<:PSY.RenewableGen, D<:AbstractRenewableDispatchForm}
    return JuMP.@constraint(m, m[:p_re][device.name, t] + m[:p_rsv][device.name, t] <= device.tech.rating * values(device.scalingfactor)[t])
end

function make_pmax_rsv_constraint(m::JuMP.AbstractModel, t::Int64, device::G, formulation::Type{D}) where {G<:PSY.InterruptibleLoad, D<:InterruptiblePowerLoad}
    return JuMP.@constraint(m, m[:p_cl][device.name, t] + m[:p_rsv][device.name, t] <= device.maxactivepower * values(device.scalingfactor)[t])
end

# ramp constraints
function make_pramp_rsv_constraint(m::JuMP.AbstractModel, t::Int64, device::G, formulation::Type{D}, timeframe) where {G<:PSY.ThermalGen, D<:AbstractThermalFormulation}
    rmax = device.tech.ramplimits != nothing  ? device.tech.ramplimits.up : device.tech.activepowerlimits.max
    return JuMP.@constraint(m, m[:p_rsv][device.name, t] <= rmax/60 * timeframe)
end

function make_pramp_rsv_constraint(m::JuMP.AbstractModel, t::Int64, device::G, formulation::Type{D}, timeframe) where {G<:PSY.RenewableGen, D<:AbstractRenewableDispatchForm}
    return
end
function make_pramp_rsv_constraint(m::JuMP.AbstractModel, t::Int64, device::G, formulation::Type{D}, timeframe) where {G<:PSY.InterruptibleLoad, D<:InterruptiblePowerLoad}
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
                pmax_rsv[name, t] = make_pmax_rsv_constraint(m, t, devices[ix].device, devices[ix].formulation)
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
                pramp_rsv[name, t] = make_pramp_rsv_constraint(m, t, rmp_devices[ix].device, rmp_devices[ix].formulation, service.timeframe)
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
