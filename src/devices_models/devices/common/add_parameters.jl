
function include_parameters!(
    optimization_container::OptimizationContainer,
    constraint_infos::Vector{DeviceTimeSeriesConstraintInfo},
    param_reference::UpdateRef,
    expression_name::Symbol,
    multiplier::Float64 = 1.0,
)
    @assert model_has_parameters(optimization_container)
    time_steps = model_time_steps(optimization_container)
    names = [get_component_name(r) for r in constraint_infos]
    @debug "adding" param_reference "parameter"
    container =
        add_param_container!(optimization_container, param_reference, names, time_steps)
    param = get_parameter_array(container)
    mult = get_multiplier_array(container)
    expr = get_expression(optimization_container, expression_name)
    for t in time_steps, r in constraint_infos
        param[get_component_name(r), t] =
            PJ.add_parameter(optimization_container.JuMPmodel, r.timeseries[t])
        mult[get_component_name(r), t] = r.multiplier * multiplier
        ix = isa(optimization_container.pm, CopperPlatePowerModel) ? t : (r.bus_number, t)
        add_to_expression!(
            expr,
            param[get_component_name(r), t],
            r.multiplier * multiplier,
            ix...
        )
    end
    return container
end

function include_parameters!(
    optimization_container::OptimizationContainer,
    constraint_infos::Vector{DeviceTimeSeriesConstraintInfo},
    param_reference::UpdateRef,
    multiplier::Float64 = 1.0,
)
    @assert model_has_parameters(optimization_container)
    time_steps = model_time_steps(optimization_container)
    names = [get_component_name(r) for r in constraint_infos]
    container =
        add_param_container!(optimization_container, param_reference, names, time_steps)
    param = get_parameter_array(container)
    mult = get_multiplier_array(container)
    for t in time_steps, r in constraint_infos
        param[get_component_name(r), t] =
            PJ.add_parameter(optimization_container.JuMPmodel, r.timeseries[t])
        mult[get_component_name(r), t] = r.multiplier * multiplier
    end
    return container
end
