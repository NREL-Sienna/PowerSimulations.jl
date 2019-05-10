abstract type AbstractStorageForm <: AbstractDeviceFormulation end

struct BookKeeping <: AbstractStorageForm end

struct BookKeepingwReservation <: AbstractStorageForm end

#################################################Storage Variables#################################

function active_power_variables(ps_m::CanonicalModel, 
                                devices::Vector{St}, 
                                time_range::UnitRange{Int64}) where {St <: PSY.Storage}

    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Psin_$(St)"), 
                 false,
                 :nodal_balance_active, 
                 -1)
    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Psout_$(St)"), 
                 false, 
                 :nodal_balance_active)

    return

end


function reactive_power_variables(ps_m::CanonicalModel, 
                                  devices::Vector{St}, 
                                  time_range::UnitRange{Int64}) where {St <: PSY.Storage}

    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Qst_$(St)"), 
                 false, 
                 :nodal_balance_reactive)

    return

end


function energy_storage_variables(ps_m::CanonicalModel, 
                                  devices::Vector{St}, 
                                  time_range::UnitRange{Int64}) where St <: PSY.Storage

    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Est_$(St)"), 
                 false)

    return

end


function storage_reservation_variables(ps_m::CanonicalModel, 
                                       devices::Vector{St}, 
                                       time_range::UnitRange{Int64}) where St <: PSY.Storage

    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Rst_$(St)"),
                 true)

    return

end


###################################################### output power constraints#################################

function active_power_constraints(ps_m::CanonicalModel, 
                                  devices::Vector{St}, 
                                  device_formulation::Type{D}, 
                                  system_formulation::Type{S}, 
                                  time_range::UnitRange{Int64}) where {St <: PSY.Storage, 
                                                                       D <: AbstractStorageForm, 
                                                                       S <: PM.AbstractPowerFormulation}

    range_data_in = [(s.name, s.inputactivepowerlimits) for s in devices]

    range_data_out = [(s.name, s.outputactivepowerlimits) for s in devices]

    device_semicontinuousrange(ps_m, 
                               range_data_in, 
                               time_range, 
                               Symbol("inputpower_range_$(St)"), 
                               Symbol("Psin_$(St)"), 
                               Symbol("Est_$(St)"))

    reserve_device_semicontinuousrange(ps_m, 
                                       range_data_in, 
                                       time_range, 
                                       Symbol("outputpower_range_$(St)"), 
                                       Symbol("Psout_$(St)"), 
                                       Symbol("Rst_$(St)"))

    return

end


"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactivepower_constraints(ps_m::CanonicalModel, 
                                   devices::Vector{St}, 
                                   device_formulation::Type{D}, 
                                   system_formulation::Type{S}, 
                                   time_range::UnitRange{Int64}) where {St <: PSY.Storage, 
                                                                        D <: AbstractStorageForm, 
                                                                        S <: PM.AbstractPowerFormulation}

    range_data = [(s.name, s.reactivepowerlimits) for s in devices]

    device_range(ps_m, 
                 range_data, 
                 time_range, 
                 Symbol("reactive_range_$(St)"), 
                 Symbol("Qst_$(St)"))

    return

end


# book keeping constraints

function energy_balance_constraint(ps_m::CanonicalModel, 
                                   devices::Vector{St}, 
                                   device_formulation::Type{D}, 
                                   system_formulation::Type{S}, 
                                   time_range::UnitRange{Int64}, 
                                   initial_conditions::Array{Float64,1}) where {St <: PSY.Storage, 
                                                                                D <: AbstractStorageForm, 
                                                                                S <: PM.AbstractPowerFormulation}

    named_initial_conditions = [(d.name, initial_conditions[ix]) for (ix, d) in enumerate(devices)]

    p_eff_data = [(d.name,d.energy) for d in devices if !isa(d.energy, Nothing)]

    if !isempty(p_eff_data)

        energy_balance(ps_m,
                       time_range,
                       named_initial_conditions,
                       p_eff_data, 
                       Symbol("energy_balance_$(St)"),
                       (Symbol("Psout_$(St)"), Symbol("Psin_$(St)"), Symbol("Est_$(St)")))

    else
        @warn "Data doesn't contain Storage efficiency , consider adjusting your formulation"
    end

    return

end
