@doc raw"""
    device_duration_retrospective(canonical::CanonicalModel,
                                        duration_data::Vector{UpDown},
                                        initial_duration::Matrix{InitialCondition},
                                        cons_name::Symbol,
                                        var_names::Tuple{Symbol, Symbol, Symbol})

This formulation of the duration constraints adds over the start times looking backwards.

# LaTeX

* Minimum up-time constraint:

If ``t \leq d_{min}^{up} - d_{init}^{up}`` and ``d_{init}^{up} > 0``

`` 1 + \sum_{i=t-d_{min}^{up} + 1}^t x_i^{start} - x_t^{on} \leq 0 ``

for i in the set of time steps. Otherwise:

`` \sum_{i=t-d_{min}^{up} + 1}^t x_i^{start} - x_t^{on} \leq 0 ``

for i in the set of time steps.

* Minimum down-time constraint:

If ``t \leq d_{min}^{down} - d_{init}^{down}`` and ``d_{init}^{down} > 0``

`` 1 + \sum_{i=t-d_{min}^{down} + 1}^t x_i^{stop} + x_t^{on} \leq 1 ``

for i in the set of time steps. Otherwise:

`` \sum_{i=t-d_{min}^{down} + 1}^t x_i^{stop} + x_t^{on} \leq 1 ``

for i in the set of time steps.


# Arguments
* canonical::CanonicalModel : the canonical model built in PowerSimulations
* duration_data::Vector{UpDown} : gives how many time steps variable needs to be up or down
* initial_duration::Matrix{InitialCondition} : gives initial conditions for up (column 1) and down (column 2)
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol, Symbol}) : names of the variables
- : var_names[1] : varon
- : var_names[2] : varstart
- : var_names[3] : varstop
"""
function device_duration_retrospective(canonical::CanonicalModel,
                                        duration_data::Vector{UpDown},
                                        initial_duration::Matrix{InitialCondition},
                                        cons_name::Symbol,
                                        var_names::Tuple{Symbol, Symbol, Symbol})

    time_steps = model_time_steps(canonical)

    varon = var(canonical, var_names[1])
    varstart = var(canonical, var_names[2])
    varstop = var(canonical, var_names[3])

    name_up = _middle_rename(cons_name, "_", "up")
    name_down = _middle_rename(cons_name, "_", "dn")

    set_names = (device_name(ic) for ic in initial_duration[:, 1])
    _add_cons_container!(canonical, name_up, set_names, time_steps)
    _add_cons_container!(canonical, name_down, set_names, time_steps)
    con_up = con(canonical, name_up)
    con_down = con(canonical, name_down)

        for t in time_steps
            for (ix, ic) in enumerate(initial_duration[:, 1])
                name = device_name(ic)
                # Minimum Up-time Constraint
                lhs_on = JuMP.GenericAffExpr{Float64, _variable_type(canonical)}(0)
                for i in (t-duration_data[ix].up + 1):t
                    if i in time_steps
                        JuMP.add_to_expression!(lhs_on, varstart[name, i])
                    end
                end
                if t <= max(0, duration_data[ix].up - ic.value) && ic.value > 0
                    JuMP.add_to_expression!(lhs_on, 1)
                end
                con_up[name, t] = JuMP.@constraint(canonical.JuMPmodel, lhs_on - varon[name, t] <= 0.0)
            end

            for (ix, ic) in enumerate(initial_duration[:, 2])
                name = device_name(ic)
                # Minimum Down-time Constraint
                lhs_off = JuMP.GenericAffExpr{Float64, _variable_type(canonical)}(0)
                for i in (t-duration_data[ix].down + 1):t
                    if i in time_steps
                        JuMP.add_to_expression!(lhs_off, varstop[name, i])
                    end
                end
                if t <=  max(0, duration_data[ix].down - ic.value) && ic.value > 0
                    JuMP.add_to_expression!(lhs_off, 1)
                end
                con_down[name, t] = JuMP.@constraint(canonical.JuMPmodel, lhs_off + varon[name, t] <= 1.0)
            end
        end
    return
