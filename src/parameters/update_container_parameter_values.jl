function _update_parameter_values!(
    ::AbstractArray{T},
    ::NoAttributes,
    args...,
) where {T <: Union{Float64, JuMP.VariableRef}} end

######################## Methods to update Parameters from Time Series #####################
function _set_param_value!(param::JuMPVariableMatrix, value::Float64, name::String, t::Int)
    fix_parameter_value(param[name, t], value)
    return
end

function _set_param_value!(
    param::DenseAxisArray{Vector{NTuple{2, Float64}}},
    value::Vector{NTuple{2, Float64}},
    name::String,
    t::Int,
)
    param[name, t] = value
    return
end

function _set_param_value!(param::JuMPFloatArray, value::Float64, name::String, t::Int)
    param[name, t] = value
    return
end

function _update_parameter_values!(
    parameter_array::AbstractArray{T},
    attributes::TimeSeriesAttributes{U},
    ::Type{V},
    model::DecisionModel,
    ::DatasetContainer{InMemoryDataset},
) where {
    T <: Union{JuMP.VariableRef, Float64},
    U <: PSY.AbstractDeterministic,
    V <: PSY.Component,
}
    initial_forecast_time = get_current_time(model) # Function not well defined for DecisionModels
    horizon = get_time_steps(get_optimization_container(model))[end]
    ts_name = get_time_series_name(attributes)
    multiplier_id = get_time_series_multiplier_id(attributes)
    subsystem = get_subsystem(attributes)
    template = get_template(model)
    if isempty(subsystem)
        device_model = get_model(template, V)
    else
        device_model = get_model(template, V, subsystem)
    end
    components = get_available_components(device_model, get_system(model))
    ts_uuids = Set{String}()
    for component in components
        ts_uuid = string(IS.get_time_series_uuid(U, component, ts_name))
        if !(ts_uuid in ts_uuids)
            ts_vector = get_time_series_values!(
                U,
                model,
                component,
                ts_name,
                multiplier_id,
                initial_forecast_time,
                horizon,
            )
            for (t, value) in enumerate(ts_vector)
                if !isfinite(value)
                    error("The value for the time series $(ts_name) is not finite. \
                          Check that the data in the time series is valid.")
                end
                _set_param_value!(parameter_array, value, ts_uuid, t)
            end
            push!(ts_uuids, ts_uuid)
        end
    end
end

function _update_parameter_values!(
    parameter_array::AbstractArray{T},
    attributes::TimeSeriesAttributes{U},
    service::V,
    model::DecisionModel,
    ::DatasetContainer{InMemoryDataset},
) where {
    T <: Union{JuMP.VariableRef, Float64},
    U <: PSY.AbstractDeterministic,
    V <: PSY.Service,
}
    initial_forecast_time = get_current_time(model) # Function not well defined for DecisionModels
    horizon = get_time_steps(get_optimization_container(model))[end]
    ts_name = get_time_series_name(attributes)
    ts_uuid = string(IS.get_time_series_uuid(U, service, ts_name))
    ts_vector = get_time_series_values!(
        U,
        model,
        service,
        get_time_series_name(attributes),
        get_time_series_multiplier_id(attributes),
        initial_forecast_time,
        horizon,
    )
    for (t, value) in enumerate(ts_vector)
        if !isfinite(value)
            error("The value for the time series $(ts_name) is not finite. \
                  Check that the data in the time series is valid.")
        end
        _set_param_value!(parameter_array, value, ts_uuid, t)
    end
end

function _update_parameter_values!(
    parameter_array::AbstractArray{T},
    attributes::TimeSeriesAttributes{U},
    ::Type{V},
    model::EmulationModel,
    ::DatasetContainer{InMemoryDataset},
) where {T <: Union{JuMP.VariableRef, Float64}, U <: PSY.SingleTimeSeries, V <: PSY.Device}
    initial_forecast_time = get_current_time(model)
    template = get_template(model)
    device_model = get_model(template, V)
    components = get_available_components(device_model, get_system(model))
    ts_name = get_time_series_name(attributes)
    ts_uuids = Set{String}()
    for component in components
        ts_uuid = string(IS.get_time_series_uuid(U, component, ts_name))
        if !(ts_uuid in ts_uuids)
            # Note: This interface reads one single value per component at a time.
            value = get_time_series_values!(
                U,
                model,
                component,
                get_time_series_name(attributes),
                get_time_series_multiplier_id(attributes),
                initial_forecast_time,
            )[1]
            if !isfinite(value)
                error("The value for the time series $(ts_name) is not finite. \
                      Check that the data in the time series is valid.")
            end
            _set_param_value!(parameter_array, value, ts_uuid, 1)
            push!(ts_uuids, ts_uuid)
        end
    end
    return
