abstract type AbstractHydroFormulation<:AbstractDeviceFormulation end

abstract type AbstractHydroDispatchForm<:AbstractHydroFormulation end

struct HydroFixed<:AbstractHydroFormulation end

struct HydroDispatchRunOfRiver<:AbstractHydroDispatchForm end

struct HydroDispatchSeasonalFlow<:AbstractHydroDispatchForm end

struct HydroCommitmentRunOfRiver<:AbstractHydroFormulation end

struct HydroCommitmentSeasonalFlow<:AbstractHydroFormulation end

#=
# hydro variables

function activepower_variables(ps_m::CanonicalModel,
                               devices::Vector{H}) where {H<:PSY.HydroGen}

    time_steps = model_time_steps(ps_m)
    var_name = Symbol("P_$(H)")

    add_variable(ps_m,
                 devices,
                 time_steps,
                 var_name,
                 false,
                 :nodal_balance_active)

    return

end


function reactivepower_variables(ps_m::CanonicalModel,
                                 devices::Vector{H}) where {H<:PSY.HydroGen}

    time_steps = model_time_steps(ps_m)
    var_name = Symbol("Q_$(H)")

    add_variable(ps_m,
                 devices,
                 time_steps,
                 var_name,
                 false,
                 :nodal_balance_active)

    return

end


function commitment_variables(ps_m::CanonicalModel, devices::Vector{H}, time_steps::UnitRange{Int64}) where {H<:PSY.HydroGen}

    add_variable(ps_m, devices, time_steps, :on_hy, true)
    add_variable(ps_m, devices, time_steps, :start_hy, true)
    add_variable(ps_m, devices, time_steps, :stop_hy, true)

    return

end


# output constraints

function activepower_constraints(ps_m::CanonicalModel,
                                  devices::Vector{H},
                                  device_formulation::Type{D},
                                  system_formulation::Type{S},
                                  time_steps::UnitRange{Int64}) where {H<:PSY.HydroGen,
                                                                       D<:AbstractHydroDispatchForm,
                                                                       S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(h), PSY.get_tech(h) |> PSY.get_activepowerlimits) for h in devices]

    device_range(ps_m, range_data, time_steps, hydro_activerange, :Phy)

    return

end


function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Vector{H},
                                 device_formulation::Type{HydroDispatchRunOfRiver},
                                 system_formulation::Type{S},
                                 time_steps::UnitRange{Int64}) where {H<:PSY.HydroGen,
                                                                      S<:PM.AbstractPowerFormulation}

    ts_data = [(PSY.get_name(h), values(PSY.get_scalingfactor(h))*(PSY.get_tech(h) |> PSY.get_rating)) for h in devices]

    device_timeseries_ub(ps_m, ts_data , time_steps, hydro_active, :Phy)

    return

end


function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Vector{H},
                                 device_formulation::Type{HydroDispatchSeasonalFlow},
                                 system_formulation::Type{S},
                                 time_steps::UnitRange{Int64}) where {H<:PSY.HydroGen,
                                                                      S<:PM.AbstractPowerFormulation}

    ts_data_ub = [(PSY.get_name(h), values(PSY.get_scalingfactor(h))*(PSY.get_tech(h) |> PSY.get_rating)) for h in devices]
    ts_data_lb = [(PSY.get_name(h), values(PSY.get_scalingfactor(h))*(PSY.get_tech(h) |> PSY.get_rating)) for h in devices]

    device_timeseries_ub(ps_m, ts_data_ub , time_steps, :hydro_active, :Phy)
    device_timeseries_lb(ps_m, ts_data_lb , time_steps, :hydro_active_lb, :Phy)

    return

end





function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Vector{H},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S},
                                   time_steps::UnitRange{Int64}) where {H<:PSY.HydroGen,
                                                                        D<:AbstractHydroDispatchForm,
                                                                        S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_reactivepowerlimits) for g in devices]

    device_range(ps_m, range_data, time_steps, :hydro_reactiverange, :Qhy)

    return

end


function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Vector{H},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S},
                                 time_steps::UnitRange{Int64}) where {H<:PSY.HydroGen,
                                                                      D<:AbstractHydroFormulation,
                                                                      S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_activepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m, range_data, time_steps, :hydro_activerange, :Phy, :on_hy)

    return

end


function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Vector{H},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S},
                                   time_steps::UnitRange{Int64}) where {H<:PSY.HydroGen,
                                                                        D<:AbstractHydroFormulation,
                                                                        S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_reactivepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m, range_data , time_steps, :hydro_reactiverange, :Qhy, :on_hy)

    return

end
=#
############################ injection expression with parameters ####################################

