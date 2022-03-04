function update_parameter_values!(
    ::AbstractArray{T},
    ::NoAttributes,
    args...,
) where {T <: Union{Float64, PJ.ParameterRef}} end

######################## Methods to update Parameters from Time Series #####################
function _set_param_value!(
    param::AbstractArray{PJ.ParameterRef},
    value::Float64,
    name::String,
    t::Int,
)
    JuMP.set_value(param[name, t], value)
    return
end

function _set_param_value!(
    param::AbstractArray{Float64},
    value::Float64,
    name::String,
    t::Int,
)
    param[name, t] = value
    return
end

function _set_param_value!(
    param::SparseAxisArray,
    value::Float64,
    name::String,
    subcomp::String,
    t::Int,
)
    _set_parameter_value_sparse_array!(param[name, subcomp, t], value)
    return
end

function _set_parameter_value_sparse_array!(parameter::Float64, value::Float64)
    parameter = value
    return
end

function _set_parameter_value_sparse_array!(parameter::PJ.ParameterRef, value::Float64)
    JuMP.set_value(parameter, value)
    return
end

function update_parameter_values!(
    param_array::AbstractArray{T},
    attributes::TimeSeriesAttributes{U},
    ::Type{V},
    model::DecisionModel,
    ::DatasetContainer{DataFrameDataset},
) where {
    T <: Union{PJ.ParameterRef, Float64},
    U <: PSY.AbstractDeterministic,
    V <: PSY.Component,
}
    initial_forecast_time = get_current_time(model) # Function not well defined for DecisionModels
    horizon = get_time_steps(get_optimization_container(model))[end]
    components = get_available_components(V, get_system(model))
    for component in components
        name = PSY.get_name(component)
        ts_vector = get_time_series_values!(
            U,
            model,
            component,
            get_time_series_name(attributes),
            get_time_series_multiplier_id(attributes),
            initial_forecast_time,
            horizon,
        )
        for (t, value) in enumerate(ts_vector)
            _set_param_value!(param_array, value, name, t)
        end
    end
end

function update_parameter_values!(
    param_array::SparseAxisArray,
    attributes::TimeSeriesAttributes{U},
    ::Type{V},
    model::DecisionModel,
    ::DatasetContainer{DataFrameDataset},
) where {
    U <: PSY.AbstractDeterministic,
    V <: PSY.HybridSystem,
}
    initial_forecast_time = get_current_time(model) # Function not well defined for DecisionModels
    horizon = get_time_steps(get_optimization_container(model))[end]
    components = get_available_components(V, get_system(model))
    for component in components, subcomp_type in [PSY.RenewableGen, PSY.ElectricLoad]
        name = PSY.get_name(component)
        !does_subcomponent_exist(component, subcomp_type) && continue
        subcomponent = get_subcomponent(component, subcomp_type)
        ts_vector = get_time_series_values!(
            U,
            model,
            component,
            make_subsystem_time_series_name(subcomponent, get_time_series_name(attributes)),
            get_time_series_multiplier_id(attributes),
            initial_forecast_time,
            horizon,
        )
        for (t, value) in enumerate(ts_vector)
            _set_param_value!(param_array, value, name, string(subcomp_type), t)
        end
    end
end

function update_parameter_values!(
    param_array::AbstractArray{T},
    attributes::TimeSeriesAttributes{U},
    service::V,
    model::DecisionModel,
    ::DatasetContainer{DataFrameDataset},
) where {
    T <: Union{PJ.ParameterRef, Float64},
    U <: PSY.AbstractDeterministic,
    V <: PSY.Service,
}
    initial_forecast_time = get_current_time(model) # Function not well defined for DecisionModels
    horizon = get_time_steps(get_optimization_container(model))[end]
    ts_vector = get_time_series_values!(
        U,
        model,
        service,
        get_time_series_name(attributes),
        get_time_series_multiplier_id(attributes),
        initial_forecast_time,
        horizon,
    )
    service_name = PSY.get_name(service)
    for (t, value) in enumerate(ts_vector)
        _set_param_value!(param_array, value, service_name, t)
    end
end

