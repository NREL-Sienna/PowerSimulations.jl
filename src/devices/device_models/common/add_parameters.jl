function include_parameters(canonical::Canonical,
                            data::Matrix,
                            param_reference::UpdateRef,
                            axs...)

    param = _add_param_container!(canonical, param_reference, axs...)
    Cidx = CartesianIndices(length.(axs))

    for idx in Cidx
        param.data[idx] = PJ.add_parameter(canonical.JuMPmodel, data[idx])
    end

    return

end

function include_parameters(canonical::Canonical,
                            ts_data::Vector{Tuple{String, Int64, Float64, Vector{Float64}}},
                            param_reference::UpdateRef,
                            expression_name::Symbol,
                            multiplier::Float64 = 1.0)


    time_steps = model_time_steps(canonical)
    param = _add_param_container!(canonical, param_reference, (r[1] for r in ts_data), time_steps)
    expr = get_expression(canonical, expression_name)

    for t in time_steps, r in ts_data
        param[r[1], t] = PJ.add_parameter(canonical.JuMPmodel, r[4][t]);
        _add_to_expression!(expr, r[2], t, param[r[1], t], r[3] * multiplier)
    end

    return

end