end
@doc raw"""
    device_duration_look_ahead(canonical::CanonicalModel,
                                duration_data::Vector{UpDown},
                                initial_duration::Matrix{InitialCondition},
                                cons_name::Symbol,
                                var_names::Tuple{Symbol, Symbol, Symbol})

This formulation of the duration constraints looks ahead in the time frame of the model.

# LaTeX

* Minimum up-time constraint:

If ``t \leq d_{min}^{up}``

`` d_{min}^{down}x_t^{stop} - \sum_{i=t-d_{min}^{up} + 1}^t x_i^{on} - x_{init}^{up} \leq 0 ``

for i in the set of time steps. Otherwise:

`` d_{min}^{down}x_t^{stop} - \sum_{i=t-d_{min}^{up} + 1}^t x_i^{on} \leq 0 ``

for i in the set of time steps.

* Minimum down-time constraint:

If ``t \leq d_{min}^{down}``

`` d_{min}^{up}x_t^{start} - \sum_{i=t-d_{min^{down} + 1}^t (1 - x_i^{on}) - x_{init}^{down} \leq 0 ``

for i in the set of time steps. Otherwise:

`` d_{min}^{up}x_t^{start} - \sum_{i=t-d_{min^{down} + 1}^t (1 - x_i^{on}) \leq 0 ``

for i in the set of time steps.


# Arguments
* canonical::CanonicalModel : the canonical model built in PowerSimulations
* duration_data::Vector{UpDown} : gives how many time steps variable needs to be up or down
* initial_duration::Matrix{InitialCondition} : gives initial conditions for up (column 1) and down (column 2)
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol, Symbol}) : names of the variables
- : var_names[1] : varon
- : var_names[2] : varstart
- : var_names[3] : varstop
"""
function device_duration_look_ahead(canonical::CanonicalModel,
                             duration_data::Vector{UpDown},
                             initial_duration::Matrix{InitialCondition},
                             cons_name::Symbol,
                             var_names::Tuple{Symbol, Symbol, Symbol})

    time_steps = model_time_steps(canonical)

    varon = var(canonical, var_names[1])
    varstart = var(canonical, var_names[2])
    varstop = var(canonical, var_names[3])

    name_up = _middle_rename(cons_name, "_", "up")
    name_down = _middle_rename(cons_name, "_", "dn")

    set_names = (device_name(ic) for ic in initial_duration[:, 1])
    _add_cons_container!(canonical, name_up, set_names, time_steps)
    _add_cons_container!(canonical, name_down, set_names, time_steps)
    con_up = con(canonical, name_up)
    con_down = con(canonical, name_down)

    for t in time_steps
        for (ix, ic) in enumerate(initial_duration[:, 1])
            name = device_name(ic)
            # Minimum Up-time Constraint
            lhs_on = JuMP.GenericAffExpr{Float64, _variable_type(canonical)}(0)
            for i in (t-duration_data[ix].up + 1):t
                if i in time_steps
                    JuMP.add_to_expression!(lhs_on, varon[name, i])
                end
            end
            if t <= duration_data[ix].up
                lhs_on += ic.value
            end
            con_up[name, t] = JuMP.@constraint(canonical.JuMPmodel,
                                                varstop[name, t]*duration_data[ix].up - lhs_on <= 0.0)
        end

        for (ix, ic) in enumerate(initial_duration[:, 2])
            name = device_name(ic)
            # Minimum Down-time Constraint
            lhs_off = JuMP.GenericAffExpr{Float64, _variable_type(canonical)}(0)
            for i in (t-duration_data[ix].down + 1):t
                if i in time_steps
                    JuMP.add_to_expression!(lhs_off, (1-varon[name, i]))
                end
            end
            if t <= duration_data[ix].down
                lhs_off += ic.value
            end
            con_down[name, t] = JuMP.@constraint(canonical.JuMPmodel,
                                                 varstart[name, t]*duration_data[ix].down - lhs_off <= 0.0 )
        end
    end

    return

end


