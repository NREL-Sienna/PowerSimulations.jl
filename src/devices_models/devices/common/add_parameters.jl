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
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    name = get_time_series_names(model)[T]
    # TODO: add a block of some sort to block other than deterministic or single time series
    ts_type = get_default_time_series_type(container)
    @debug "adding" T name ts_type
    parameter_container =
        add_param_container!(container, T(), D, ts_type, names, time_steps; meta = name)
    param = get_parameter_array(parameter_container)
    mult = get_multiplier_array(parameter_container)

    for d in devices, t in time_steps
        name = PSY.get_name(d)
        ts_vector = get_time_series(container, d, T(), name)
        mult[name, t] = get_multiplier_value(parameter, d, W())
        param[name, t] = add_parameter(container.JuMPmodel, ts_vector[t])
    end
    return
end
