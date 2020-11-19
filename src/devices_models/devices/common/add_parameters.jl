
function include_parameters!(
    psi_container::PSIContainer,
    constraint_infos::Vector{DeviceTimeSeriesConstraintInfo},
    param_reference::UpdateRef,
    expression_name::Symbol,
    multiplier::Float64 = 1.0,
)
    @assert model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)
    names = [get_component_name(r) for r in constraint_infos]
    @debug "adding" param_reference "parameter"
    container = add_param_container!(psi_container, param_reference, names, time_steps)
    param = get_parameter_array(container)
    mult = get_multiplier_array(container)
    expr = get_expression(psi_container, expression_name)
    for t in time_steps, r in constraint_infos
        param[get_component_name(r), t] =
            PJ.add_parameter(psi_container.JuMPmodel, r.timeseries[t])
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
    psi_container::PSIContainer,
    constraint_infos::Vector{DeviceTimeSeriesConstraintInfo},
    param_reference::UpdateRef,
    multiplier::Float64 = 1.0,
)
    @assert model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)
    names = [get_component_name(r) for r in constraint_infos]
    container = add_param_container!(psi_container, param_reference, names, time_steps)
    param = get_parameter_array(container)
    mult = get_multiplier_array(container)
    for t in time_steps, r in constraint_infos
        param[get_component_name(r), t] =
            PJ.add_parameter(psi_container.JuMPmodel, r.timeseries[t])
        mult[get_component_name(r), t] = r.multiplier * multiplier
    end
    return container
end


function include_parameters!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    param_reference::UpdateRef,
    expression_name::Symbol,
    multiplier::Float64 = 1.0,
) where {T <: PSY.StaticInjection}
    @assert model_has_parameters(psi_container)
    time_steps = model_time_steps(psi_container)
    names = [PSY.get_name(r) for r in devices]
    @debug "adding" param_reference "parameter"
    container = add_param_container!(psi_container, param_reference, names)
    param = get_parameter_array(container)
    mult = get_multiplier_array(container)
    expr = get_expression(psi_container, expression_name)
    for r in devices
        param[PSY.get_name(r)] =
            PJ.add_parameter(psi_container.JuMPmodel, PSY.get_active_power(r))
        mult[PSY.get_name(r)] = multiplier
        bus_number = PSY.get_number(PSY.get_bus(r))
        for t in time_steps
            add_to_expression!(
                expr,
                bus_number,
                t,
                param[PSY.get_name(r)],
                multiplier,
            )
        end
    end
    return container
end
