
function include_parameters!(
    optimization_container::OptimizationContainer,
    constraint_infos::Vector{DeviceTimeSeriesConstraintInfo},
    parameter_type::RightHandSideParameter,
    ::Type{T},
    time_series_label::String,
    expression_name::Symbol,
    multiplier::Float64 = 1.0,
) where {T <: PSY.Device}
    @assert model_has_parameters(optimization_container)
    time_steps = model_time_steps(optimization_container)
    names = [get_component_name(r) for r in constraint_infos]
    @debug "adding" param_reference "parameter"
    container = add_param_container!(
        optimization_container,
        parameter_type,
        T,
        names,
        time_steps;
        meta = time_series_label
    )
    param = get_parameter_array(container)
    mult = get_multiplier_array(container)
    expr = get_expression(optimization_container, expression_name)
    for t in time_steps, r in constraint_infos
        param[get_component_name(r), t] =
            add_parameter(optimization_container.JuMPmodel, r.timeseries[t])
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
    optimization_container::OptimizationContainer,
    constraint_infos::Vector{DeviceTimeSeriesConstraintInfo},
    parameter_type::RightHandSideParameter,
    ::Type{T},
    time_series_label::String,
    multiplier::Float64 = 1.0,
) where {T <: PSY.Device}
    @assert model_has_parameters(optimization_container)
    time_steps = model_time_steps(optimization_container)
    names = [get_component_name(r) for r in constraint_infos]
    container = add_param_container!(
        optimization_container,
        parameter_type,
        T,
        names,
        time_steps;
        meta = time_series_label
    )
    param = get_parameter_array(container)
    mult = get_multiplier_array(container)
    for t in time_steps, r in constraint_infos
        param[get_component_name(r), t] =
            add_parameter(optimization_container.JuMPmodel, r.timeseries[t])
        mult[get_component_name(r), t] = r.multiplier * multiplier
    end
    return container
end
