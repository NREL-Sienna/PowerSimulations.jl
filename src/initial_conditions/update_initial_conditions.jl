function _update_initial_conditions!(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {
    T <:
    InitialCondition{InitialTimeDurationOn, S},
} where {S <: Union{Float64, PJ.ParameterRef}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_aux_variable_value(store, TimeDurationOn(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function _update_initial_conditions!(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {
    T <: InitialCondition{
        InitialTimeDurationOff,
        S,
    },
} where {S <: Union{Float64, PJ.ParameterRef}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_aux_variable_value(store, TimeDurationOff(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function _update_initial_conditions!(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {T <: InitialCondition{DevicePower, S}} where {S <: Union{Float64, PJ.ParameterRef}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_variable_value(store, ActivePowerVariable(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function _update_initial_conditions!(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {
    T <: InitialCondition{DeviceStatus, S},
} where {S <: Union{Float64, PJ.ParameterRef}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_variable_value(store, OnVariable(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function _update_initial_conditions!(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {
    T <:
    InitialCondition{DeviceAboveMinPower, S},
} where {S <: Union{Float64, PJ.ParameterRef}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values =
            get_variable_value(store, PowerAboveMinimumVariable(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function _update_initial_conditions!(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {
    T <:
    InitialCondition{InitialEnergyLevel, S},
} where {S <: Union{Float64, PJ.ParameterRef}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_variable_value(store, EnergyVariable(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function _update_initial_conditions!(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {
    T <:
    InitialCondition{InitialEnergyLevelUp, S},
} where {S <: Union{Float64, PJ.ParameterRef}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_variable_value(store, EnergyVariableUp(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function _update_initial_conditions!(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {
    T <: InitialCondition{
        InitialEnergyLevelDown,
        S,
    },
} where {S <: Union{Float64, PJ.ParameterRef}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_variable_value(store, EnergyVariableDown(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function update_initial_conditions!(
    model::OperationModel,
    key::ICKey{T, U},
    source # Store or State are used in simulations by default
) where {T <: InitialConditionType, U <: PSY.Component}
    container = get_optimization_container(model)
    interval = get_interval(model.internal.store_parameters)
    ini_conditions_vector = get_initial_condition(container, key)
    timestamp = get_current_timestamp(model)
    previous_values = get_condition.(ini_conditions_vector)
    _update_initial_conditions!(ini_conditions_vector, source, interval)
    for (i, initial_condition) in enumerate(ini_conditions_vector)
        IS.@record :execution InitialConditionUpdateEvent(
            timestamp,
            initial_condition,
            previous_values[i],
            0,
        )
    end
end