function update_parameter_values!(
    param_array::AbstractArray{T},
    attributes::TimeSeriesAttributes{U},
    ::Type{V},
    model::EmulationModel,
    ::DatasetContainer{DataFrameDataset},
) where {T <: Union{PJ.ParameterRef, Float64}, U <: PSY.SingleTimeSeries, V <: PSY.Device}
    initial_forecast_time = get_current_time(model)
    components = get_available_components(V, get_system(model))
    for component in components
        # Note: This interface reads one single value per component at a time.
        ts_vector = get_time_series_values!(
            U,
            model,
            component,
            get_time_series_name(attributes),
            get_time_series_multiplier_id(attributes),
            initial_forecast_time,
        )
        _set_param_value!(param_array, ts_vector[1], PSY.get_name(component), 1)
    end
    return
end

function update_parameter_values!(
    param_array::AbstractArray{T},
    attributes::VariableValueAttributes,
    ::Type{<:PSY.Component},
    model::DecisionModel,
    state::DatasetContainer{DataFrameDataset},
) where {T <: Union{PJ.ParameterRef, Float64}}
    current_time = get_current_time(model)
    state_values = get_dataset_values(state, get_attribute_key(attributes))
    component_names, time = axes(param_array)
    resolution = get_resolution(model)

    state_data = get_dataset(state, get_attribute_key(attributes))
    state_timestamps = state_data.timestamps
    max_state_index = length(state_data)

    state_data_index = find_timestamp_index(state_timestamps, current_time)

    sim_timestamps = range(current_time, step=resolution, length=time[end])
    for t in time
        timestamp_ix = min(max_state_index, state_data_index + 1)
        @debug "parameter horizon is over the step" max_state_index > state_data_index + 1
        if state_timestamps[timestamp_ix] <= sim_timestamps[t]
            state_data_index = timestamp_ix
        end
        for name in component_names
            # Pass indices in this way since JuMP DenseAxisArray don't support view()
            _set_param_value!(param_array, state_values[state_data_index, name], name, t)
        end
    end
    return
end

function update_parameter_values!(
    param_array::AbstractArray{T},
    attributes::VariableValueAttributes,
    ::Type{<:PSY.Component},
    model::EmulationModel,
    state::DatasetContainer{DataFrameDataset},
) where {T <: Union{PJ.ParameterRef, Float64}}
    current_time = get_current_time(model)
    state_values = get_dataset_values(state, get_attribute_key(attributes))
    component_names, _ = axes(param_array)
    state_data = get_dataset(state, get_attribute_key(attributes))
    state_timestamps = state_data.timestamps
    state_data_index = find_timestamp_index(state_timestamps, current_time)
    for name in component_names
        # Pass indices in this way since JuMP DenseAxisArray don't support view()
        _set_param_value!(param_array, state_values[state_data_index, name], name, 1)
    end
    return
end

function update_parameter_values!(
    ::AbstractArray{T},
    ::VariableValueAttributes,
    ::Type{<:PSY.Component},
    ::EmulationModel,
    ::EmulationModelStore,
) where {T <: Union{PJ.ParameterRef, Float64}}
    error("The emulation model has parameters that can't be updated from its results")
    return
end

"""
Update parameter function an OperationModel
"""
function update_parameter_values!(
    model::OperationModel,
    key::ParameterKey{T, U},
    input::DatasetContainer{DataFrameDataset},
) where {T <: ParameterType, U <: PSY.Component}
    # Enable again for detailed debugging
    # TimerOutputs.@timeit RUN_SIMULATION_TIMER "$T $U Parameter Update" begin
    optimization_container = get_optimization_container(model)
    # Note: Do not instantite a new key here because it might not match the param keys in the container
    # if the keys have strings in the meta fields
    parameter_array = get_parameter_array(optimization_container, key)
    parameter_attributes = get_parameter_attributes(optimization_container, key)
    update_parameter_values!(parameter_array, parameter_attributes, U, model, input)
    IS.@record :execution ParameterUpdateEvent(
        T,
        U,
        parameter_attributes,
        get_current_timestamp(model),
        get_name(model),
    )
    # end
    return
end

