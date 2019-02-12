function device_duration(ps_m::CanonicalModel, duration_data::Array{Tuple{String,NamedTuple{(:up, :down),Tuple{Float64,Float64}}},1}, initial_duration::Array{Float64,2}, time_range::UnitRange{Int64}, cons_name::String, var_names::Tuple{String,String,String})

    set_name = [r[1] for r in duration_data]

    ps_m.constraints["$(cons_name)_up"] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)
    ps_m.constraints["$(cons_name)_down"] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)

        for t in time_range, d in duration_data

                if t - devices[ix].tech.timelimits.up >= 1
                    tst = devices[ix].tech.timelimits.up
                else
                    tst = max(0, devices[ix].tech.timelimits.up - initialonduration[name])
                end
                if t - devices[ix].tech.timelimits.down >= 1
                    tsd = devices[ix].tech.timelimits.down
                else
                    tsd = max(0, devices[ix].tech.timelimits.down - initialoffduration[name])
                end

                ps_m.constraints["$(cons_name)_up"][d[1], t] = JuMP.@constraint(m,sum([start_th[name,i] for i in ((t - tst - 1) :t) if i > 0 ]) <= on_th[name,t])
                ps_m.constraints["$(cons_name)_down"][d[1], t] = JuMP.@constraint(m,sum([stop_th[name,i] for i in ((t - tsd - 1) :t) if i > 0]) <= (1 - on_th[name,t]))

        end

end