end

function _update_parameter_values!(
    parameter_array::AbstractArray{T},
    attributes::VariableValueAttributes,
    ::Type{<:PSY.Device},
    model::DecisionModel,
    state::DatasetContainer{InMemoryDataset},
) where {T <: Union{JuMP.VariableRef, Float64}}
    current_time = get_current_time(model)
    state_values = get_dataset_values(state, get_attribute_key(attributes))
    component_names, time = axes(parameter_array)
    model_resolution = get_resolution(model)
    state_data = get_dataset(state, get_attribute_key(attributes))
    state_timestamps = state_data.timestamps
    max_state_index = get_num_rows(state_data)
    if model_resolution < state_data.resolution
        t_step = 1
    else
        t_step = model_resolution ÷ state_data.resolution
    end
    state_data_index = find_timestamp_index(state_timestamps, current_time)
    sim_timestamps = range(current_time; step = model_resolution, length = time[end])
    for t in time
        timestamp_ix = min(max_state_index, state_data_index + t_step)
        @debug "parameter horizon is over the step" max_state_index > state_data_index + 1
        if state_timestamps[timestamp_ix] <= sim_timestamps[t]
            state_data_index = timestamp_ix
        end
        for name in component_names
            # Pass indices in this way since JuMP DenseAxisArray don't support view()
            state_value = state_values[name, state_data_index]
            if !isfinite(state_value)
                error(
                    "The value for the system state used in $(encode_key_as_string(get_attribute_key(attributes))) is not a finite value $(state_value) \
                     This is commonly caused by referencing a state value at a time when such decision hasn't been made. \
                     Consider reviewing your models' horizon and interval definitions",
                )
            end
            _set_param_value!(parameter_array, state_value, name, t)
        end
    end
    return
end

function _update_parameter_values!(
    parameter_array::AbstractArray{T},
    attributes::VariableValueAttributes,
    ::PSY.Reserve,
    model::DecisionModel,
    state::DatasetContainer{InMemoryDataset},
) where {T <: Union{JuMP.VariableRef, Float64}}
    current_time = get_current_time(model)
    state_values = get_dataset_values(state, get_attribute_key(attributes))
    component_names, time = axes(parameter_array)
    model_resolution = get_resolution(model)
    state_data = get_dataset(state, get_attribute_key(attributes))
    state_timestamps = state_data.timestamps
    max_state_index = get_num_rows(state_data)
    if model_resolution < state_data.resolution
        t_step = 1
    else
        t_step = model_resolution ÷ state_data.resolution
    end
    state_data_index = find_timestamp_index(state_timestamps, current_time)
    sim_timestamps = range(current_time; step = model_resolution, length = time[end])
    for t in time
        timestamp_ix = min(max_state_index, state_data_index + t_step)
        @debug "parameter horizon is over the step" max_state_index > state_data_index + 1
        if state_timestamps[timestamp_ix] <= sim_timestamps[t]
            state_data_index = timestamp_ix
        end
        for name in component_names
            # Pass indices in this way since JuMP DenseAxisArray don't support view()
            state_value = state_values[name, state_data_index]
            if !isfinite(state_value)
                error(
                    "The value for the system state used in $(encode_key_as_string(get_attribute_key(attributes))) is not a finite value $(state_value) \
                     This is commonly caused by referencing a state value at a time when such decision hasn't been made. \
                     Consider reviewing your models' horizon and interval definitions",
                )
            end
            _set_param_value!(parameter_array, state_value, name, t)
        end
    end
    return
end

