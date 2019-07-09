abstract type AbstractHydroFormulation <: AbstractDeviceFormulation end

abstract type AbstractHydroDispatchForm <: AbstractHydroFormulation end

abstract type HydroDispatchRunOfRiver <: AbstractHydroDispatchForm end

abstract type HydroDispatchSeasonalFlow <: AbstractHydroDispatchForm end

abstract type HydroCommitmentRunOfRiver <: AbstractHydroFormulation end

abstract type HydroCommitmentSeasonalFlow <: AbstractHydroFormulation end

# hydro variables

function activepower_variables(ps_m::CanonicalModel, devices::Array{H,1}, time_steps::UnitRange{Int64}) where {H <: PSY.HydroGen}

    add_variable(ps_m, devices, time_steps, :Phy, false, :nodal_balance_active)

    return

end


function reactivepower_variables(ps_m::CanonicalModel, devices::Array{H,1}, time_steps::UnitRange{Int64}) where {H <: PSY.HydroGen}

    add_variable(ps_m, devices, time_steps, :Qhy, false, :nodal_balance_reactive)

    return

end


function commitment_variables(ps_m::CanonicalModel, devices::Array{H,1}, time_steps::UnitRange{Int64}) where {H <: PSY.HydroGen}

    add_variable(ps_m, devices, time_steps, :on_hy, true)
    add_variable(ps_m, devices, time_steps, :start_hy, true)
    add_variable(ps_m, devices, time_steps, :stop_hy, true)

    return

end


# output constraints

function activepower_constraints(ps_m::CanonicalModel,
                                  devices::Array{H,1},
                                  device_formulation::Type{D},
                                  system_formulation::Type{S},
                                  time_steps::UnitRange{Int64}) where {H <: PSY.HydroGen,
                                                                       D <: AbstractHydroDispatchForm,
                                                                       S <: PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(h), PSY.get_tech(h) |> PSY.get_activepowerlimits) for h in devices]

    device_range(ps_m, range_data, time_steps, hydro_active_range, :Phy)

    return

end


function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Array{H,1},
                                 device_formulation::Type{HydroDispatchRunOfRiver},
                                 system_formulation::Type{S},
                                 time_steps::UnitRange{Int64}) where {H <: PSY.HydroGen,
                                                                      S <: PM.AbstractPowerFormulation}

    ts_data = [(PSY.get_name(h), values(PSY.get_scalingfactor(h))*(PSY.get_tech(h) |> PSY.get_rating)) for h in devices]

    device_timeseries_ub(ps_m, ts_data , time_steps, hydro_active_ub, :Phy)

    return

end


function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Array{H,1},
                                 device_formulation::Type{HydroDispatchSeasonalFlow},
                                 system_formulation::Type{S},
                                 time_steps::UnitRange{Int64}) where {H <: PSY.HydroGen,
                                                                      S <: PM.AbstractPowerFormulation}

    ts_data_ub = [(PSY.get_name(h), values(PSY.get_scalingfactor(h))*(PSY.get_tech(h) |> PSY.get_rating)) for h in devices]
    ts_data_lb = [(PSY.get_name(h), values(PSY.get_scalingfactor(h))*(PSY.get_tech(h) |> PSY.get_rating)) for h in devices]

    device_timeseries_ub(ps_m, ts_data_ub , time_steps, :hydro_active_ub, :Phy)
    device_timeseries_lb(ps_m, ts_data_lb , time_steps, :hydro_active_lb, :Phy)

    return

end





function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Array{H,1},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S},
                                   time_steps::UnitRange{Int64}) where {H <: PSY.HydroGen,
                                                                        D <: AbstractHydroDispatchForm,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_reactivepowerlimits) for g in devices]

    device_range(ps_m, range_data, time_steps, :hydro_reactive_range, :Qhy)

    return

end


function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Array{H,1},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S},
                                 time_steps::UnitRange{Int64}) where {H <: PSY.HydroGen,
                                                                      D <: AbstractHydroFormulation,
                                                                      S <: PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_activepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m, range_data, time_steps, :hydro_active_range, :Phy, :on_hy)

    return

end


function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::Array{H,1},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S},
                                   time_steps::UnitRange{Int64}) where {H <: PSY.HydroGen,
                                                                        D <: AbstractHydroFormulation,
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_reactivepowerlimits) for g in devices]

    device_semicontinuousrange(ps_m, range_data , time_steps, :hydro_reactive_range, :Qhy, :on_hy)

    return

end

# # Injection expression

# function nodal_expression(ps_m::CanonicalModel, devices::Array{R,1}, system_formulation::Type{S}, time_steps::UnitRange{Int64}) where {H <: PSY.Hydrogen, S <: PM.AbstractPowerFormulation}
#
#     for t in time_steps, d in devices
#
#         _add_to_expression!(ps_m.expressions[:nodal_balance_active], d.bus.number, t, d.tech.rating * values(d.scalingfactor)[t])
#
#         _add_to_expression!(ps_m.expressions[:nodal_balance_reactive], d.bus.number, t, d.tech.rating * values(d.scalingfactor)[t]*sin(acos(d.tech.powerfactor)))
#
#     end
#
#     return
#
# end
#
# function nodal_expression(ps_m::CanonicalModel, devices::Array{R,1}, system_formulation::Type{S}, time_steps::UnitRange{Int64}) where {H <: PSY.Hydrogen, S <: PM.AbstractActivePowerFormulation}
#
#     for t in time_steps, d in devices
#
#         _add_to_expression!(ps_m.expressions[:nodal_balance_active], d.bus.number, t, d.tech.rating * values(d.scalingfactor)[t])
#
#     end
#
#     return
#
# end
#

# # hydro generation cost

# function cost_function(ps_m::CanonicalModel, devices::Array{PSY.HydroGen,1}, device_formulation::Type{D}, system_formulation::Type{S}) where {D <: HydroDispatchRunOfRiver, S <: PM.AbstractPowerFormulation}
#
#     add_to_cost(ps_m, devices, :Phy, :curtailcost)
#
#     return
#
# end

