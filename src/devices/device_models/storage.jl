abstract type AbstractStorageFormulation <: AbstractDeviceFormulation end

struct BookKeeping <: AbstractStorageFormulation end

struct BookKeepingwReservation <: AbstractStorageFormulation end

#################################################Storage Variables#################################

function active_power_variables(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{St}) where {St<:PSY.Storage}

    add_variable(canonical_model,
                 devices,
                 Symbol("Psin_$(St)"),
                 false,
                 :nodal_balance_active,
                 -1.0;
                 lb_value = d -> 0.0,)
    add_variable(canonical_model,
                 devices,
                 Symbol("Psout_$(St)"),
                 false,
                 :nodal_balance_active;
                 lb_value = d -> 0.0,)

    return

end


function reactive_power_variables(canonical_model::CanonicalModel,
                                  devices::IS.FlattenIteratorWrapper{St}) where {St<:PSY.Storage}
    add_variable(canonical_model,
                 devices,
                 Symbol("Qst_$(St)"),
                 false,
                 :nodal_balance_reactive)

    return

end


function energy_storage_variables(canonical_model::CanonicalModel,
                                  devices::IS.FlattenIteratorWrapper{St}) where St<:PSY.Storage

    add_variable(canonical_model,
                 devices,
                 Symbol("Est_$(St)"),
                 false;
                 lb_value = d -> 0.0,)

    return

end


function storage_reservation_variables(canonical_model::CanonicalModel,
                                       devices::IS.FlattenIteratorWrapper{St}) where St<:PSY.Storage

    add_variable(canonical_model,
                 devices,
                 Symbol("Rst_$(St)"),
                 true)

    return

end


###################################################### output power constraints#################################

function active_power_constraints(canonical_model::CanonicalModel,
                                  devices::IS.FlattenIteratorWrapper{St},
                                  ::Type{BookKeeping},
                                  ::Type{S}) where {St<:PSY.Storage,
                                                                      S<:PM.AbstracPowerModel}

    range_data_in = [(PSY.get_name(s), PSY.get_inputactivepowerlimits(s)) for s in devices]
    range_data_out = [(PSY.get_name(s), PSY.get_outputactivepowerlimits(s)) for s in devices]

    device_range(canonical_model,
                 range_data_in,
                 Symbol("inputpower_range_$(St)"),
                 Symbol("Psin_$(St)"))

    device_range(canonical_model,
                range_data_out,
                Symbol("outputpower_range_$(St)"),
                Symbol("Psout_$(St)"))

    return

end

function active_power_constraints(canonical_model::CanonicalModel,
                                  devices::IS.FlattenIteratorWrapper{St},
                                  ::Type{BookKeepingwReservation},
                                  ::Type{S}) where {St<:PSY.Storage,
                                                                      S<:PM.AbstracPowerModel}

    range_data_in = [(PSY.get_name(s), PSY.get_inputactivepowerlimits(s)) for s in devices]
    range_data_out = [(PSY.get_name(s), PSY.get_outputactivepowerlimits(s)) for s in devices]

    reserve_device_semicontinuousrange(canonical_model,
                                       range_data_in,
                                       Symbol("inputpower_range_$(St)"),
                                       Symbol("Psin_$(St)"),
                                       Symbol("Rst_$(St)"))

    reserve_device_semicontinuousrange(canonical_model,
                                       range_data_out,
                                       Symbol("outputpower_range_$(St)"),
                                       Symbol("Psout_$(St)"),
                                       Symbol("Rst_$(St)"))

    return

end


"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactive_power_constraints(canonical_model::CanonicalModel,
                                   devices::IS.FlattenIteratorWrapper{St},
                                   ::Type{D},
                                   ::Type{S}) where {St<:PSY.Storage,
                                                                       D<:AbstractStorageFormulation,
                                                                       S<:PM.AbstracPowerModel}

    range_data = [(PSY.get_name(s), PSY.get_reactivepowerlimits(s)) for s in devices]

    device_range(canonical_model,
                 range_data,
                 Symbol("reactiverange_$(St)"),
                 Symbol("Qst_$(St)"))

    return

end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(canonical_model::CanonicalModel,
                            devices::IS.FlattenIteratorWrapper{St},
                            ::Type{D}) where {St<:PSY.Storage,
                                                                D<:AbstractStorageFormulation}

    storage_energy_init(canonical_model, devices)

return

end

###################################################### Energy Capacity constraints##########

function energy_capacity_constraints(canonical_model::CanonicalModel,
                                    devices::IS.FlattenIteratorWrapper{St},
                                    ::Type{D},
                                    ::Type{S}) where {St<:PSY.Storage,
                                                                        D<:AbstractStorageFormulation,
                                                                        S<:PM.AbstracPowerModel}

    range_data = [(PSY.get_name(s), PSY.get_capacity(s)) for s in devices]

    device_range(canonical_model,
                 range_data,
                 Symbol("energy_capacity_$(St)"),
                 Symbol("Est_$(St)"))
    return

end

###################################################### book keeping constraints ############

function make_efficiency_data(devices::IS.FlattenIteratorWrapper{St}) where {St<:PSY.Storage}

    names = Vector{String}(undef, length(devices))
    in_out = Vector{InOut}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        names[ix] = PSY.get_name(d)
        in_out[ix] = PSY.get_efficiency(d)
    end

    return names, in_out

end



function energy_balance_constraint(canonical_model::CanonicalModel,
                                   devices::IS.FlattenIteratorWrapper{St},
                                   ::Type{D},
                                   ::Type{S}) where {St<:PSY.Storage,
                                                            D<:AbstractStorageFormulation,
                                                            S<:PM.AbstracPowerModel}

    key = ICKey(DeviceEnergy, St)

    if !(key in keys(canonical_model.initial_conditions))
        error("Initial Conditions for $(St) Energy Constraints not in the model")
    end

    efficiency_data = make_efficiency_data(devices)

    energy_balance(canonical_model,
                   canonical_model.initial_conditions[key],
                   efficiency_data,
                   Symbol("energy_balance_$(St)"),
                   (Symbol("Psout_$(St)"), Symbol("Psin_$(St)"), Symbol("Est_$(St)")))

    return

end
