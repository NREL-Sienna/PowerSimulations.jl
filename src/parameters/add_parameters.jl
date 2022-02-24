"""
Function to create a unique index of time series names for each device model. For example,
if two parameters each reference the same time series name, this function will return a
different value for each parameter entry
"""
function create_time_series_multiplier_index(
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
    T <: TimeSeriesParameter,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    add_parameters!(container, T(), devices, model)
    return
end

function add_parameters!(
    container::OptimizationContainer,
    ::Type{T},
    devices::U,
    model::DeviceModel{D, W},
) where {
    T <: TimeSeriesParameter,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.HybridSystem}
    _devices = [d for d in devices if PSY.get_renewable_unit(d) !== nothing]
    add_parameters!(container, T(), _devices, model)
    return
end

function add_parameters!(
    container::OptimizationContainer,
    ::Type{T},
    service::U,
    model::ServiceModel{U, V},
) where {T <: TimeSeriesParameter, U <: PSY.Service, V <: AbstractReservesFormulation}
    add_parameters!(container, T(), service, model)
    return
end

function add_parameters!(
    container::OptimizationContainer,
    ::Type{T},
    key::VariableKey{U, D},
    model::DeviceModel{D, W},
    devices::V,
) where {
    T <: VariableValueParameter,
    U <: VariableType,
    V <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    add_parameters!(container, T(), key, model, devices)
    return
end

function add_parameters!(
    container::OptimizationContainer,
    ::T,
    devices::U,
    model::DeviceModel{D, W},
) where {
    T <: TimeSeriesParameter,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    ts_type = get_default_time_series_type(container)
    if !(ts_type <: Union{PSY.AbstractDeterministic, PSY.StaticTimeSeries})
        error("add_parameters! for TimeSeriesParameter is not compatible with $ts_type")
    end
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    ts_name = get_time_series_names(model)[T]
    time_series_mult_id = create_time_series_multiplier_index(model, T)
    @debug "adding" T ts_name ts_type time_series_mult_id _group =
        LOG_GROUP_OPTIMIZATION_CONTAINER
    parameter_container =
        add_param_container!(container, T(), D, ts_type, ts_name, names, time_steps)
    set_time_series_multiplier_id!(get_attributes(parameter_container), time_series_mult_id)
    jump_model = get_jump_model(container)
    for d in devices
        name = PSY.get_name(d)
        ts_vector = get_time_series(container, d, T())
        multiplier = get_multiplier_value(T(), d, W())
        for t in time_steps
            set_parameter!(
                parameter_container,
                jump_model,
                ts_vector[t],
                multiplier,
                name,
                t,
            )
        end
    end
    return
end

function add_parameters!(
    container::OptimizationContainer,
    ::T,
    devices::U,
    model::DeviceModel{D, W},
) where {
    T <: ActivePowerTimeSeriesParameter,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.HybridSystem}
    ts_type = get_default_time_series_type(container)
    if !(ts_type <: Union{PSY.AbstractDeterministic, PSY.StaticTimeSeries})
        error("add_parameters! for TimeSeriesParameter is not compatible with $ts_type")
    end
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    ts_name = get_time_series_names(model)[T]
    time_series_mult_id = create_time_series_multiplier_index(model, T)
    @debug "adding" T ts_name ts_type time_series_mult_id _group =
        LOG_GROUP_OPTIMIZATION_CONTAINER
    sub_comp_type = [PSY.RenewableGen, PSY.ElectricLoad]
    parameter_container = add_param_container!(
        container,
        T(),
        D,
        ts_type,
        ts_name,
        names,
        string.(sub_comp_type),
        time_steps;
        sparse=true,
    )
    set_time_series_multiplier_id!(get_attributes(parameter_container), time_series_mult_id)
    jump_model = get_jump_model(container)
    for d in devices, comp_type in sub_comp_type
        name = PSY.get_name(d)
        if does_subcomponent_exist(d, comp_type)
            ts_vector = get_time_series(container, d, comp_type, T())
            multiplier = get_multiplier_value(T(), d, comp_type, W())
        else
            ts_vector = zeros(time_steps[end])
            multiplier = 0.0
        end
        for t in time_steps
            set_parameter!(
                parameter_container,
                jump_model,
                ts_vector[t],
                multiplier,
                name,
                string(comp_type),
                t,
            )
        end
    end
    return
end

function add_parameters!(
    container::OptimizationContainer,
    ::T,
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
    names = [PSY.get_name(d) for d in devices]
    ts_name = get_time_series_names(model)[T]
    time_series_mult_id = create_time_series_multiplier_index(model, T)
    @debug "adding" T ts_name ts_type time_series_mult_id _group =
        LOG_GROUP_OPTIMIZATION_CONTAINER
    parameter_container =
        add_param_container!(container, T(), D, ts_type, ts_name, names, time_steps)
    set_time_series_multiplier_id!(get_attributes(parameter_container), time_series_mult_id)
    jump_model = get_jump_model(container)
    for d in devices
        name = PSY.get_name(d)
        ts_vector = get_time_series(container, d, T())
        multiplier = get_multiplier_value(T(), d, W())
        for t in time_steps
            set_parameter!(
                parameter_container,
                jump_model,
                ts_vector[t],
                multiplier,
                name,
                t,
            )
        end
    end
    return
end

function add_parameters!(
    container::OptimizationContainer,
    ::Type{T},
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
    add_parameters!(container, T(), key, model, devices)
    return
end

function add_parameters!(
    container::OptimizationContainer,
    ::T,
    service::U,
    model::ServiceModel{U, V},
) where {T <: TimeSeriesParameter, U <: PSY.Service, V <: AbstractReservesFormulation}
    ts_type = get_default_time_series_type(container)
    if !(ts_type <: Union{PSY.AbstractDeterministic, PSY.StaticTimeSeries})
        error("add_parameters! for TimeSeriesParameter is not compatible with $ts_type")
    end
    ts_name = get_time_series_names(model)[T]
    time_series_mult_id = create_time_series_multiplier_index(model, T)
    time_steps = get_time_steps(container)
    name = PSY.get_name(service)
    @debug "adding" parameter_type U _group = LOG_GROUP_OPTIMIZATION_CONTAINER
    parameter_container = add_param_container!(
        container,
        T(),
        U,
        ts_type,
        ts_name,
        [name],
        time_steps;
        meta=name,
    )
    set_time_series_multiplier_id!(get_attributes(parameter_container), time_series_mult_id)
    jump_model = get_jump_model(container)
    ts_vector = get_time_series(container, service, T(), name)
    multiplier = get_multiplier_value(T(), service, V())
    for t in time_steps
        set_parameter!(parameter_container, jump_model, ts_vector[t], multiplier, name, t)
    end

    return
end

function add_parameters!(
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
        for t in time_steps
            set_parameter!(
                parameter_container,
                jump_model,
                get_initial_parameter_value(T(), d, W()),
                get_parameter_multiplier(T(), d, W()),
                name,
                t,
            )
        end
    end
    return
end

function add_parameters!(
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
    parameter_container = add_param_container!(container, T(), D, key, names, time_steps)
    jump_model = get_jump_model(container)

    for d in devices
        name = PSY.get_name(d)
        for t in time_steps
            set_parameter!(
                parameter_container,
                jump_model,
                get_initial_parameter_value(T(), d, W()),
                get_parameter_multiplier(T(), d, W()),
                name,
                t,
            )
        end
    end
    return
end

function add_parameters!(
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
            set_parameter!(
                parameter_container,
                jump_model,
                get_initial_parameter_value(T(), d, W()),
                get_parameter_multiplier(T(), d, W()),
                name,
                t,
            )
        end
    end
    return
end

function add_parameters!(
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
    names = [PSY.get_name(device) for device in devices]
    time_steps = get_time_steps(container)
    parameter_container = add_param_container!(container, T(), D, key, names, time_steps)
    jump_model = get_jump_model(container)

    for d in devices
        name = PSY.get_name(d)
        for t in time_steps
            set_parameter!(
                parameter_container,
                jump_model,
                get_initial_parameter_value(T(), S, W()),
                get_parameter_multiplier(T(), S, W()),
                name,
                t,
            )
        end
    end
    return
end
