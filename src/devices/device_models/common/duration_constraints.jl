"""
This formulation of the duration constraints, adds over the start times looking backwards.

"""
function device_duration_retrospective(ps_m::CanonicalModel,
                                        duration_data::Tuple{Vector{String},Vector{UpDown}},
                                        initial_duration_on::Vector{InitialCondition},
                                        initial_duration_off::Vector{InitialCondition},
                                        time_range::UnitRange{Int64},
                                        cons_name::Symbol,
                                        var_names::Tuple{Symbol,Symbol,Symbol})

    set_name = duration_data[1]

    name_up = Symbol(cons_name,:_up)
    name_down = Symbol(cons_name,:_down)

    ps_m.constraints[name_up] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)
    ps_m.constraints[name_down] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)

        for t in time_range, (ix,name) in enumerate(duration_data[1])

                if t - duration_data[2][ix].up >= 1
                    tst = duration_data[2][ix].up
                else
                    tst = max(1.0, duration_data[2][ix].up - initial_duration_on[ix].value)
                end

                if t - duration_data[2][ix].down >= 1
                    tsd = duration_data[2][ix].down
                else
                    tsd = max(1.0, duration_data[2][ix].down - initial_duration_off[ix].value)
                end

                ps_m.constraints[name_up][name, t] = JuMP.@constraint(ps_m.JuMPmodel, sum([ps_m.variables[var_names[2]][name,i] for i in ((t - tst + 1) :t) if i > 0 ]) <= ps_m.variables[var_names[1]][name,t])
                ps_m.constraints[name_down][name, t] = JuMP.@constraint(ps_m.JuMPmodel, sum([ps_m.variables[var_names[3]][name,i] for i in ((t - tsd + 1) :t) if i > 0]) <= (1 - ps_m.variables[var_names[1]][name,t]))

        end

    return

end


"""
This formulation of the duration constraints, adds over the start times looking backwards.

"""
function device_duration_indicator(ps_m::CanonicalModel,
                                    duration_data::Tuple{Vector{String},Vector{UpDown}},
                                    initial_duration_on::Vector{InitialCondition},
                                    initial_duration_off::Vector{InitialCondition},
                                    time_range::UnitRange{Int64},
                                    cons_name::Symbol,
                                    var_names::Tuple{Symbol,Symbol,Symbol})

    set_name = duration_data[1]

    name_up = Symbol(cons_name,:_up)
    name_down = Symbol(cons_name,:_down)

    ps_m.constraints[name_up] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)
    ps_m.constraints[name_down] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, set_name, time_range)

    for (ix,name) in enumerate(duration_data[1])

        ps_m.constraints[name_up][name, 1] = JuMP.@constraint(ps_m.JuMPmodel, 
                                            initial_duration_on[ix].value - duration_data[2][ix].up  <= ps_m.variables[var_names[1]][name,1])
        ps_m.constraints[name_down][name, 1] = JuMP.@constraint(ps_m.JuMPmodel, 
                                            initial_duration_off[ix].value - duration_data[2][ix].down  <= (1- ps_m.variables[var_names[1]][name,1]))

    end

        for t in time_range[2:end], (ix,name) in enumerate(duration_data[1])

            if t <= duration_data[2][ix].up

                ps_m.constraints[name_up][name, t] = JuMP.@constraint(ps_m.JuMPmodel, 
                                                                 initial_duration_on[ix].value - duration_data[2][ix].up  
                                                                 + sum([ps_m.variables[var_names[2]][name,i] for i in 1:(t-1)]) <= ps_m.variables[var_names[1]][name,t])
                ps_m.constraints[name_down][name, t] = JuMP.@constraint(ps_m.JuMPmodel, 
                                                                initial_duration_on[ix].value - duration_data[2][ix].down  
                                                                + sum([ps_m.variables[var_names[3]][name,i] for i in 1:(t-1)]) <= (1 - ps_m.variables[var_names[1]][name,t]))                                                                 
            else

                ps_m.constraints[name_up][name, t] = JuMP.@constraint(ps_m.JuMPmodel, sum([ps_m.variables[var_names[2]][name,i] for i in (t-duration_data[2][ix].up):t]) <= ps_m.variables[var_names[1]][name,t])
                ps_m.constraints[name_down][name, t] = JuMP.@constraint(ps_m.JuMPmodel, sum([ps_m.variables[var_names[3]][name,i] for i in (t-duration_data[2][ix].down):t]) <= (1 - ps_m.variables[var_names[1]][name,t])) 
        end
    
    end

    return

end