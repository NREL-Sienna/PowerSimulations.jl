abstract type AbstractStorageForm<:AbstractDeviceFormulation end

struct BookKeeping<:AbstractStorageForm end

struct BookKeepingwReservation<:AbstractStorageForm end

#################################################Storage Variables#################################

function active_power_variables(canonical_model::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{St}) where {St<:PSY.Storage}

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
                                  devices::PSY.FlattenIteratorWrapper{St}) where {St<:PSY.Storage}
    add_variable(canonical_model,
                 devices,
                 Symbol("Qst_$(St)"),
                 false,
                 :nodal_balance_reactive)

    return

end


function energy_storage_variables(canonical_model::CanonicalModel,
                                  devices::PSY.FlattenIteratorWrapper{St}) where St<:PSY.Storage

    add_variable(canonical_model,
                 devices,
                 Symbol("Est_$(St)"),
                 false;
                 lb_value = d -> 0.0,)

    return

end


function storage_reservation_variables(canonical_model::CanonicalModel,
                                       devices::PSY.FlattenIteratorWrapper{St}) where St<:PSY.Storage

    add_variable(canonical_model,
                 devices,
                 Symbol("Rst_$(St)"),
                 true)

    return

end


###################################################### output power constraints#################################

function active_power_constraints(canonical_model::CanonicalModel,
                                  devices::PSY.FlattenIteratorWrapper{St},
                                  device_formulation::Type{BookKeeping},
                                  system_formulation::Type{S}) where {St<:PSY.Storage,
                                                                      S<:PM.AbstractPowerFormulation}

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
                                  devices::PSY.FlattenIteratorWrapper{St},
                                  device_formulation::Type{BookKeepingwReservation},
                                  system_formulation::Type{S}) where {St<:PSY.Storage,
                                                                      S<:PM.AbstractPowerFormulation}

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
                                   devices::PSY.FlattenIteratorWrapper{St},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S}) where {St<:PSY.Storage,
                                                                       D<:AbstractStorageForm,
                                                                       S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(s), PSY.get_reactivepowerlimits(s)) for s in devices]

    device_range(canonical_model,
                 range_data,
                 Symbol("reactiverange_$(St)"),
                 Symbol("Qst_$(St)"))

    return

end


###################################################### Energy Capacity constraints#################################

function energy_capacity_constraints(canonical_model::CanonicalModel,
                                    devices::PSY.FlattenIteratorWrapper{St},
                                    device_formulation::Type{D},
                                    system_formulation::Type{S}) where {St<:PSY.Storage,
                                                                        D<:AbstractStorageForm,
                                                                        S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(s), PSY.get_capacity(s)) for s in devices]

    device_range(canonical_model,
                 range_data,
                 Symbol("energy_capacity_$(St)"),
                 Symbol("Est_$(St)"))
    return

end

###################################################### book keeping constraints #################################

function make_efficiency_data(devices::PSY.FlattenIteratorWrapper{St}) where {St<:PSY.Storage}

    names = Vector{String}(undef, length(devices))
    in_out = Vector{InOut}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        names[ix] = PSY.get_name(d)
        in_out[ix] = PSY.get_efficiency(d)
    end

    return names, in_out

end



function energy_balance_constraint(canonical_model::CanonicalModel,
                                   devices::PSY.FlattenIteratorWrapper{St},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S}) where {St<:PSY.Storage,
                                                            D<:AbstractStorageForm,
                                                            S<:PM.AbstractPowerFormulation}

    key = Symbol("energy_$(St)")

    if !(key in keys(canonical_model.initial_conditions))
        @warn("Initial status conditions not provided. This can lead to unwanted results")
        device_name = map(x-> PSY.get_name(x), devices)
        storage_energy_init(canonical_model, devices, device_name)
    else
        storage_miss = missing_init_cond(canonical_model.initial_conditions[key], devices)
        if !isnothing(storage_miss)
            @warn("Initial status conditions not provided. This can lead to unwanted results")
            storage_energy_init(canonical_model, devices, storage_miss)
        end
    end

    efficiency_data = make_efficiency_data(devices)

    energy_balance(canonical_model,
                   canonical_model.initial_conditions[key],
                   efficiency_data,
                   Symbol("energy_balance_$(St)"),
                   (Symbol("Psout_$(St)"), Symbol("Psin_$(St)"), Symbol("Est_$(St)")))

    return

end
