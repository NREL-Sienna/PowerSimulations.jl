"""
This formulation of the duration constraints, adds over the start times looking backwards.

"""
function device_duration_retrospective(ps_m::CanonicalModel,
                                        set_names::Vector{String},
                                        duration_data::Vector{UpDown},
                                        initial_duration_on::Vector{InitialCondition},
                                        initial_duration_off::Vector{InitialCondition},
                                        time_range::UnitRange{Int64},
                                        cons_name::Symbol,
                                        var_names::Tuple{Symbol,Symbol,Symbol})

    name_up = Symbol(cons_name,:_up)
    name_down = Symbol(cons_name,:_down)

    ps_m.constraints[name_up] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_names, time_range)
    ps_m.constraints[name_down] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_names, time_range)

        for t in time_range, (ix,name) in enumerate(set_names)

                if t - duration_data[ix].up >= 1
                    tst = duration_data[ix].up
                else
                    tst = max(1.0, duration_data[ix].up - initial_duration_on[ix].value)
                end

                if t - duration_data[ix].down >= 1
                    tsd = duration_data[ix].down
                else
                    tsd = max(1.0, duration_data[ix].down - initial_duration_off[ix].value)
                end

                ps_m.constraints[name_up][name, t] = JuMP.@constraint(ps_m.JuMPmodel, sum([ps_m.variables[var_names[2]][name,i] for i in ((t - tst + 1) :t) if i > 0 ]) <= ps_m.variables[var_names[1]][name,t])
                ps_m.constraints[name_down][name, t] = JuMP.@constraint(ps_m.JuMPmodel, sum([ps_m.variables[var_names[3]][name,i] for i in ((t - tsd + 1) :t) if i > 0]) <= (1 - ps_m.variables[var_names[1]][name,t]))

        end

    return

end


"""
This formulation of the duration constraints, uses an Indicator parameter value to show if the constraint was satisfied in the past. 

"""
function device_duration_indicator(ps_m::CanonicalModel,
                                    set_names::Vector{String},
                                    duration_data::Vector{UpDown},
                                    duration_indicator_status_on::Vector{InitialCondition},
                                    duration_indicator_status_off::Vector{InitialCondition},
                                    time_range::UnitRange{Int64},
                                    cons_name::Symbol,
                                    var_names::Tuple{Symbol,Symbol,Symbol})


    name_up = Symbol(cons_name,:_up)
    name_down = Symbol(cons_name,:_down)

    ps_m.constraints[name_up] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_names, time_range)
    ps_m.constraints[name_down] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_names, time_range)

    for (ix,name) in enumerate(set_names)
        ps_m.constraints[name_up][name, 1] = JuMP.@constraint(ps_m.JuMPmodel, 
                                            duration_indicator_status_on[ix].value <= ps_m.variables[var_names[1]][name,1])
        ps_m.constraints[name_down][name, 1] = JuMP.@constraint(ps_m.JuMPmodel, 
                                            duration_indicator_status_off[ix].value <= (1- ps_m.variables[var_names[1]][name,1]))
    end

    for t in time_range[2:end], (ix,name) in enumerate(set_names)
        if t <= duration_data[ix].up
            ps_m.constraints[name_up][name, t] = JuMP.@constraint(ps_m.JuMPmodel, 
                                                            sum([ps_m.variables[var_names[2]][name,i] for i in 1:(t-1)]) + duration_indicator_status_on[ix].value <= ps_m.variables[var_names[1]][name,t])
         else
            ps_m.constraints[name_up][name, t] = JuMP.@constraint(ps_m.JuMPmodel, sum([ps_m.variables[var_names[2]][name,i] for i in (t-duration_data[ix].up):t]) <= ps_m.variables[var_names[1]][name,t])
        end

        if t <= duration_data[ix].down
            ps_m.constraints[name_down][name, t] = JuMP.@constraint(ps_m.JuMPmodel, 
                                                            sum([ps_m.variables[var_names[3]][name,i] for i in 1:(t-1)]) + duration_indicator_status_off[ix].value <= (1 - ps_m.variables[var_names[1]][name,t]))                                                                 
        else
            ps_m.constraints[name_down][name, t] = JuMP.@constraint(ps_m.JuMPmodel, sum([ps_m.variables[var_names[3]][name,i] for i in (t-duration_data[ix].down):t]) <= (1 - ps_m.variables[var_names[1]][name,t])) 
        end

    end

    return

end