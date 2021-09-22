function update_initial_conditions(
    ::Vector{T},
    store::EmulationModelOptimizerResults,
    elapsed_period::Dates.Period,
) where {T <: InitialCondition{InitialTimeDurationOn, PJ.ParameterRef}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_aux_variable(store, TimeDurationOn(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function update_initial_conditions(
    ::Vector{T},
    store::EmulationModelOptimizerResults,
    ::Dates.Period,
) where {T <: InitialCondition{InitialTimeDurationOff, PJ.ParameterRef}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_aux_variable(store, TimeDurationOff(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function update_initial_conditions(
    ::Vector{T},
    store::EmulationModelOptimizerResults,
    ::Dates.Period,
) where {T <: InitialCondition{DevicePower, PJ.ParameterRef}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_variable(store, ActivePowerVariable(), get_component_type(ic))
        set_ic_quantity!(ic, values[index, get_component_name(ic)])
    end
    return
end

function update_initial_conditions(
    ::Vector{T},
    store::EmulationModelOptimizerResults,
    ::Dates.Period,
) where {T <: InitialCondition{DeviceStatus, PJ.ParameterRef}}
    index = store.data.last_recorded_row
    for ic in ic_vector
        values = get_aux_variable(store, OnVariable(), get_component_type(ic))
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
    update_initial_conditions(ini_conditions_vector, store, interval)
end
