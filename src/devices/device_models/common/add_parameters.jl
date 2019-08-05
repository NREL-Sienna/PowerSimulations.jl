function include_parameters(ps_m::CanonicalModel,
                            data::Matrix,
                            param_reference::RefParam,
                            axs...)

    _add_param_container!(ps_m, param_reference, axs...)
    param = par(ps_m, param_reference)

    Cidx = CartesianIndices(length.(axs))

    for idx in Cidx
        param.data[idx] = PJ.add_parameter(ps_m.JuMPmodel, data[idx])
    end

    return

end

function include_parameters(ps_m::CanonicalModel,
                            ts_data::Vector{Tuple{String, Int64, Vector{Float64}}},
                            param_reference::RefParam,
                            expression::Symbol,
                            sign::Float64 = 1.0)


    time_steps = model_time_steps(ps_m)
    _add_param_container!(ps_m, param_reference, (r[1] for r in ts_data), time_steps)
    param = par(ps_m, param_reference)
    expr = exp(ps_m, expression)

    for t in time_steps, r in ts_data
        param[r[1], t] = PJ.add_parameter(ps_m.JuMPmodel, r[3][t]);
        _add_to_expression!(expr, r[2], t, param[r[1], t], sign)
    end

    return

end
