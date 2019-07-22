"""
This formulation of the duration constraints, adds over the start times looking backwards.

"""
function device_duration_retrospective(ps_m::CanonicalModel,
                                        set_names::Vector{String},
                                        duration_data::Vector{UpDown},
                                        initial_duration_on::Vector{InitialCondition},
                                        initial_duration_off::Vector{InitialCondition},
                                        cons_name::Symbol,
                                        var_names::Tuple{Symbol, Symbol, Symbol})

    time_steps = model_time_steps(ps_m)
    name_up = Symbol(cons_name, :_up)
    name_down = Symbol(cons_name, :_down)

    ps_m.constraints[name_up] = JuMPConstraintArray(undef, set_names, time_steps)
    ps_m.constraints[name_down] = JuMPConstraintArray(undef, set_names, time_steps)



        for t in time_steps, (ix,name) in enumerate(set_names)
            # Minimum Up-time Constraint
            lhs_on = JuMP.GenericAffExpr{Float64, _variable_type(ps_m)}(0);
            for i in (t-duration_data[ix].up + 1):t 
                if in(i,time_steps) 
                    JuMP.add_to_expression!(lhs_on,ps_m.variables[var_names[2]][name,i])
                end
            end
            if t <= max(1, duration_data[ix].up - initial_duration_on[ix].value) &&  initial_duration_on[ix].value > 0
                JuMP.add_to_expression!(lhs_on,1) ; 
            end
            
            ps_m.constraints[name_up][name, t] = JuMP.@constraint(ps_m.JuMPmodel, 
                lhs_on <= ps_m.variables[var_names[1]][name,t])
            
            # Minimum Down-time Constraint
            lhs_off = JuMP.GenericAffExpr{Float64, _variable_type(ps_m)}(0);
            for i in (t-duration_data[ix].down + 1):t
                if in(i,time_steps)  
                    JuMP.add_to_expression!(lhs_off,ps_m.variables[var_names[3]][name,i]) ; 
                end
            end
            if t <=  max(1, duration_data[ix].down - initial_duration_off[ix].value) &&  initial_duration_off[ix].value > 0
                JuMP.add_to_expression!(lhs_off,1) ; 
            end

            ps_m.constraints[name_down][name, t] = JuMP.@constraint(ps_m.JuMPmodel, 
                lhs_off <= (1 - ps_m.variables[var_names[1]][name,t]))

        end

    return

end


"""
This formulation of the duration constraints, uses an Indicator parameter value to show if the constraint was satisfied in the past.

"""
function device_duration_ind(ps_m::CanonicalModel,
                             set_names::Vector{String},
                             duration_data::Vector{UpDown},
                             duration_ind_status_on::Vector{InitialCondition},
                             duration_ind_status_off::Vector{InitialCondition},
                             cons_name::Symbol,
                             var_names::Tuple{Symbol, Symbol, Symbol})


    time_steps = model_time_steps(ps_m)
    name_up = Symbol(cons_name, :_up)
    name_down = Symbol(cons_name, :_down)

    ps_m.constraints[name_up] = JuMPConstraintArray(undef, set_names, time_steps)
    ps_m.constraints[name_down] = JuMPConstraintArray(undef, set_names, time_steps)

    for (ix, name) in enumerate(set_names)
        ps_m.constraints[name_up][name, 1] = JuMP.@constraint(ps_m.JuMPmodel,
                                            duration_ind_status_on[ix].value <= ps_m.variables[var_names[1]][name, 1])
        ps_m.constraints[name_down][name, 1] = JuMP.@constraint(ps_m.JuMPmodel,
                                            duration_ind_status_off[ix].value <= (1- ps_m.variables[var_names[1]][name, 1]))
    end

    for t in time_steps[2:end], (ix, name) in enumerate(set_names)
        if t <= duration_data[ix].up
            ps_m.constraints[name_up][name, t] = JuMP.@constraint(ps_m.JuMPmodel,
                                                            sum([ps_m.variables[var_names[2]][name, i] for i in 1:(t-1)]) + duration_ind_status_on[ix].value <= ps_m.variables[var_names[1]][name, t])
         else
            ps_m.constraints[name_up][name, t] = JuMP.@constraint(ps_m.JuMPmodel, sum([ps_m.variables[var_names[2]][name, i] for i in (t-duration_data[ix].up):t]) <= ps_m.variables[var_names[1]][name, t])
        end

        if t <= duration_data[ix].down
            ps_m.constraints[name_down][name, t] = JuMP.@constraint(ps_m.JuMPmodel,
                                                            sum([ps_m.variables[var_names[3]][name, i] for i in 1:(t-1)]) + duration_ind_status_off[ix].value <= (1 - ps_m.variables[var_names[1]][name, t]))
        else
            ps_m.constraints[name_down][name, t] = JuMP.@constraint(ps_m.JuMPmodel, sum([ps_m.variables[var_names[3]][name, i] for i in (t-duration_data[ix].down):t]) <= (1 - ps_m.variables[var_names[1]][name, t]))
        end

    end

    return

