abstract type AbstractHydroFormulation <: AbstractDeviceFormulation end

abstract type AbstractHydroDispatchFormulation <: AbstractHydroFormulation end

struct HydroFixed <: AbstractHydroFormulation end

struct HydroDispatchRunOfRiver <: AbstractHydroDispatchFormulation end

struct HydroDispatchSeasonalFlow <: AbstractHydroDispatchFormulation end

struct HydroCommitmentRunOfRiver <: AbstractHydroFormulation end

struct HydroCommitmentSeasonalFlow <: AbstractHydroFormulation end

#=
# hydro variables

function activepower_variables(canonical_model::CanonicalModel,
                               devices::Vector{H}) where {H<:PSY.HydroGen}

    time_steps = model_time_steps(canonical_model)
    var_name = Symbol("P_$(H)")

    add_variable(canonical_model,
                 devices,
                 time_steps,
                 var_name,
                 false,
                 :nodal_balance_active)

    return

end


function reactivepower_variables(canonical_model::CanonicalModel,
                                 devices::Vector{H}) where {H<:PSY.HydroGen}

    time_steps = model_time_steps(canonical_model)
    var_name = Symbol("Q_$(H)")

    add_variable(canonical_model,
                 devices,
                 time_steps,
                 var_name,
                 false,
                 :nodal_balance_active)

    return

end


function commitment_variables(canonical_model::CanonicalModel, devices::Vector{H}, time_steps::UnitRange{Int64}) where {H<:PSY.HydroGen}

    add_variable(canonical_model, devices, time_steps, :on_hy, true)
    add_variable(canonical_model, devices, time_steps, :start_hy, true)
    add_variable(canonical_model, devices, time_steps, :stop_hy, true)

    return

end


# output constraints

function activepower_constraints(canonical_model::CanonicalModel,
                                  devices::Vector{H},
                                  device_formulation::Type{D},
                                  system_formulation::Type{S},
                                  time_steps::UnitRange{Int64}) where {H<:PSY.HydroGen,
                                                                       D<:AbstractHydroDispatchFormulation,
                                                                       S<:PM.AbstracPowerModel}

    range_data = [(PSY.get_name(h), PSY.get_tech(h) |> PSY.get_activepowerlimits) for h in devices]

    device_range(canonical_model, range_data, time_steps, hydro_activerange, :Phy)

    return

end


function activepower_constraints(canonical_model::CanonicalModel,
                                 devices::Vector{H},
                                 device_formulation::Type{HydroDispatchRunOfRiver},
                                 system_formulation::Type{S},
                                 time_steps::UnitRange{Int64}) where {H<:PSY.HydroGen,
                                                                      S<:PM.AbstracPowerModel}

    ts_data = [(PSY.get_name(h), values(PSY.get_scalingfactor(h))*(PSY.get_tech(h) |> PSY.get_rating)) for h in devices]

    device_timeseries_ub(canonical_model, ts_data , time_steps, hydro_active, :Phy)

    return

end


function activepower_constraints(canonical_model::CanonicalModel,
                                 devices::Vector{H},
                                 device_formulation::Type{HydroDispatchSeasonalFlow},
                                 system_formulation::Type{S},
                                 time_steps::UnitRange{Int64}) where {H<:PSY.HydroGen,
                                                                      S<:PM.AbstracPowerModel}

    ts_data_ub = [(PSY.get_name(h), values(PSY.get_scalingfactor(h))*(PSY.get_tech(h) |> PSY.get_rating)) for h in devices]
    ts_data_lb = [(PSY.get_name(h), values(PSY.get_scalingfactor(h))*(PSY.get_tech(h) |> PSY.get_rating)) for h in devices]

    device_timeseries_ub(canonical_model, ts_data_ub , time_steps, :hydro_active, :Phy)
    device_timeseries_lb(canonical_model, ts_data_lb , time_steps, :hydro_active_lb, :Phy)

    return

end





function reactivepower_constraints(canonical_model::CanonicalModel,
                                   devices::Vector{H},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S},
                                   time_steps::UnitRange{Int64}) where {H<:PSY.HydroGen,
                                                                        D<:AbstractHydroDispatchFormulation,
                                                                        S<:PM.AbstracPowerModel}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_reactivepowerlimits) for g in devices]

    device_range(canonical_model, range_data, time_steps, :hydro_reactiverange, :Qhy)

    return

end


function activepower_constraints(canonical_model::CanonicalModel,
                                 devices::Vector{H},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S},
                                 time_steps::UnitRange{Int64}) where {H<:PSY.HydroGen,
                                                                      D<:AbstractHydroFormulation,
                                                                      S<:PM.AbstracPowerModel}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_activepowerlimits) for g in devices]

    device_semicontinuousrange(canonical_model, range_data, time_steps, :hydro_activerange, :Phy, :on_hy)

    return

end


function reactivepower_constraints(canonical_model::CanonicalModel,
                                   devices::Vector{H},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S},
                                   time_steps::UnitRange{Int64}) where {H<:PSY.HydroGen,
                                                                        D<:AbstractHydroFormulation,
                                                                        S<:PM.AbstracPowerModel}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_reactivepowerlimits) for g in devices]

    device_semicontinuousrange(canonical_model, range_data , time_steps, :hydro_reactiverange, :Qhy, :on_hy)

    return

end
=#