@doc raw"""
    device_duration_param(canonical::CanonicalModel,
                             duration_data::Vector{UpDown},
                             initial_duration_on::Vector{InitialCondition},
                             initial_duration_off::Vector{InitialCondition},
                             cons_name::Symbol,
                             var_names::Tuple{Symbol, Symbol, Symbol})

This formulation of the duration constraints considers parameters.


# LaTeX

* Minimum up-time constraint:

If ``t \leq d_{min}^{up}``

`` d_{min}^{down}x_t^{stop} - \sum_{i=t-d_{min}^{up} + 1}^t x_i^{on} - x_{init}^{up} \leq 0 ``

for i in the set of time steps. Otherwise:

`` \sum_{i=t-d_{min}^{up} + 1}^t x_i^{start} - x_t^{on} \leq 0 ``

for i in the set of time steps.

* Minimum down-time constraint:

If ``t \leq d_{min}^{down}``

`` d_{min}^{up}x_t^{start} - \sum_{i=t-d_{min^{down} + 1}^t (1 - x_i^{on}) - x_{init}^{down} \leq 0 ``

for i in the set of time steps. Otherwise:

`` \sum_{i=t-d_{min}^{down} + 1}^t x_i^{stop} + x_t^{on} \leq 1 ``

for i in the set of time steps.

# Arguments
* canonical::CanonicalModel : the canonical model built in PowerSimulations
* duration_data::Vector{UpDown} : gives how many time steps variable needs to be up or down
* initial_duration_on::Vector{InitialCondition} : gives initial number of time steps variable is up
* initial_duration_off::Vector{InitialCondition} : gives initial number of time steps variable is down
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol, Symbol}) : names of the variables
- : var_names[1] : varon
- : var_names[2] : varstart
- : var_names[3] : varstop
"""
function device_duration_param(canonical::CanonicalModel,
                               duration_data::Vector{UpDown},
                               initial_duration::Matrix{InitialCondition},
                               cons_name::Symbol,
                               var_names::Tuple{Symbol, Symbol, Symbol})

    time_steps = model_time_steps(canonical)

    varon = var(canonical, var_names[1])
    varstart = var(canonical, var_names[2])
    varstop = var(canonical, var_names[3])

    name_up = _middle_rename(cons_name, "_", "up")
    name_down = _middle_rename(cons_name, "_", "dn")

    set_names = (device_name(ic) for ic in initial_duration[:, 1])
    _add_cons_container!(canonical, name_up, set_names, time_steps)
    _add_cons_container!(canonical, name_down, set_names, time_steps)
    con_up = con(canonical, name_up)
    con_down = con(canonical, name_down)

    for t in time_steps
        for (ix, ic) in enumerate(initial_duration[:, 1])
            name = device_name(ic)
            # Minimum Up-time Constraint
            lhs_on = JuMP.GenericAffExpr{Float64, _variable_type(canonical)}(0)
            for i in (t-duration_data[ix].up + 1):t
                if t <= duration_data[ix].up
                    if in(i, time_steps)
                        JuMP.add_to_expression!(lhs_on, varon[name, i])
                    end
                else
                    JuMP.add_to_expression!(lhs_on, varstart[name, i])
                end
            end
            if t <= duration_data[ix].up
                lhs_on += ic.value
                con_up[name, t] = JuMP.@constraint(canonical.JuMPmodel,
                                      varstop[name, t]*duration_data[ix].up - lhs_on <= 0.0)
            else
                con_up[name, t] = JuMP.@constraint(canonical.JuMPmodel,
                                       lhs_on - varon[name, t] <= 0.0)
            end
        end

        for (ix, ic) in enumerate(initial_duration[:, 2])
            name = device_name(ic)
            # Minimum Down-time Constraint
            lhs_off = JuMP.GenericAffExpr{Float64, _variable_type(canonical)}(0)
            for i in (t-duration_data[ix].down + 1):t
                if t <= duration_data[ix].down
                    if in(i, time_steps)
                        JuMP.add_to_expression!(lhs_off, (1-varon[name, i]))
                    end
                else
                    JuMP.add_to_expression!(lhs_off, varstop[name, i])
                end
            end
            if t <= duration_data[ix].down
                lhs_off += ic.value
                con_down[name, t] = JuMP.@constraint(canonical.JuMPmodel, varstart[name, t]*duration_data[ix].down - lhs_off <= 0.0)
            else
                con_down[name, t] = JuMP.@constraint(canonical.JuMPmodel, lhs_off + varon[name, t] <= 1.0)
            end
        end
    end
    return
end