########################################### Devices ####################################################

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{H},
                                system_formulation::Type{S}) where {H<:PSY.HydroGen,
                                                                    S<:PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)
    ts_data_active = Vector{Tuple{String, Int64, Vector{Float64}}}(undef, length(devices))
    ts_data_reactive = Vector{Tuple{String, Int64, Vector{Float64}}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        time_series_vector = fill(PSY.get_tech(d) |> PSY.get_rating, (time_steps[end]))
        ts_data_active[ix] = (PSY.get_name(d), PSY.get_bus(d) |> PSY.get_number, time_series_vector)
        ts_data_reactive[ix] = (PSY.get_name(d), PSY.get_bus(d) |> PSY.get_number, time_series_vector * sin(acos(PSY.get_tech(d) |> PSY.get_powerfactor)))
    end

    include_parameters(ps_m,
                    ts_data_active,
                    Symbol("P_$(H)"),
                    :nodal_balance_active)
    include_parameters(ps_m,
                    ts_data_reactive,
                    Symbol("Q_$(H)"),
                    :nodal_balance_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{H},
                                system_formulation::Type{S}) where {H<:PSY.HydroGen,
                                                                    S<:PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)
    ts_data_active = Vector{Tuple{String, Int64, Vector{Float64}}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        time_series_vector = fill(PSY.get_tech(d) |> PSY.get_rating, (time_steps[end]))
        ts_data_active[ix] = (PSY.get_name(d), PSY.get_bus(d) |> PSY.get_number, time_series_vector)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    Symbol("P_$(H)"),
                    :nodal_balance_active)

    return

end

############################################## Time Series ###################################
function _nodal_expression_param(ps_m::CanonicalModel,
                                 forecasts::PSY.FlattenIteratorWrapper{PSY.Deterministic{H}},
                                 system_formulation::Type{S}) where {H<:PSY.HydroGen,
                                                                     S<:PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)
    ts_data_active = Vector{Tuple{String, Int64, Vector{Float64}}}(undef, length(forecasts))
    ts_data_reactive = Vector{Tuple{String, Int64, Vector{Float64}}}(undef, length(forecasts))

    for (ix, f) in enumerate(forecasts)
        device = PSY.get_component(f)
        time_series_vector = values(PSY.get_data(f))*(PSY.get_tech(device) |> PSY.get_rating)
        ts_data_active[ix] = (PSY.get_name(device), PSY.get_bus(device) |> PSY.get_number, time_series_vector)
        ts_data_reactive[ix] = (PSY.get_name(device),
                                PSY.get_bus(device) |> PSY.get_number,
                                time_series_vector * sin(acos(PSY.get_tech(device) |> PSY.get_powerfactor)))
    end

    include_parameters(ps_m,
                    ts_data_active,
                    Symbol("P_$(H)"),
                    :nodal_balance_active)
    include_parameters(ps_m,
                    ts_data_reactive,
                    Symbol("Q_$(H)"),
                    :nodal_balance_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                forecasts::PSY.FlattenIteratorWrapper{PSY.Deterministic{H}},
                                system_formulation::Type{S}) where {H<:PSY.HydroGen,
                                                                    S<:PM.AbstractActivePowerFormulation}

    ts_data_active = Vector{Tuple{String, Int64, Vector{Float64}}}(undef, length(forecasts))

    for (ix, f) in enumerate(forecasts)
        device = PSY.get_component(f)
        time_series_vector = values(PSY.get_data(f)) * (PSY.get_tech(device) |> PSY.get_rating)
        ts_data_active[ix] = (PSY.get_name(device),
                              PSY.get_bus(device) |> PSY.get_number,
                              time_series_vector)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    Symbol("P_$(H)"),
                    :nodal_balance_active)

    return

end

############################ injection expression with fixed values ####################################
########################################### Devices ####################################################
function _nodal_expression_fixed(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{H},
                                system_formulation::Type{S}) where {H<:PSY.HydroGen,
                                                                     S<:PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)

    for t in time_steps, d in devices
        _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                            PSY.get_bus(d) |> PSY.get_number,
                            t,
                            PSY.get_tech(d) |> PSY.get_rating)
        _add_to_expression!(ps_m.expressions[:nodal_balance_reactive],
                            PSY.get_bus(d) |> PSY.get_number,
                            t,
                            (PSY.get_tech(d) |> PSY.get_rating) * sin(acos(PSY.get_tech(d) |> PSY.get_powerfactor)))
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                    devices::PSY.FlattenIteratorWrapper{H},
                                    system_formulation::Type{S}) where {H<:PSY.HydroGen,
                                                                         S<:PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)

    for t in time_steps, d in devices
        _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                            PSY.get_bus(d) |> PSY.get_number,
                            t,
                            PSY.get_tech(d) |> PSY.get_rating)
    end

    return

end


############################################## Time Series ###################################
function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::PSY.FlattenIteratorWrapper{PSY.Deterministic{H}},
                                system_formulation::Type{S}) where {H<:PSY.HydroGen,
                                                                    S<:PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)

    for f in forecasts
        time_series_vector = values(PSY.get_data(f)) * (PSY.get_component(f) |> PSY.get_tech |> PSY.get_rating)
        device = PSY.get_component(f)
        for t in time_steps
            _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                                PSY.get_bus(device) |> PSY.get_number,
                                t,
                                time_series_vector[t])
            _add_to_expression!(ps_m.expressions[:nodal_balance_reactive],
                                PSY.get_bus(device) |> PSY.get_number,
                                t,
                                time_series_vector[t] * sin(acos(PSY.get_tech(device) |> PSY.get_powerfactor)))
        end
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::PSY.FlattenIteratorWrapper{PSY.Deterministic{H}},
                                system_formulation::Type{S}) where {H<:PSY.HydroGen,
                                                                    S<:PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)

    for f in forecasts
        time_series_vector = values(PSY.get_data(f)) * (PSY.get_component(f) |> PSY.get_tech |> PSY.get_rating)
        device = PSY.get_component(f)
        for t in time_steps
            _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                                PSY.get_bus(device) |> PSY.get_number,
                                t,
                                time_series_vector[t])
        end
    end

    return

end
