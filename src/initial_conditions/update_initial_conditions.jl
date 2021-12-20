function update_initial_conditions!(
    model::OperationModel,
    key::ICKey{T, U},
    source, # Store or State are used in simulations by default
) where {T <: InitialConditionType, U <: PSY.Component}
    container = get_optimization_container(model)
    interval = get_interval(model.internal.store_parameters)
    model_resolution = get_resolution(model.internal.store_parameters)
    ini_conditions_vector = get_initial_condition(container, key)
    timestamp = get_current_timestamp(model)
    previous_values = get_condition.(ini_conditions_vector)
    # The implementation of specific update_initial_conditions! is located in the files
    # update_initial_conditions_in_memory_store.jl and update_initial_conditions_simulation.jl
    update_initial_conditions!(ini_conditions_vector, source, model_resolution)
    for (i, initial_condition) in enumerate(ini_conditions_vector)
        IS.@record :execution InitialConditionUpdateEvent(
            timestamp,
            initial_condition,
            previous_values[i],
            get_name(model),
        )
    end
end
