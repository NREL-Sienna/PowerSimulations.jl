
function include_parameters(
    psi_container::PSIContainer,
    constraint_infos::Vector{DeviceTimeSeriesConstraintInfo},
    param_reference::UpdateRef,
    expression_name::Symbol,
    multiplier::Float64 = 1.0,
)
    @assert model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)
    ## TODO, replace multiplier
    names = (get_name(r) for r in constraint_infos)
    container = add_param_container!(psi_container, param_reference, names, time_steps)
    param = get_parameter_array(container)
    mult = get_multiplier_array(container)
    expr = get_expression(psi_container, expression_name)
    for t in time_steps, r in constraint_infos
        param[get_name(r), t] = PJ.add_parameter(psi_container.JuMPmodel, r.timeseries[t])
        mult[get_name(r), t] = r.multiplier * multiplier
        add_to_expression!(
            expr,
            r.bus_number,
            t,
            param[get_name(r), t],
            r.multiplier * multiplier,
        )
    end
    return container
end

function include_parameters(
    psi_container::PSIContainer,
    constraint_infos::Vector{DeviceTimeSeriesConstraintInfo},
    param_reference::UpdateRef,
    multiplier::Float64 = 1.0,
)
    @assert model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)
    ## TODO, replace multiplier
    names = (get_name(r) for r in constraint_infos)
    container = add_param_container!(psi_container, param_reference, names, time_steps)
    param = get_parameter_array(container)
    mult = get_multiplier_array(container)
    for t in time_steps, r in constraint_infos
        param[get_name(r), t] = PJ.add_parameter(psi_container.JuMPmodel, r.timeseries[t])
        mult[get_name(r), t] = r.multiplier * multiplier
    end
    return container
end
