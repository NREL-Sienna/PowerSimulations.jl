function device_range(ps_m::CanonicalModel,
                        range_data::Vector{NamedMinMax},
                        time_range::UnitRange{Int64},
                        cons_name::Symbol,
                        var_name::Symbol)

    ps_m.constraints[cons_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, [r[1] for r in range_data], time_range)

    for t in time_range, r in range_data
            if abs(r[2].min - r[2].max) >= eps()
                ps_m.constraints[cons_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, r[2].min <= ps_m.variables[var_name][r[1], t] <= r[2].max)            
            else
                @warn("The min - max values in range constraint with eps() distance to each other. Range Constraint will be modified for Equality Constraint")
                ps_m.constraints[cons_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][r[1], t] == r[2].max)
            end
    end

    return

end

function device_semicontinuousrange(ps_m::CanonicalModel,
                                    scrange_data::Vector{NamedMinMax},
                                    time_range::UnitRange{Int64}, cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

    ub_name = Symbol(cons_name,:_ub)
    lb_name = Symbol(cons_name,:_lb)

    #MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it. In the future this can be updated
    set_name = [r[1] for r in scrange_data]
    ps_m.constraints[ub_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)
    ps_m.constraints[lb_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)

    for t in time_range, r in scrange_data

            if r[2].min == 0.0

                ps_m.constraints[ub_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][r[1], t] <= r[2].max*ps_m.variables[binvar_name][r[1], t])
                ps_m.constraints[lb_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][r[1], t] >= 0.0)

            else

                ps_m.constraints[ub_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][r[1], t] <= r[2].max*ps_m.variables[binvar_name][r[1], t])
                ps_m.constraints[lb_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][r[1], t] >= r[2].min*ps_m.variables[binvar_name][r[1], t])

            end

    end

    return

end

function reserve_device_semicontinuousrange(ps_m::CanonicalModel,
                                            scrange_data::Vector{NamedMinMax},
                                            time_range::UnitRange{Int64},
                                            cons_name::Symbol,
                                            var_name::Symbol,
                                            binvar_name::Symbol)

    ub_name = Symbol(cons_name,:_ub)
    lb_name = Symbol(cons_name,:_lb)

    #MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it. In the future this can be updated
    set_name = [r[1] for r in scrange_data]
    ps_m.constraints[ub_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)
    ps_m.constraints[lb_name] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)

    for t in time_range, r in scrange_data

            if r[2].min == 0.0

                ps_m.constraints[ub_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][r[1], t] <= r[2].max*(1-ps_m.variables[binvar_name][r[1], t]))
                ps_m.constraints[lb_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][r[1], t] >= 0.0)

            else

                ps_m.constraints[ub_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][r[1], t] <= r[2].max*(1-ps_m.variables[binvar_name][r[1], t]))
                ps_m.constraints[lb_name][r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, ps_m.variables[var_name][r[1], t] >= r[2].min*(1-ps_m.variables[binvar_name][r[1], t]))

            end

    end

    return

 end
