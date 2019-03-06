function device_linear_rateofchange(ps_m::CanonicalModel,
                                    rate_data::Array{Tuple{String,NamedTuple{(:up, :down),Tuple{Float64,Float64}}},1},
                                    initial_conditions::Array{Float64,1},
                                    time_range::UnitRange{Int64},
                                    cons_name::Symbol,
                                    var_name::Symbol)


    up_name = Symbol(cons_name,:_up)
    down_name = Symbol(cons_name,:_down)

    set_name = [r[1] for r in rate_data]

    ps_m.constraints[up_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)
    ps_m.constraints[down_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)

    for (ix,r) in enumerate(rate_data)

        ps_m.constraints[up_name][r[1], 1] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][r[1], 1] - initial_conditions[ix] <= r[2].up)
        ps_m.constraints[down_name][r[1], 1] = JuMP.@constraint(ps_m.JuMPmodel, initial_conditions[ix] - ps_m.variables[var_name][r[1], 1] <= r[2].down)

    end

    for t in time_range[2:end], r in rate_data

        ps_m.constraints[up_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][r[1], t-1] - ps_m.variables[var_name][r[1], t] <= r[2].up)
        ps_m.constraints[down_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][r[1], t] - ps_m.variables[var_name][r[1], t-1] <= r[2].down)

    end

    return nothing

end

function device_mixedinteger_rateofchange(ps_m::CanonicalModel,
                                            rate_data::Array{Tuple{String,NamedTuple{(:up, :down),Tuple{Float64,Float64}},NamedTuple{(:min, :max),Tuple{Float64,Float64}}},1},
                                            initial_conditions::Array{Float64,1},
                                            time_range::UnitRange{Int64},
                                            cons_name::Symbol,
                                            var_names::Tuple{Symbol,Symbol,Symbol})

    up_name = Symbol(cons_name,:_up)
    down_name = Symbol(cons_name,:_down)

    set_name = [r[1] for r in rate_data]

    ps_m.constraints[up_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)
    ps_m.constraints[down_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)

    for (ix,r) in enumerate(rate_data)

        ps_m.constraints[up_name][r[1], 1] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_names[1]][r[1], 1] - initial_conditions[ix] <= r[2].up + r[3].max*ps_m.variables[var_names[2]][r[1], 1])
        ps_m.constraints[down_name][r[1], 1] = JuMP.@constraint(ps_m.JuMPmodel, initial_conditions[ix] - ps_m.variables[var_names[1]][r[1], 1] <= r[2].down + r[3].min*ps_m.variables[var_names[3]][r[1], 1])

    end

    for t in time_range[2:end], r in rate_data

        ps_m.constraints[up_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_names[1]][r[1], t-1] - ps_m.variables[var_names[1]][r[1], t] <= r[2].up + r[3].max*ps_m.variables[var_names[2]][r[1], t])
        ps_m.constraints[down_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_names[1]][r[1], t] - ps_m.variables[var_names[1]][r[1], t-1] <= r[2].down + r[3].min*ps_m.variables[var_names[3]][r[1], t])

    end

    return nothing

end


