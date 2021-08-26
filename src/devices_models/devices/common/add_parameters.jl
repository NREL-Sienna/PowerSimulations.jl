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
    ts_type = get_default_time_series_type(container)
    if !isa(ts_type, PSY.AbstractDeterministic) || !isa(ts_type, PSY.StaticTimeSeries)
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