function _update_parameter_values!(
    parameter_array::AbstractArray{T},
    attributes::VariableValueAttributes{VariableKey{OnVariable, U}},
    ::Type{U},
    model::DecisionModel,
    state::DatasetContainer{InMemoryDataset},
) where {T <: Union{JuMP.VariableRef, Float64}, U <: PSY.Device}
    current_time = get_current_time(model)
    state_values = get_dataset_values(state, get_attribute_key(attributes))
    component_names, time = axes(parameter_array)
    model_resolution = get_resolution(model)
    state_data = get_dataset(state, get_attribute_key(attributes))
    state_timestamps = state_data.timestamps
    max_state_index = get_num_rows(state_data)
    if model_resolution < state_data.resolution
        t_step = 1
    else
        t_step = model_resolution ÷ state_data.resolution
    end
    state_data_index = find_timestamp_index(state_timestamps, current_time)

    sim_timestamps = range(current_time; step = model_resolution, length = time[end])
    for t in time
        timestamp_ix = min(max_state_index, state_data_index + t_step)
        @debug "parameter horizon is over the step" max_state_index > state_data_index + 1
        if state_timestamps[timestamp_ix] <= sim_timestamps[t]
            state_data_index = timestamp_ix
        end
        for name in component_names
            # Pass indices in this way since JuMP DenseAxisArray don't support view()
            value = round(state_values[name, state_data_index])
            @assert 0.0 <= value <= 1.0
            if !isfinite(value)
                error(
                    "The value for the system state used in $(encode_key_as_string(get_attribute_key(attributes))) is not a finite value $(value) \
                     This is commonly caused by referencing a state value at a time when such decision hasn't been made. \
                     Consider reviewing your models' horizon and interval definitions",
                )
            end
            _set_param_value!(parameter_array, value, name, t)
        end
    end
    return
end

function _update_parameter_values!(
    parameter_array::AbstractArray{T},
    attributes::VariableValueAttributes,
    ::Type{<:PSY.Component},
    model::EmulationModel,
    state::DatasetContainer{InMemoryDataset},
) where {T <: Union{JuMP.VariableRef, Float64}}
    current_time = get_current_time(model)
    state_values = get_dataset_values(state, get_attribute_key(attributes))
    component_names, _ = axes(parameter_array)
    state_data = get_dataset(state, get_attribute_key(attributes))
    state_timestamps = state_data.timestamps
    state_data_index = find_timestamp_index(state_timestamps, current_time)
    for name in component_names
        # Pass indices in this way since JuMP DenseAxisArray don't support view()
        _set_param_value!(parameter_array, state_values[name, state_data_index], name, 1)
    end
    return
end

function _update_parameter_values!(
    parameter_array::AbstractArray{T},
    attributes::VariableValueAttributes{VariableKey{OnVariable, U}},
    ::Type{<:PSY.Component},
    model::EmulationModel,
    state::DatasetContainer{InMemoryDataset},
) where {T <: Union{JuMP.VariableRef, Float64}, U <: PSY.Component}
    current_time = get_current_time(model)
    state_values = get_dataset_values(state, get_attribute_key(attributes))
    component_names, _ = axes(parameter_array)
    state_data = get_dataset(state, get_attribute_key(attributes))
    state_timestamps = state_data.timestamps
    state_data_index = find_timestamp_index(state_timestamps, current_time)
    for name in component_names
        # Pass indices in this way since JuMP DenseAxisArray don't support view()
        value = round(state_values[name, state_data_index])
        @assert 0.0 <= value <= 1.0
        if !isfinite(value)
            error(
                "The value for the system state used in $(encode_key_as_string(get_attribute_key(attributes))) is not a finite value $(value) \
                 This is commonly caused by referencing a state value at a time when such decision hasn't been made. \
                 Consider reviewing your models' horizon and interval definitions",
            )
        end
        _set_param_value!(parameter_array, value, name, 1)
    end
    return
end

function _update_parameter_values!(
    ::AbstractArray{T},
    ::VariableValueAttributes,
    ::Type{<:PSY.Component},
    ::EmulationModel,
    ::EmulationModelStore,
) where {T <: Union{JuMP.VariableRef, Float64}}
    error("The emulation model has parameters that can't be updated from its results")
    return
end

