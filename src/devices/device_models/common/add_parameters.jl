function include_parameters(ps_m::CanonicalModel,
                        data::Matrix,
                        param_name::Symbol,
                        axs...)

    ps_m.parameters[param_name] = JuMP.Containers.DenseAxisArray{PJ.ParameterRef}(undef, axs...)

    Cidx = CartesianIndices(length.(axs))

    for idx in Cidx
        ps_m.parameters[param_name].data[idx] = PJ.add_parameter(ps_m.JuMPmodel,data[idx])
    end

    return

end

function include_parameters(ps_m::CanonicalModel,
                        ts_data::Vector{Tuple{String,Int64, Vector{Float64}}},
                        time_steps::UnitRange{Int64},
                        param_name::Symbol,
                        expression::Symbol)

    ps_m.parameters[param_name] = JuMP.Containers.DenseAxisArray{PJ.ParameterRef}(undef, [r[1] for r in ts_data], time_range)

    for t in time_range, r in ts_data
        ps_m.parameters[param_name][r[1], t] = PJ.add_parameter(ps_m.JuMPmodel, r[3][t]);
        _add_to_expression!(ps_m.expressions[expression], r[2], t, ps_m.parameters[param_name][r[1], t])
    end

    return

end