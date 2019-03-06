"""
This formulation of the duration constraints, adds over the start times looking backwards.

"""
function device_duration_retrospective(ps_m::CanonicalModel,
                                        duration_data::Array{Tuple{String,NamedTuple{(:up, :down),Tuple{Float64,Float64}}},1},
                                        initial_duration::Array{Float64,2},
                                        time_range::UnitRange{Int64},
                                        cons_name::Symbol,
                                        var_names::Tuple{Symbol,Symbol,Symbol})

    set_name = [r[1] for r in duration_data]

    name_up = Symbol(cons_name,:_up)
    name_down = Symbol(cons_name,:_down)

    ps_m.constraints[name_up] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)
    ps_m.constraints[name_down] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)

        for t in time_range, (ix,d) in enumerate(duration_data)

                if t - d[2].up >= 1
                    tst = d[2].up
                else
                    tst = max(1.0, d[2].up - initial_duration[ix,1])
                end

                if t - d[2].down >= 1
                    tsd = d[2].down
                else
                    tsd = max(1.0, d[2].down - initial_duration[ix,2])
                end

                ps_m.constraints[name_up][d[1], t] = JuMP.@constraint(ps_m.JuMPmodel, sum([ps_m.variables[var_names[2]][d[1],i] for i in ((t - tst + 1) :t) if i > 0 ]) <= ps_m.variables[var_names[1]][d[1],t])
                ps_m.constraints[name_down][d[1], t] = JuMP.@constraint(ps_m.JuMPmodel, sum([ps_m.variables[var_names[3]][d[1],i] for i in ((t - tsd + 1) :t) if i > 0]) <= (1 - ps_m.variables[var_names[1]][d[1],t]))

        end

    return

end
