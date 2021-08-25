function add_parameters!(
    container::OptimizationContainer,
    parameter_type::Type{T},
    devices::U,
    model::DeviceModel{D, W},
) where {
    T <: TimeSeriesParameter,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractDeviceFormulation,
} where {D <: PSY.Component}
    time_steps = get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    @debug "adding" parameter_type
    parameter_container = add_param_container!(container, T(), D, names, time_steps)
    param = get_parameter_array(parameter_container)
    mult = get_multiplier_array(parameter_container)
    label = get(get_time_series_labels(model), parameter_type, nothing)
    if !isnothing(label)
        for d in devices, t in time_steps
            name = PSY.get_name(d)
            ts_vector = get_time_series(container, d, label)
            mult[name, t] = get_multiplier_value(T(), d, W())
            param[name, t] = PJ.add_parameter(container.JuMPmodel, ts_vector[t])
        end
    end
    return
end

function add_parameters!(
    container::OptimizationContainer,
    parameter_type::Type{T},
    service::U,
    model::ServiceModel{U, V},
) where {
    T <: TimeSeriesParameter,
    U <: PSY.Service,
    V <: AbstractReservesFormulation,
}

    time_steps = get_time_steps(container)
    name = PSY.get_name(service)
    @debug "adding" parameter_type
    parameter_container = add_param_container!(container, T(), U, [name], time_steps; meta = name)
    param = get_parameter_array(parameter_container)
    mult = get_multiplier_array(parameter_container)
    label = get(get_time_series_labels(model), parameter_type, nothing)
    
    if !isnothing(label)
        ts_vector = get_time_series(container, service, label)
        for t in time_steps
            mult[name, t] = get_multiplier_value(T(), service, V())
            param[name, t] = PJ.add_parameter(container.JuMPmodel, ts_vector[t])
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
