function add_parameters(ps_m::CanonicalModel,
                        data::Matrix,
                        param_name::Symbol,
                        axs...)

    ps_m.parameters[param_name] = JuMP.Containers.DenseAxisArray{PJ.Parameter}(undef, axs...)

    Cidx = CartesianIndices(length.(axs))

    for idx in Cidx
        ps_m.parameters[param_name].data[idx] = PJ.Parameter(ps_m.JuMPmodel,data[idx])
    end

    return

end

function add_parameters(ps_m::CanonicalModel,
                        ts_data::Vector{Tuple{String,Int64, Vector{Float64}}},
                        time_range::UnitRange{Int64},
                        param_name::Symbol,
                        expression::Symbol)

    ps_m.parameters[param_name] = JuMP.Containers.DenseAxisArray{PJ.Parameter}(undef, [r[1] for r in ts_data], time_range)

    for t in time_range, r in ts_data
        ps_m.parameters[param_name][r[1], t] = PJ.Parameter(ps_m.JuMPmodel, r[3][t]);
        _add_to_expression!(ps_m.expressions[expression].data, r[2], t, ps_m.parameters[param_name][r[1], t])
    end

    return

end