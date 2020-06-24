abstract type AbstractStorageFormulation <: AbstractDeviceFormulation end
struct BookKeeping <: AbstractStorageFormulation end
struct BookKeepingwReservation <: AbstractStorageFormulation end
#################################################Storage Variables#################################

function make_variable_inputs(
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::PSIContainer,
) where {T <: PSY.Storage}
    return [
        AddVariableInputs(;
            variable_name = make_variable_name(ACTIVE_POWER_IN, T),
            binary = false,
            expression_name = :nodal_balance_active,
            sign = -1.0,
            lb_value_func = x -> 0.0,
        ),
        AddVariableInputs(;
            variable_name = make_variable_name(ACTIVE_POWER_OUT, T),
            binary = false,
            expression_name = :nodal_balance_active,
            lb_value_func = x -> 0.0,
        ),
    ]
end

function make_variable_inputs(
    ::Type{ReactivePowerVariable},
    ::Type{T},
    ::PSIContainer,
) where {T <: PSY.Storage}
    return AddVariableInputs(;
        variable_name = make_variable_name(REACTIVE_POWER, T),
        binary = false,
        expression_name = :nodal_balance_reactive,
    )
end

function make_variable_inputs(
    ::Type{EnergyStorageVariable},
    ::Type{T},
    ::PSIContainer,
) where {T <: PSY.Storage}
    return AddVariableInputs(;
        variable_name = make_variable_name(ENERGY, T),
        binary = false,
        lb_value_func = x -> 0.0,
    )
end

function make_variable_inputs(
    ::Type{StorageReservationVariable},
    ::Type{T},
    ::PSIContainer,
) where {T <: PSY.Storage}
    return AddVariableInputs(;
        variable_name = make_variable_name(RESERVE, T),
        binary = true,
    )
end

################################## output power constraints#################################

function make_active_power_constraints_inputs(
    ::Type{<:PSY.Storage},
    ::Type{<:BookKeeping},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
)
    return DeviceRangeConstraintInputs(;
        range_constraint_inputs = [
            RangeConstraintInputs(;
                constraint_name = OUTPUT_POWER_RANGE,
                variable_name = ACTIVE_POWER_OUT,
                limits_func = x -> PSY.get_outputactivepowerlimits(x),
                constraint_func = device_range,
            ),
            RangeConstraintInputs(;
                constraint_name = INPUT_POWER_RANGE,
                variable_name = ACTIVE_POWER_IN,
                limits_func = x -> PSY.get_inputactivepowerlimits(x),
                constraint_func = device_range,
            ),
        ],
    )
end

function make_active_power_constraints_inputs(
    ::Type{<:PSY.Storage},
    ::Type{<:BookKeepingwReservation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
)
    return DeviceRangeConstraintInputs(;
        range_constraint_inputs = [
            RangeConstraintInputs(;
                constraint_name = OUTPUT_POWER_RANGE,
                variable_name = ACTIVE_POWER_OUT,
                bin_variable_name = RESERVE,
                limits_func = x -> PSY.get_outputactivepowerlimits(x),
                constraint_func = reserve_device_semicontinuousrange,
            ),
            RangeConstraintInputs(;
                constraint_name = INPUT_POWER_RANGE,
                variable_name = ACTIVE_POWER_IN,
                bin_variable_name = RESERVE,
                limits_func = x -> PSY.get_inputactivepowerlimits(x),
                constraint_func = reserve_device_semicontinuousrange,
            ),
        ],
    )
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
        RangeConstraintInputsInternal(
            constraint_infos,
            constraint_name(REACTIVE_RANGE, St),
            make_variable_name(REACTIVE_POWER, St),
        ),
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
        RangeConstraintInputsInternal(
            constraint_infos,
            constraint_name(ENERGY_CAPACITY, St),
            make_variable_name(ENERGY, St),
        ),
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
            make_variable_name(ACTIVE_POWER_OUT, St),
            make_variable_name(ACTIVE_POWER_IN, St),
            make_variable_name(ENERGY, St),
        ),
    )
    return
end
