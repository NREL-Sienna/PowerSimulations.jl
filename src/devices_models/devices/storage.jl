abstract type AbstractStorageFormulation <: AbstractDeviceFormulation end
struct BookKeeping <: AbstractStorageFormulation end
struct BookKeepingwReservation <: AbstractStorageFormulation end
#################################################Storage Variables#################################

function active_power_variables!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{St}) where {St<:PSY.Storage}
    add_variable(psi_container,
                 devices,
                 Symbol("Pin_$(St)"),
                 false,
                 :nodal_balance_active,
                 -1.0;
                 lb_value = d -> 0.0,)
    add_variable(psi_container,
                 devices,
                 Symbol("Pout_$(St)"),
                 false,
                 :nodal_balance_active;
                 lb_value = d -> 0.0,)
    return
end


function reactive_power_variables!(psi_container::PSIContainer,
                                  devices::IS.FlattenIteratorWrapper{St}) where {St<:PSY.Storage}
    add_variable(psi_container,
                 devices,
                 Symbol("Q_$(St)"),
                 false,
                 :nodal_balance_reactive)
    return
end


function energy_storage_variables!(psi_container::PSIContainer,
                                  devices::IS.FlattenIteratorWrapper{St}) where St<:PSY.Storage
    add_variable(psi_container,
                 devices,
                 Symbol("E_$(St)"),
                 false;
                 lb_value = d -> 0.0,)
    return
end


function storage_reservation_variables!(psi_container::PSIContainer,
                                       devices::IS.FlattenIteratorWrapper{St}) where St<:PSY.Storage
    add_variable(psi_container,
                 devices,
                 Symbol("R_$(St)"),
                 true)
    return
end


###################################################### output power constraints#################################