end

function device_duration_look_ahead(ps_m::CanonicalModel,
                             set_names::Vector{String},
                             duration_data::Vector{UpDown},
                             initial_duration_on::Vector{InitialCondition},
                             initial_duration_off::Vector{InitialCondition},
                             cons_name::Symbol,
                             var_names::Tuple{Symbol,Symbol,Symbol})

    time_steps = model_time_steps(ps_m)
    name_up = Symbol(cons_name,:_up)
    name_down = Symbol(cons_name,:_down)

    ps_m.constraints[name_up] = JuMPConstraintArray(undef, set_names, time_steps)
    ps_m.constraints[name_down] = JuMPConstraintArray(undef, set_names, time_steps)


    for t in time_steps, (ix,name) in enumerate(set_names)
        # Minimum Up-time Constraint
        lhs_on = JuMP.GenericAffExpr{Float64, _variable_type(ps_m)}(0);
        for i in t-duration_data[ix].up:t
            if in(i,time_steps)  
                JuMP.add_to_expression!(lhs_on,ps_m.variables[var_names[1]][name,i])
            end
        end
        if t <= duration_data[ix].up
            lhs_on += initial_duration_on[ix].value; #TODO: Change to add_to_expression
        end

        ps_m.constraints[name_up][name, t] = JuMP.@constraint(ps_m.JuMPmodel, 
            lhs_on >= ps_m.variables[var_names[3]][name,t]*duration_data[ix].up)

        # Minimum Down-time Constraint
        lhs_off = JuMP.GenericAffExpr{Float64, _variable_type(ps_m)}(0);
        for i in t-duration_data[ix].down:t
            if in(i,time_steps) 
                JuMP.add_to_expression!(lhs_off,(1-ps_m.variables[var_names[1]][name,i]));
            end
        end
        if t <= duration_data[ix].down
            lhs_off += initial_duration_on[ix].value ; #TODO: Change to add_to_expression
        end

        ps_m.constraints[name_down][name, t] = JuMP.@constraint(ps_m.JuMPmodel, 
            lhs_off >= ps_m.variables[var_names[2]][name,t]*duration_data[ix].down)

    end
end

function device_duration_param(ps_m::CanonicalModel,
                             set_names::Vector{String},
                             duration_data::Vector{UpDown},
                             initial_duration_on::Vector{InitialCondition},
                             initial_duration_off::Vector{InitialCondition},
                             cons_name::Symbol,
                             var_names::Tuple{Symbol,Symbol,Symbol})

    time_steps = model_time_steps(ps_m)
    name_up = Symbol(cons_name,:_up)
    name_down = Symbol(cons_name,:_down)

    ps_m.constraints[name_up] = JuMPConstraintArray(undef, set_names, time_steps)
    ps_m.constraints[name_down] = JuMPConstraintArray(undef, set_names, time_steps)

    for t in time_steps, (ix,name) in enumerate(set_names)
        # Minimum Up-time Constraint
        lhs_on = JuMP.GenericAffExpr{Float64, _variable_type(ps_m)}(0);
        for i in t-duration_data[ix].up:t
            if t <= duration_data[ix].up
                if in(i,time_steps)
                    JuMP.add_to_expression!(lhs_on,ps_m.variables[var_names[1]][name,i]);
                end
            else
                JuMP.add_to_expression!(lhs_on,ps_m.variables[var_names[2]][name,i]);
            end
        end
        if t <= duration_data[ix].up
            lhs_on =+ initial_duration_on[ix].value; #TODO: Change to add_to_expression
            ps_m.constraints[name_up][name, t] = JuMP.@constraint(ps_m.JuMPmodel,
                lhs_on >= ps_m.variables[var_names[3]][name,t]*duration_data[ix].up)
         else
            ps_m.constraints[name_up][name, t] = JuMP.@constraint(ps_m.JuMPmodel, 
                lhs_on <= ps_m.variables[var_names[1]][name,t])
            
        end
        
        # Minimum Down-time Constraint
        lhs_off = JuMP.GenericAffExpr{Float64, _variable_type(ps_m)}(0);
        for i in t-duration_data[ix].up:t
            if t <= duration_data[ix].up
                if in(i,time_steps)
                    JuMP.add_to_expression!(lhs_off,(1-ps_m.variables[var_names[1]][name,i])) ;
                end
            else
                JuMP.add_to_expression!(lhs_off,ps_m.variables[var_names[3]][name,i]);
            end
        end
        if t <= duration_data[ix].down
            lhs_off += initial_duration_on[ix].value; #TODO: Change to add_to_expression
            ps_m.constraints[name_down][name, t] = JuMP.@constraint(ps_m.JuMPmodel,
                lhs_off >= ps_m.variables[var_names[2]][name,t]*duration_data[ix].down)
        else
            ps_m.constraints[name_down][name, t] = JuMP.@constraint(ps_m.JuMPmodel, 
                lhs_off <= (1 - ps_m.variables[var_names[1]][name,t]))
        end

    end
end