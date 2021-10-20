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
    _devices = [d for d in devices if PSY.get_renewable_unit(d) != nothing]
    add_parameters!(container, T(), _devices, model)
end

function add_parameters!(
    container::OptimizationContainer,
    ::Type{T},
    service::U,
    model::ServiceModel{U, V},
) where {T <: TimeSeriesParameter, U <: PSY.Service, V <: AbstractReservesFormulation}
    add_parameters!(container, T(), service, model)
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
    @debug "adding" T name ts_type
    parameter_container =
        add_param_container!(container, T(), D, ts_type, ts_name, names, time_steps)
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
    time_steps = get_time_steps(container)
    name = PSY.get_name(service)
    @debug "adding" parameter_type
    parameter_container = add_param_container!(
        container,
        T(),
        U,
        ts_type,
        ts_name,
        [name],
        time_steps;
        meta = name,
    )
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
    @debug "adding" T D U
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
    @debug "adding" T D V

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
    @debug "adding" T D U
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
