function norm_two_constraint(ps_m::CanonicalModel,
                            rating_data::Tuple{Vector{String}, Vector{Float64}},
                            time_range::UnitRange{Int64},
                            cons_name::Symbol,
                            var_names::Tuple{Symbol, Symbol})

    ps_m.constraints[cons_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, rating_data[1], time_range)

    for t in time_range, (ix,r) in enumerate(rating_data[1])

            ps_m.constraints[cons_name][r, t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_names[1]][r[1], t] + ps_m.variables[var_names[2]][r[1], t] <= rating_data[ix][2]^2)

    end

    return

end