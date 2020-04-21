
function include_parameters(
    psi_container::PSIContainer,
    ts_data::Vector{DeviceTimeSeries},
    param_reference::UpdateRef,
    expression_name::Symbol,
    multiplier::Float64 = 1.0,
)
    @assert !model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)
    ## TODO, replace multiplier
    names = [r.name for r in ts_data]
    container = add_param_container!(psi_container, param_reference, names, time_steps)
    param = get_parameter_array(container)
    mult = get_multiplier_array(container)
    expr = get_expression(psi_container, expression_name)
    for t in time_steps, r in ts_data
        param[r.name, t] = PJ.add_parameter(psi_container.JuMPmodel, r.timeseries[t])
        mult[r.name, t] = r.multiplier * multiplier
        add_to_expression!(
            expr,
            r.bus_number,
            t,
            param[r.name, t],
            r.multiplier * multiplier,
        )
    end
    return param
end
