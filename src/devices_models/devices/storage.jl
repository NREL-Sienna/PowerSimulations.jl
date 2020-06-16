abstract type AbstractStorageFormulation <: AbstractDeviceFormulation end
struct BookKeeping <: AbstractStorageFormulation end
struct BookKeepingwReservation <: AbstractStorageFormulation end
#################################################Storage Variables#################################

function active_power_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
) where {St <: PSY.Storage}
    add_variable(
        psi_container,
        devices,
        variable_name(ACTIVE_POWER_IN, St),
        false,
        :nodal_balance_active,
        -1.0;
        lb_value = d -> 0.0,
    )
    add_variable(
        psi_container,
        devices,
        variable_name(ACTIVE_POWER_OUT, St),
        false,
        :nodal_balance_active;
        lb_value = d -> 0.0,
    )
    return
end

function reactive_power_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
) where {St <: PSY.Storage}
    add_variable(
        psi_container,
        devices,
        variable_name(REACTIVE_POWER, St),
        false,
        :nodal_balance_reactive,
    )
    return
end

function energy_storage_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
) where {St <: PSY.Storage}
    add_variable(
        psi_container,
        devices,
        variable_name(ENERGY, St),
        false;
        lb_value = d -> 0.0,
    )
    return
end

function storage_reservation_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
) where {St <: PSY.Storage}
    add_variable(psi_container, devices, variable_name(RESERVE, St), true)
    return
end

################################## output power constraints#################################

function active_power_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
    model::DeviceModel{St, BookKeeping},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    constraints_info_in = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    constraints_info_out = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        in_lims = PSY.get_inputactivepowerlimits(d)
        out_lims = PSY.get_outputactivepowerlimits(d)
        constraints_info_in[ix] = DeviceRangeConstraintInfo(name, in_lims)
        constraints_info_out[ix] = DeviceRangeConstraintInfo(name, out_lims)
        add_device_services!(constraints_info_in[ix], constraints_info_out[ix], d, model)
    end

    device_range(
        psi_container,
        constraints_info_out,
        constraint_name(OUTPUT_POWER_RANGE, St),
        variable_name(ACTIVE_POWER_OUT, St),
    )

    device_range(
        psi_container,
        constraints_info_in,
        constraint_name(INPUT_POWER_RANGE, St),
        variable_name(ACTIVE_POWER_IN, St),
    )
    return
end

function active_power_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
    model::DeviceModel{St, BookKeepingwReservation},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    constraints_info_in = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    constraints_info_out = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        in_lims = PSY.get_inputactivepowerlimits(d)
        out_lims = PSY.get_outputactivepowerlimits(d)
        constraints_info_in[ix] = DeviceRangeConstraintInfo(name, in_lims)
        constraints_info_out[ix] = DeviceRangeConstraintInfo(name, out_lims)
        add_device_services!(constraints_info_in[ix], constraints_info_out[ix], d, model)
    end

    reserve_device_semicontinuousrange(
        psi_container,
        constraints_info_in,
        constraint_name(INPUT_POWER_RANGE, St),
        variable_name(ACTIVE_POWER_IN, St),
        variable_name(RESERVE, St),
    )

    reserve_device_semicontinuousrange(
        psi_container,
        constraints_info_out,
        constraint_name(OUTPUT_POWER_RANGE, St),
        variable_name(ACTIVE_POWER_OUT, St),
        variable_name(RESERVE, St),
    )
    return
end

"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactive_power_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
    model::DeviceModel{St, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation, S <: PM.AbstractPowerModel}
    constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        limits = PSY.get_reactivepowerlimits(d)
        constraint_infos[ix] = DeviceRangeConstraintInfo(name, limits)
    end

    device_range(
        psi_container,
        constraint_infos,
        constraint_name(REACTIVE_RANGE, St),
        variable_name(REACTIVE_POWER, St),
    )
    return
end

########################## Make initial Conditions for a Model #############################
function initial_conditions!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
    ::Type{D},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation}
    storage_energy_init(psi_container, devices)
    return
end

############################ Energy Capacity Constraints####################################

function energy_capacity_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
    model::DeviceModel{St, D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation, S <: PM.AbstractPowerModel}
    constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        limits = PSY.get_capacity(d)
        constraint_info = DeviceRangeConstraintInfo(name, limits)
        add_device_services!(constraint_info, d, model)
        constraint_infos[ix] = constraint_info
    end

    device_range(
        psi_container,
        constraint_infos,
        constraint_name(ENERGY_CAPACITY, St),
        variable_name(ENERGY, St),
    )
    return
end

############################ book keeping constraints ######################################

function make_efficiency_data(
    devices::IS.FlattenIteratorWrapper{St},
) where {St <: PSY.Storage}
    names = Vector{String}(undef, length(devices))
    in_out = Vector{InOut}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        names[ix] = PSY.get_name(d)
        in_out[ix] = PSY.get_efficiency(d)
    end

    return names, in_out
end

function energy_balance_constraint!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{St},
    ::Type{D},
    ::Type{S},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation, S <: PM.AbstractPowerModel}
    efficiency_data = make_efficiency_data(devices)
    energy_balance(
        psi_container,
        get_initial_conditions(psi_container, ICKey(EnergyLevel, St)),
        efficiency_data,
        constraint_name(ENERGY_LIMIT, St),
        (
            variable_name(ACTIVE_POWER_OUT, St),
            variable_name(ACTIVE_POWER_IN, St),
            variable_name(ENERGY, St),
        ),
    )
    return
end
