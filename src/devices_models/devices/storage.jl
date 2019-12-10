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

function _device_services(constraint_data::DeviceRange,
                          index::Int64,
                          device::PSY.Storage,
                          model::DeviceModel)
    for service_model in get_services(model)
        if PSY.has_service(device, service_model.service_type)
            services = [s for s in PSY.get_services(device) if isa(s, service_model.service_type)]
            @assert !isempty(services)
            include_service!(constraint_data, index, services, service_model)
        end
    end
    return
end

###################################################### output power constraints#################################

function active_power_constraints!(psi_container::PSIContainer,
                                   devices::IS.FlattenIteratorWrapper{St},
                                   model::DeviceModel{St, BookKeeping},
                                   ::Type{S},
                                   feed_forward::Union{Nothing, AbstractAffectFeedForward}) where {St<:PSY.Storage,
                                                     S<:PM.AbstractPowerModel}
    constraint_data_in = DeviceRange(length(devices))
    constraint_data_out = DeviceRange(length(devices))
    for (ix, d) in enumerate(devices)
        constraint_data_in.values[ix] = PSY.get_inputactivepowerlimits(d)
        constraint_data_out.values[ix] = PSY.get_outputactivepowerlimits(d)
        constraint_data_in.names[ix] = constraint_data_out.names[ix] = PSY.get_name(d)
        #_device_services(constraint_data, ix, d, model)
    end

    device_range(psi_container,
                 constraint_data_out,
                 Symbol("outputpower_range_$(St)"),
                 Symbol("Pout_$(St)"))

    device_range(psi_container,
                 constraint_data_in,
                 Symbol("inputpower_range_$(St)"),
                 Symbol("Pin_$(St)"))
    return
end

function active_power_constraints!(psi_container::PSIContainer,
                                   devices::IS.FlattenIteratorWrapper{St},
                                   model::DeviceModel{St, BookKeepingwReservation},
                                   ::Type{S},
                                   feed_forward::Union{Nothing, AbstractAffectFeedForward}) where {St<:PSY.Storage,
                                                     S<:PM.AbstractPowerModel}
    constraint_data_in = DeviceRange(length(devices))
    constraint_data_out = DeviceRange(length(devices))
    for (ix, d) in enumerate(devices)
        constraint_data_in.values[ix] = PSY.get_inputactivepowerlimits(d)
        constraint_data_out.values[ix] = PSY.get_outputactivepowerlimits(d)
        constraint_data_in.names[ix] = constraint_data_out.names[ix] = PSY.get_name(d)
        #_device_services(constraint_data, ix, d, model)
    end
    reserve_device_semicontinuousrange(psi_container,
                                       constraint_data_in,
                                       Symbol("inputpower_range_$(St)"),
                                       Symbol("Pin_$(St)"),
                                       Symbol("R_$(St)"))

    reserve_device_semicontinuousrange(psi_container,
                                       constraint_data_out,
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
                                   model::DeviceModel{St, D},
                                   ::Type{S},
                                   feed_forward::Union{Nothing, AbstractAffectFeedForward}) where {St<:PSY.Storage,
                                                     D<:AbstractStorageFormulation,
                                                     S<:PM.AbstractPowerModel}
    constraint_data = DeviceRange(length(devices))
    for (ix, d) in enumerate(devices)
        constraint_data.values[ix] = PSY.get_reactivepowerlimits(d)
        constraint_data.names[ix] = PSY.get_name(d)
        #_device_services(constraint_data, ix, d, model)
        # Uncomment when we implement reactive power services
    end

    device_range(psi_container,
                constraint_data,
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
                                    model::DeviceModel{St, D},
                                    ::Type{S},
                                    feed_forward::Union{Nothing, AbstractAffectFeedForward}) where {St<:PSY.Storage,
                                                                        D<:AbstractStorageFormulation,
                                                                        S<:PM.AbstractPowerModel}
    constraint_data = DeviceRange(length(devices))
    for (ix, d) in enumerate(devices)
        constraint_data.values[ix] = PSY.get_capacity(d)
        constraint_data.names[ix] = PSY.get_name(d)
        #_device_services(constraint_data, ix, d, model)
        # Uncomment when we implement reactive power services
    end

    device_range(psi_container,
                 constraint_data,
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
                                   ::Type{S},
                                   feed_forward::Union{Nothing, AbstractAffectFeedForward}) where {St<:PSY.Storage,
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
