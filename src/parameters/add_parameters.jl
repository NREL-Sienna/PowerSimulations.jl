"""
Function to create a unique index of time series names for each device model. For example,
if two parameters each reference the same time series name, this function will return a
different value for each parameter entry
"""
function _create_time_series_multiplier_index(
    model,
    ::Type{T},
) where {T <: TimeSeriesParameter}
    ts_names = get_time_series_names(model)
    if length(ts_names) > 1
        ts_name = ts_names[T]
        ts_id = findfirst(x -> x == T, [k for (k, v) in ts_names if v == ts_name])
    else
        ts_id = 1
    end
    return ts_id
end

function add_parameters!(
    container::OptimizationContainer,
    ::Type{T},
    devices::U,
    model::DeviceModel{D, W},
) where {
    T <: ParameterType,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    if get_rebuild_model(get_settings(container)) && has_container_key(container, T, D)
        return
    end
    _add_parameters!(container, T(), devices, model)
    return
end

function add_parameters!(
    container::OptimizationContainer,
    ::Type{T},
    devices::U,
    model::DeviceModel{D, W},
) where {
    T <: FuelCostParameter,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    if get_rebuild_model(get_settings(container)) && has_container_key(container, T, D)
        return
    end
    _add_parameters!(container, T(), devices, model)
    return
end

function add_parameters!(
    container::OptimizationContainer,
    ::Type{T},
    ff::LowerBoundFeedforward,
    model::ServiceModel{S, W},
    devices::V,
) where {
    S <: PSY.AbstractReserve,
    T <: VariableValueParameter,
    V <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractReservesFormulation,
} where {D <: PSY.Component}
    if get_rebuild_model(get_settings(container)) && has_container_key(container, T, S)
        return
    end
    source_key = get_optimization_container_key(ff)
    _add_parameters!(container, T(), source_key, model, devices)
    return
end

function add_parameters!(
    container::OptimizationContainer,
    ::Type{T},
    service::U,
    model::ServiceModel{U, V},
) where {T <: TimeSeriesParameter, U <: PSY.Service, V <: AbstractServiceFormulation}
    if get_rebuild_model(get_settings(container)) &&
       has_container_key(container, T, U, PSY.get_name(service))
        return
    end
    _add_parameters!(container, T(), service, model)
    return
end

function add_parameters!(
    container::OptimizationContainer,
    ::Type{T},
    ff::AbstractAffectFeedforward,
    model::DeviceModel{D, W},
    devices::V,
) where {
    T <: VariableValueParameter,
    V <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    if get_rebuild_model(get_settings(container)) && has_container_key(container, T, D)
        return
    end
    source_key = get_optimization_container_key(ff)
    _add_parameters!(container, T(), source_key, model, devices)
    return
end

function add_parameters!(
    container::OptimizationContainer,
    ::Type{T},
    ff::FixValueFeedforward,
    model::DeviceModel{D, W},
    devices::V,
) where {
    T <: VariableValueParameter,
    V <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    if get_rebuild_model(get_settings(container)) && has_container_key(container, T, D)
        return
    end
    source_key = get_optimization_container_key(ff)
    _add_parameters!(container, T(), source_key, model, devices)
    _set_affected_variables!(container, T(), D, ff)
    return
end

function add_parameters!(
    container::OptimizationContainer,
    ::Type{T},
    ff::FixValueFeedforward,
    model::ServiceModel{K, W},
    devices::V,
) where {
    T <: VariableValueParameter,
    V <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractServiceFormulation,
    K <: PSY.Reserve,
} where {D <: PSY.Component}
    if get_rebuild_model(get_settings(container)) && has_container_key(container, T, D)
        return
    end
    source_key = get_optimization_container_key(ff)
    _add_parameters!(container, T(), source_key, model, devices)
    _set_affected_variables!(container, T(), K, ff)
    return
end

function _set_affected_variables!(
    container::OptimizationContainer,
    ::T,
    device_type::Type{U},
    ff::FixValueFeedforward,
) where {
    T <: VariableValueParameter,
    U <: PSY.Component,
}
    source_key = get_optimization_container_key(ff)
    var_type = get_entry_type(source_key)
    parameter_container = get_parameter(container, T(), U, "$var_type")
    param_attributes = get_attributes(parameter_container)
    affected_variables = get_affected_values(ff)
    push!(param_attributes.affected_keys, affected_variables...)
    return
end

function _set_affected_variables!(
    container::OptimizationContainer,
    ::T,
    device_type::Type{U},
    ff::FixValueFeedforward,
) where {
    T <: VariableValueParameter,
    U <: PSY.Service,
}
    meta = ff.optimization_container_key.meta
    parameter_container = get_parameter(container, T(), U, meta)
    param_attributes = get_attributes(parameter_container)
    affected_variables = get_affected_values(ff)
    push!(param_attributes.affected_keys, affected_variables...)
    return
end

function _add_parameters!(
    container::OptimizationContainer,
    param::T,
    devices::U,
    model::DeviceModel{D, W},
) where {
    T <: TimeSeriesParameter,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    _add_time_series_parameters!(container, param, devices, model)
    return
end

function _add_time_series_parameters!(
    container::OptimizationContainer,
    param::T,
    devices,
    model::DeviceModel{D, W},
) where {D <: PSY.Component, T <: TimeSeriesParameter, W <: AbstractDeviceFormulation}
    ts_type = get_default_time_series_type(container)
    if !(ts_type <: Union{PSY.AbstractDeterministic, PSY.StaticTimeSeries})
        error("add_parameters! for TimeSeriesParameter is not compatible with $ts_type")
    end
    time_steps = get_time_steps(container)
    ts_name = get_time_series_names(model)[T]
    time_series_mult_id = _create_time_series_multiplier_index(model, T)

    @debug "adding" T D ts_name ts_type time_series_mult_id _group =
        LOG_GROUP_OPTIMIZATION_CONTAINER

    device_names = String[]
    initial_values = Dict{String, AbstractArray}()
    for device in devices
        if !PSY.has_time_series(device, ts_type, ts_name)
            @debug "skipped time series for $D, $(PSY.get_name(device))"
            continue
        end
        push!(device_names, PSY.get_name(device))
        ts_uuid = string(IS.get_time_series_uuid(ts_type, device, ts_name))
        if !(ts_uuid in keys(initial_values))
            initial_values[ts_uuid] =
                get_time_series_initial_values!(container, ts_type, device, ts_name)
        end
    end

    param_container = add_param_container!(
        container,
        param,
        D,
        ts_type,
        ts_name,
        collect(keys(initial_values)),
        device_names,
        time_steps,
    )
    set_time_series_multiplier_id!(get_attributes(param_container), time_series_mult_id)
    set_subsystem!(get_attributes(param_container), get_subsystem(model))
    jump_model = get_jump_model(container)

    for (ts_uuid, ts_values) in initial_values
        for step in time_steps
            set_parameter!(param_container, jump_model, ts_values[step], ts_uuid, step)
        end
    end

    for device in devices
        if !PSY.has_time_series(device, ts_type, ts_name)
            continue
        end
        name = PSY.get_name(device)
        multiplier = get_multiplier_value(T(), device, W())
        for step in time_steps
            set_multiplier!(param_container, multiplier, name, step)
        end
        add_component_name!(
            get_attributes(param_container),
            name,
            string(IS.get_time_series_uuid(ts_type, device, ts_name)),
        )
    end
    return
end

function _add_parameters!(
    container::OptimizationContainer,
    param::T,
    devices::U,
    model::DeviceModel{D, W},
) where {
    T <: ObjectiveFunctionParameter,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    ts_type = get_default_time_series_type(container)
    if !(ts_type <: Union{PSY.AbstractDeterministic, PSY.StaticTimeSeries})
        error(
            "add_parameters! for ObjectiveFunctionParameter is not compatible with $ts_type",
        )
    end
    time_steps = get_time_steps(container)
    ts_name = get_time_series_names(model)[T]
    device_names =
        [PSY.get_name(x) for x in devices if PSY.has_time_series(x, ts_type, ts_name)]
    if isempty(device_names)
        return
    end
    jump_model = get_jump_model(container)

    param_container = add_param_container!(
        container,
        param,
        D,
        ActivePowerVariable,
        PSI.SOSStatusVariable.NO_VARIABLE,
        false,
        Float64,
        device_names,
        time_steps,
    )

    for device in devices
        if !PSY.has_time_series(device, ts_type, ts_name)
            continue
        end
        ts_vals = get_time_series_initial_values!(container, ts_type, device, ts_name)
        name = PSY.get_name(device)
        for step in time_steps
            PSI.set_parameter!(
                param_container,
                jump_model,
                ts_vals[step],
                name,
                step,
            )
            PSI.set_multiplier!(
                param_container,
                get_multiplier_value(T(), device, W()),
                name,
                step,
            )
        end
    end
    return
end

function _add_parameters!(
    container::OptimizationContainer,
    ::T,
    service::U,
    model::ServiceModel{U, V},
) where {T <: TimeSeriesParameter, U <: PSY.Service, V <: AbstractServiceFormulation}
    ts_type = get_default_time_series_type(container)
    if !(ts_type <: Union{PSY.AbstractDeterministic, PSY.StaticTimeSeries})
        error("add_parameters! for TimeSeriesParameter is not compatible with $ts_type")
    end
    ts_name = get_time_series_names(model)[T]
    time_series_mult_id = _create_time_series_multiplier_index(model, T)
    time_steps = get_time_steps(container)
    name = PSY.get_name(service)
    ts_uuid = string(IS.get_time_series_uuid(ts_type, service, ts_name))
    @debug "adding" T U _group = LOG_GROUP_OPTIMIZATION_CONTAINER
    parameter_container = add_param_container!(
        container,
        T(),
        U,
        ts_type,
        ts_name,
        [ts_uuid],
        [name],
        time_steps;
        meta = name,
    )

    set_time_series_multiplier_id!(get_attributes(parameter_container), time_series_mult_id)
    set_subsystem!(get_attributes(parameter_container), get_subsystem(model))
    jump_model = get_jump_model(container)
    ts_vector = get_time_series(container, service, T(), name)
    multiplier = get_multiplier_value(T(), service, V())
    for t in time_steps
        set_multiplier!(parameter_container, multiplier, name, t)
        set_parameter!(parameter_container, jump_model, ts_vector[t], ts_uuid, t)
    end
    add_component_name!(get_attributes(parameter_container), name, ts_uuid)
    return
end

function _add_parameters!(
    container::OptimizationContainer,
    ::T,
    key::VariableKey{U, D},
    model::DeviceModel{D, W},
    devices::V,
) where {
    T <: VariableValueParameter,
    U <: VariableType,
    V <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    @debug "adding" T D U _group = LOG_GROUP_OPTIMIZATION_CONTAINER
    names = [PSY.get_name(device) for device in devices]
    time_steps = get_time_steps(container)
    parameter_container = add_param_container!(container, T(), D, key, names, time_steps)
    jump_model = get_jump_model(container)
    for d in devices
        name = PSY.get_name(d)
        if get_variable_warm_start_value(U(), d, W()) === nothing
            inital_parameter_value = 0.0
        else
            inital_parameter_value = get_variable_warm_start_value(U(), d, W())
        end
        for t in time_steps
            set_multiplier!(
                parameter_container,
                get_parameter_multiplier(T(), d, W()),
                name,
                t,
            )
            set_parameter!(
                parameter_container,
                jump_model,
                inital_parameter_value,
                name,
                t,
            )
        end
    end
    return
end

function _add_parameters!(
    container::OptimizationContainer,
    ::T,
    key::VariableKey{U, D},
    model::DeviceModel{D, W},
    devices::V,
) where {
    T <: OnStatusParameter,
    U <: OnVariable,
    V <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractThermalFormulation,
} where {D <: PSY.ThermalGen}
    @debug "adding" T D U _group = LOG_GROUP_OPTIMIZATION_CONTAINER
    names = [PSY.get_name(device) for device in devices if !PSY.get_must_run(device)]
    time_steps = get_time_steps(container)
    parameter_container = add_param_container!(container, T(), D, key, names, time_steps)
    jump_model = get_jump_model(container)
    for d in devices
        if PSY.get_must_run(d)
            continue
        end
        name = PSY.get_name(d)
        if get_variable_warm_start_value(U(), d, W()) === nothing
            inital_parameter_value = 0.0
        else
            inital_parameter_value = get_variable_warm_start_value(U(), d, W())
        end
        for t in time_steps
            set_multiplier!(
                parameter_container,
                get_parameter_multiplier(T(), d, W()),
                name,
                t,
            )
            set_parameter!(
                parameter_container,
                jump_model,
                inital_parameter_value,
                name,
                t,
            )
        end
    end
    return
end

function _add_parameters!(
    container::OptimizationContainer,
    ::T,
    key::VariableKey{U, D},
    model::DeviceModel{D, W},
    devices::V,
) where {
    T <: FixValueParameter,
    U <: VariableType,
    V <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    @debug "adding" T D U _group = LOG_GROUP_OPTIMIZATION_CONTAINER
    names = [PSY.get_name(device) for device in devices]
    time_steps = get_time_steps(container)
    parameter_container =
        add_param_container!(container, T(), D, key, names, time_steps; meta = "$U")
    jump_model = get_jump_model(container)
    for d in devices
        name = PSY.get_name(d)
        if get_variable_warm_start_value(U(), d, W()) === nothing
            inital_parameter_value = 0.0
        else
            inital_parameter_value = get_variable_warm_start_value(U(), d, W())
        end
        for t in time_steps
            set_multiplier!(
                parameter_container,
                get_parameter_multiplier(T(), d, W()),
                name,
                t,
            )
            set_parameter!(
                parameter_container,
                jump_model,
                inital_parameter_value,
                name,
                t,
            )
        end
    end
    return
end

function _add_parameters!(
    container::OptimizationContainer,
    ::T,
    key::AuxVarKey{U, D},
    model::DeviceModel{D, W},
    devices::V,
) where {
    T <: VariableValueParameter,
    U <: AuxVariableType,
    V <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    @debug "adding" T D U _group = LOG_GROUP_OPTIMIZATION_CONTAINER
    names = [PSY.get_name(device) for device in devices]
    time_steps = get_time_steps(container)
    parameter_container = add_param_container!(
        container,
        T(),
        D,
        key,
        names,
        time_steps,
    )
    jump_model = get_jump_model(container)

    for d in devices
        name = PSY.get_name(d)
        for t in time_steps
            set_multiplier!(
                parameter_container,
                get_parameter_multiplier(T(), d, W()),
                name,
                t,
            )
            set_parameter!(
                parameter_container,
                jump_model,
                get_initial_parameter_value(T(), d, W()),
                name,
                t,
            )
        end
    end
    return
end

function _add_parameters!(
    container::OptimizationContainer,
    ::T,
    devices::V,
    model::DeviceModel{D, W},
) where {
    T <: OnStatusParameter,
    V <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    @debug "adding" T D V _group = LOG_GROUP_OPTIMIZATION_CONTAINER

    # We do this to handle cases where the same parameter is also added as a Feedforward.
    # When the OnStatusParameter is added without a feedforward it takes a Float value.
    # This is used to handle the special case of compact formulations.
    !isempty(get_feedforwards(model)) && return
    names = [PSY.get_name(device) for device in devices]
    time_steps = get_time_steps(container)
    parameter_container = add_param_container!(
        container,
        T(),
        D,
        VariableKey(OnVariable, D),
        names,
        time_steps,
    )
    jump_model = get_jump_model(container)

    for d in devices
        name = PSY.get_name(d)
        for t in time_steps
            set_multiplier!(
                parameter_container,
                get_parameter_multiplier(T(), d, W()),
                name,
                t,
            )
            set_parameter!(
                parameter_container,
                jump_model,
                get_initial_parameter_value(T(), d, W()),
                name,
                t,
            )
        end
    end
    return
end

function _add_parameters!(
    container::OptimizationContainer,
    ::T,
    key::VariableKey{U, S},
    model::ServiceModel{S, W},
    devices::V,
) where {
    S <: PSY.AbstractReserve,
    T <: VariableValueParameter,
    U <: VariableType,
    V <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractReservesFormulation,
} where {D <: PSY.Component}
    @debug "adding" T D U _group = LOG_GROUP_OPTIMIZATION_CONTAINER
    contributing_devices = get_contributing_devices(model)
    names = [PSY.get_name(device) for device in contributing_devices]
    time_steps = get_time_steps(container)
    parameter_container = add_param_container!(
        container,
        T(),
        S,
        key,
        names,
        time_steps;
        meta = get_service_name(model),
    )
    jump_model = get_jump_model(container)
    for d in contributing_devices
        name = PSY.get_name(d)
        for t in time_steps
            set_multiplier!(
                parameter_container,
                get_parameter_multiplier(T(), S, W()),
                name,
                t,
            )
            set_parameter!(
                parameter_container,
                jump_model,
                get_initial_parameter_value(T(), S, W()),
                name,
                t,
            )
        end
    end
    return
end