function update_parameter_values!(
    model::OperationModel,
    key::ParameterKey{IntegralLimitParameter, U},
    input::DatasetContainer{DataFrameDataset},
) where {T <: ParameterType, U <: PSY.Component}
    # Enable again for detailed debugging
    # TimerOutputs.@timeit RUN_SIMULATION_TIMER "$T $U Parameter Update" begin
    optimization_container = get_optimization_container(model)
    # Note: Do not instantite a new key here because it might not match the param keys in the container
    # if the keys have strings in the meta fields
    parameter_array = get_parameter_array(optimization_container, key)
    parameter_attributes = get_parameter_attributes(optimization_container, key)
    internal = get_internal(model)
    execution_count = internal.execution_count
    current_time = get_current_time(model)
    state_values = get_dataset_values(input, get_attribute_key(parameter_attributes))
    component_names, time = axes(parameter_array)
    resolution = get_resolution(model)
    interval_time_steps = Int(get_interval(model.internal.store_parameters)/resolution)
    state_data = get_dataset(input, get_attribute_key(parameter_attributes))
    state_timestamps = state_data.timestamps
    max_state_index = length(state_data)

    state_data_index = find_timestamp_index(state_timestamps, current_time)
    sim_timestamps = range(current_time, step=resolution, length=time[end])
    old_parameter_values = JuMP.value.(parameter_array)

    for t in time
        timestamp_ix = min(max_state_index, state_data_index + 1)
        @debug "parameter horizon is over the step" max_state_index > state_data_index + 1
        if state_timestamps[timestamp_ix] <= sim_timestamps[t]
            state_data_index = timestamp_ix
        end
        for name in component_names
            if execution_count == 0 || t > time[end]-interval_time_steps
                # Pass indices in this way since JuMP DenseAxisArray don't support view()
                _set_param_value!(parameter_array, state_values[state_data_index, name], name, t)
            else
                _set_param_value!(parameter_array, old_parameter_values[name, t+interval_time_steps], name, t)
            end
        end
    end

    IS.@record :execution ParameterUpdateEvent(
        T,
        U,
        parameter_attributes,
        get_current_timestamp(model),
        get_name(model),
    )
    end
    return
end

"""
Update parameter function an OperationModel
"""
function update_parameter_values!(
    model::OperationModel,
    key::ParameterKey{T, U},
    input::DatasetContainer{DataFrameDataset},
) where {T <: ParameterType, U <: PSY.Service}
    # Enable again for detailed debugging
    # TimerOutputs.@timeit RUN_SIMULATION_TIMER "$T $U Parameter Update" begin
    optimization_container = get_optimization_container(model)
    # Note: Do not instantite a new key here because it might not match the param keys in the container
    # if the keys have strings in the meta fields
    param_array = get_parameter_array(optimization_container, key)
    parameter_attributes = get_parameter_attributes(optimization_container, key)
    service = PSY.get_component(U, get_system(model), key.meta)
    update_parameter_values!(param_array, parameter_attributes, service, model, input)
    IS.@record :execution ParameterUpdateEvent(
        T,
        U,
        parameter_attributes,
        get_current_timestamp(model),
        get_name(model),
    )
    #end
    return
end

function _set_param_value!(
    param::AbstractArray{Vector{NTuple{2, Float64}}},
    value::Vector{NTuple{2, Float64}},
    name::String,
    t::Int,
)
    param[name, t] = value
    return
end

function update_parameter_values!(
    param_array::AbstractArray{Vector{NTuple{2, Float64}}},
    attributes::CostFunctionAttributes,
    ::Type{V},
    model::DecisionModel,
    ::DatasetContainer{DataFrameDataset},
) where {V <: PSY.Component}
    initial_forecast_time = get_current_time(model) # Function not well defined for DecisionModels
    time_steps = get_time_steps(get_optimization_container(model))
    horizon = time_steps[end]
    container = get_optimization_container(model)
    if is_synchronized(container)
        obj_func = get_cost_function(container)
        set_synchronized_status(obj_func, false)
        reset_variant_terms(obj_func)
    end
    components = get_available_components(V, get_system(model))

    for component in components
        if _has_variable_cost_parameter(component)
            name = PSY.get_name(component)
            ts_vector = PSY.get_variable_cost(
                component,
                PSY.get_operation_cost(component);
                start_time=initial_forecast_time,
                len=horizon,
            )
            variable_cost_forecast_values = TimeSeries.values(ts_vector)
            for (t, value) in enumerate(variable_cost_forecast_values)
                if attributes.uses_compact_power
                    value, _ = _convert_variable_cost(value)
                end
                _set_param_value!(param_array, PSY.get_cost(value), name, t)
                update_variable_cost!(container, param_array, attributes, component, t)
            end
        end
    end
    return
end

_has_variable_cost_parameter(component::PSY.Component) =
    _has_variable_cost_parameter(PSY.get_operation_cost(component))
_has_variable_cost_parameter(::PSY.MarketBidCost) = true
_has_variable_cost_parameter(::T) where {T <: PSY.OperationalCost} = false
