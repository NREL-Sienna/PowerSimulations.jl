function include_parameters(ps_m::CanonicalModel,
                        data::Matrix,
                        param_name::Symbol,
                        axs...)
    
    _add_param_container!(ps_m, param_name, axs...)
    parameter = par(ps_m, param_name)
    
    Cidx = CartesianIndices(length.(axs))

    for idx in Cidx
        parameter.data[idx] = PJ.add_parameter(ps_m.JuMPmodel,data[idx])
    end

    return

end

function include_parameters(ps_m::CanonicalModel,
                        ts_data::Vector{Tuple{String,Int64, Vector{Float64}}},
                        param_name::Symbol,
                        expression::Symbol)


    time_steps = model_time_steps(ps_m)
    _add_param_container!(ps_m, param_name, (r[1] for r in ts_data), time_steps)
    parameter = par(ps_m, param_name)
    expr = exp(ps_m, expression)

    for t in time_steps, r in ts_data
        parameter[r[1], t] = PJ.add_parameter(ps_m.JuMPmodel, r[3][t]);
        _add_to_expression!(expr, r[2], t, parameter[r[1], t])
    end

    return

end