function active_power_constraints!(psi_container::PSIContainer,
                                   devices::IS.FlattenIteratorWrapper{St},
                                   ::Type{BookKeeping},
                                   ::Type{S}) where {St<:PSY.Storage,
                                                     S<:PM.AbstractPowerModel}
    names = Vector{String}(undef, length(devices))
    limit_values_in = Vector{MinMax}(undef, length(devices))
    limit_values_out = Vector{MinMax}(undef, length(devices))
    additional_terms_ub = Vector{Vector{Symbol}}(undef, length(devices))
    additional_terms_lb = Vector{Vector{Symbol}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        limit_values_in[ix] = PSY.get_inputactivepowerlimits(d)
        limit_values_out[ix] = PSY.get_outputactivepowerlimits(d)
        names[ix] = PSY.get_name(d)
        services_ub = Vector{Symbol}()
        services_lb = Vector{Symbol}()
        for service in PSY.get_services(d)
            SR = typeof(service)
            push!(services_ub, Symbol("R$(PSY.get_name(service))_$SR"))
        end
        additional_terms_ub[ix] = services_ub
        additional_terms_lb[ix] = services_lb
    end

    device_range(psi_container,
                 DeviceRange(names, limit_values_out, additional_terms_ub, Vector{Vector{Symbol}}()),
                 Symbol("outputpower_range_$(St)"),
                 Symbol("Pout_$(St)"))

    device_range(psi_container,
                 DeviceRange(names, limit_values_in, Vector{Vector{Symbol}}(), additional_terms_lb),
                 Symbol("inputpower_range_$(St)"),
                 Symbol("Pin_$(St)"))
    return
end

function active_power_constraints!(psi_container::PSIContainer,
                                   devices::IS.FlattenIteratorWrapper{St},
                                   ::Type{BookKeepingwReservation},
                                   ::Type{S}) where {St<:PSY.Storage,
                                                     S<:PM.AbstractPowerModel}
    names = Vector{String}(undef, length(devices))
    limit_values_in = Vector{MinMax}(undef, length(devices))
    limit_values_out = Vector{MinMax}(undef, length(devices))
    additional_terms_ub = Vector{Vector{Symbol}}(undef, length(devices))
    additional_terms_lb = Vector{Vector{Symbol}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        limit_values_in[ix] = PSY.get_inputactivepowerlimits(d)
        limit_values_out[ix] = PSY.get_outputactivepowerlimits(d)
        names[ix] = PSY.get_name(d)
        services_ub = Vector{Symbol}()
        services_lb = Vector{Symbol}()
        for service in PSY.get_services(d)
            SR = typeof(service)
            push!(services_ub, Symbol("R$(PSY.get_name(service))_$SR"))
        end
        additional_terms_ub[ix] = services_ub
        additional_terms_lb[ix] = services_lb
    end                                              
    #range_data_in = [(PSY.get_name(s), PSY.get_inputactivepowerlimits(s)) for s in devices]
    #range_data_out = [(PSY.get_name(s), PSY.get_outputactivepowerlimits(s)) for s in devices]

    reserve_device_semicontinuousrange(psi_container,
                                       DeviceRange(names, limit_values_in, Vector{Vector{Symbol}}(), additional_terms_lb),
                                       Symbol("inputpower_range_$(St)"),
                                       Symbol("Pin_$(St)"),
                                       Symbol("R_$(St)"))

    reserve_device_semicontinuousrange(psi_container,
                                       DeviceRange(names, limit_values_out, Vector{Vector{Symbol}}(), additional_terms_lb),
                                       Symbol("outputpower_range_$(St)"),
                                       Symbol("Pout_$(St)"),
                                       Symbol("R_$(St)"))
    return
end


"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactive_power_constraints!(psi_container::PSIContainer,
                                   devices::IS.FlattenIteratorWrapper{St},
                                   ::Type{D},
                                   ::Type{S}) where {St<:PSY.Storage,
                                                     D<:AbstractStorageFormulation,
                                                     S<:PM.AbstractPowerModel}
    names = Vector{String}(undef, length(devices))
    limit_values = Vector{MinMax}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limit_values[ix] = PSY.get_reactivepowerlimits(d)
        names[ix] = PSY.get_name(d)
    end

    device_range(psi_container,
                 DeviceRange(names, limit_values, Vector{Vector{Symbol}}(), Vector{Vector{Symbol}}()),
                 Symbol("reactiverange_$(St)"),
                 Symbol("Q_$(St)"))
    return
end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(psi_container::PSIContainer,
                            devices::IS.FlattenIteratorWrapper{St},
                            ::Type{D}) where {St<:PSY.Storage,
                                                                D<:AbstractStorageFormulation}
    storage_energy_init(psi_container, devices)
    return
end

###################################################### Energy Capacity constraints##########

function energy_capacity_constraints!(psi_container::PSIContainer,
                                    devices::IS.FlattenIteratorWrapper{St},
                                    ::Type{D},
                                    ::Type{S}) where {St<:PSY.Storage,
                                                                        D<:AbstractStorageFormulation,
                                                                        S<:PM.AbstractPowerModel}
    names = Vector{String}(undef, length(devices))
    limit_values = Vector{MinMax}(undef, length(devices))
    additional_terms_ub = Vector{Vector{Symbol}}(undef, length(devices))
    additional_terms_lb = Vector{Vector{Symbol}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        limit_values[ix] = PSY.get_capacity(d)
        names[ix] = PSY.get_name(d)
        services_ub = Vector{Symbol}()
        services_lb = Vector{Symbol}()
        for service in PSY.get_services(d)
            SR = typeof(service)
            push!(services_ub, Symbol("R$(PSY.get_name(service))_$SR"))
        end
        additional_terms_ub[ix] = services_ub
        additional_terms_lb[ix] = services_lb
    end

    names = Vector{String}(undef, length(devices))
    limit_values = Vector{MinMax}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        limit_values[ix] = PSY.get_capacity(d)
        names[ix] = PSY.get_name(d)
    end

    device_range(psi_container,
                 DeviceRange(names, limit_values, additional_terms_ub, additional_terms_lb),
                 Symbol("energy_capacity_$(St)"),
                 Symbol("E_$(St)"))
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



function energy_balance_constraint!(psi_container::PSIContainer,
                                   devices::IS.FlattenIteratorWrapper{St},
                                   ::Type{D},
                                   ::Type{S}) where {St<:PSY.Storage,
                                                            D<:AbstractStorageFormulation,
                                                            S<:PM.AbstractPowerModel}
    key = ICKey(DeviceEnergy, St)
    if !(key in keys(psi_container.initial_conditions))
        error("Initial Conditions for $(St) Energy Constraints not in the model")
    end

    efficiency_data = make_efficiency_data(devices)

    energy_balance(psi_container,
                   psi_container.initial_conditions[key],
                   efficiency_data,
                   Symbol("energy_balance_$(St)"),
                   (Symbol("Pout_$(St)"), Symbol("Pin_$(St)"), Symbol("E_$(St)")))
    return
end