"""
Update parameter function an OperationModel
"""
function update_container_parameter_values!(
    optimization_container::OptimizationContainer,
    model::OperationModel,
    key::ParameterKey{T, U},
    input::DatasetContainer{InMemoryDataset},
) where {T <: ParameterType, U <: PSY.Component}
    # Enable again for detailed debugging
    # TimerOutputs.@timeit RUN_SIMULATION_TIMER "$T $U Parameter Update" begin
    # Note: Do not instantite a new key here because it might not match the param keys in the container
    # if the keys have strings in the meta fields
    parameter_array = get_parameter_array(optimization_container, key)
    parameter_attributes = get_parameter_attributes(optimization_container, key)
    _update_parameter_values!(parameter_array, parameter_attributes, U, model, input)
    return
end

function update_container_parameter_values!(
    optimization_container::OptimizationContainer,
    model::OperationModel,
    key::ParameterKey{T, U},
    input::DatasetContainer{InMemoryDataset},
) where {T <: ObjectiveFunctionParameter, U <: PSY.Component}
    # Note: Do not instantite a new key here because it might not match the param keys in the container
    # if the keys have strings in the meta fields
    parameter_array = get_parameter_array(optimization_container, key)
    # Multiplier is only needed for the objective function since `_update_parameter_values!` also updates the objective function
    parameter_multiplier = get_parameter_multiplier_array(optimization_container, key)
    parameter_attributes = get_parameter_attributes(optimization_container, key)
    _update_parameter_values!(
        parameter_array,
        parameter_multiplier,
        parameter_attributes,
        U,
        model,
        input,
    )
    return
end

function update_container_parameter_values!(
    optimization_container::OptimizationContainer,
    model::OperationModel,
    key::ParameterKey{T, U},
    input::DatasetContainer{InMemoryDataset},
) where {T <: ObjectiveFunctionParameter, U <: PSY.Service}
    # Note: Do not instantite a new key here because it might not match the param keys in the container
    # if the keys have strings in the meta fields
    parameter_array = get_parameter_array(optimization_container, key)
    # Multiplier is only needed for the objective function since `_update_parameter_values!` also updates the objective function
    parameter_multiplier = get_parameter_multiplier_array(optimization_container, key)
    parameter_attributes = get_parameter_attributes(optimization_container, key)
    _update_parameter_values!(
        parameter_array,
        parameter_multiplier,
        parameter_attributes,
        U,
        model,
        input,
    )
    return
end

function update_container_parameter_values!(
    optimization_container::OptimizationContainer,
    model::OperationModel,
    key::ParameterKey{FixValueParameter, U},
    input::DatasetContainer{InMemoryDataset},
) where {U <: PSY.Component}
    # Note: Do not instantite a new key here because it might not match the param keys in the container
    # if the keys have strings in the meta fields
    parameter_array = get_parameter_array(optimization_container, key)
    parameter_attributes = get_parameter_attributes(optimization_container, key)
    _update_parameter_values!(parameter_array, parameter_attributes, U, model, input)
    _fix_parameter_value!(optimization_container, parameter_array, parameter_attributes)
    return
end

function update_container_parameter_values!(
    optimization_container::OptimizationContainer,
    model::OperationModel,
    key::ParameterKey{FixValueParameter, U},
    input::DatasetContainer{InMemoryDataset},
) where {U <: PSY.Service}
    # Note: Do not instantite a new key here because it might not match the param keys in the container
    # if the keys have strings in the meta fields
    parameter_array = get_parameter_array(optimization_container, key)
    parameter_attributes = get_parameter_attributes(optimization_container, key)
    service = PSY.get_component(U, get_system(model), key.meta)
    @assert service !== nothing
    _update_parameter_values!(parameter_array, parameter_attributes, U, model, input)
    _fix_parameter_value!(optimization_container, parameter_array, parameter_attributes)
    return
end

function update_container_parameter_values!(
    optimization_container::OptimizationContainer,
    model::OperationModel,
    key::ParameterKey{T, U},
    input::DatasetContainer{InMemoryDataset},
) where {T <: ParameterType, U <: PSY.Service}
    # Note: Do not instantite a new key here because it might not match the param keys in the container
    # if the keys have strings in the meta fields
    parameter_array = get_parameter_array(optimization_container, key)
    parameter_attributes = get_parameter_attributes(optimization_container, key)
    service = PSY.get_component(U, get_system(model), key.meta)
    @assert service !== nothing
    _update_parameter_values!(parameter_array, parameter_attributes, service, model, input)
    return
end
