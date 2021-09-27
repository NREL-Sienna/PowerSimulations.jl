function update_initial_conditions(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {T <: InitialCondition{InitialTimeDurationOn, Union{Float64, PJ.ParameterRef}}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_aux_variable(store, TimeDurationOn(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function update_initial_conditions(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {T <: InitialCondition{InitialTimeDurationOff, Union{Float64, PJ.ParameterRef}}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_aux_variable(store, TimeDurationOff(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function update_initial_conditions(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {T <: InitialCondition{DevicePower, Union{Float64, PJ.ParameterRef}}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_variable(store, ActivePowerVariable(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function update_initial_conditions(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {T <: InitialCondition{DeviceStatus, PJ.ParameterRef}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_variable(store, OnVariable(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function update_initial_conditions(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {T <: InitialCondition{DeviceAboveMinPower, Union{Float64, PJ.ParameterRef}}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_variable(store, PowerAboveMinimumVariable(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function update_initial_conditions(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {T <: InitialCondition{InitialEnergyLevel, Union{Float64, PJ.ParameterRef}}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_variable(store, EnergyVariable(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function update_initial_conditions(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {T <: InitialCondition{InitialEnergyLevelUp, Union{Float64, PJ.ParameterRef}}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_variable(store, EnergyVariableUp(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function update_initial_conditions(
    ic_vector::Vector{T},
    store::InMemoryModelStore,
    ::Dates.Period,
) where {T <: InitialCondition{InitialEnergyLevelDown, Union{Float64, PJ.ParameterRef}}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_variable(store, EnergyVariableDown(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function update_initial_conditions!(
    model::OperationModel,
    key::ICKey{T, U},
) where {T <: InitialConditionType, U <: PSY.Component}
    # TODO: Add Recorder Event here
    container = get_optimization_container(model)
    interval = get_interval(model.internal.store_parameters)
    ini_conditions_vector = get_initial_condition(container, key)
    update_initial_conditions(ini_conditions_vector, model.store, interval)
end
