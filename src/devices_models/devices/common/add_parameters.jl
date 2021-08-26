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
    label = get_time_series_labels(model)[T]
    parameter = T(get_default_time_series_type(container), label)
    @debug "adding" parameter
    parameter_container = add_param_container!(container, parameter, D, names, time_steps)
    param = get_parameter_array(parameter_container)
    mult = get_multiplier_array(parameter_container)

    if !isnothing(label)
        for d in devices, t in time_steps
            name = PSY.get_name(d)
            ts_vector = get_time_series(container, d, parameter)
            mult[name, t] = get_multiplier_value(parameter, d, W())
            param[name, t] = add_parameter(container.JuMPmodel, ts_vector[t])
        end
    end
    return
end

function include_parameters!(
    container::OptimizationContainer,
    constraint_infos::Vector{DeviceTimeSeriesConstraintInfo},
    parameter::RightHandSideParameter,
    ::Type{T},
    expression_name::Symbol,
    multiplier::Float64 = 1.0,
) where {T <: PSY.Device}
    @assert built_for_simulation(container)
    time_steps = get_time_steps(container)
    names = [get_component_name(r) for r in constraint_infos]
    @debug "adding" parameter
    container = add_param_container!(container, parameter, T, names, time_steps)
    param = get_parameter_array(container)
    mult = get_multiplier_array(container)
    expr = get_expression(container, expression_name)
    for t in time_steps, r in constraint_infos
        param[get_component_name(r), t] =
            add_parameter(container.JuMPmodel, r.timeseries[t])
        mult[get_component_name(r), t] = r.multiplier * multiplier
        add_to_expression!(
            expr,
            r.bus_number,
            t,
            param[get_component_name(r), t],
            r.multiplier * multiplier,
        )
    end
    return container
end

function include_parameters!(
    container::OptimizationContainer,
    constraint_infos::Vector{DeviceTimeSeriesConstraintInfo},
    parameter::RightHandSideParameter,
    ::Type{T},
    multiplier::Float64 = 1.0,
) where {T <: PSY.Device}
    @assert built_for_simulation(container)
    time_steps = get_time_steps(container)
    names = [get_component_name(r) for r in constraint_infos]
    container = add_param_container!(container, parameter, T, names, time_steps)
    param = get_parameter_array(container)
    mult = get_multiplier_array(container)
    for t in time_steps, r in constraint_infos
        param[get_component_name(r), t] =
            add_parameter(container.JuMPmodel, r.timeseries[t])
        mult[get_component_name(r), t] = r.multiplier * multiplier
    end
    return container
end
