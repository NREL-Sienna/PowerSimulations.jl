@doc raw"""
    norm_two_constraint(ps_m::CanonicalModel,
                            rating_data::Vector{NamedMinMax},
                            cons_name::Symbol,
                            var_names::Tuple{Symbol, Symbol})

Constructs constraint from rating data and related variable tuple.

# Constraint

``` var1[r[1], t] + var2[r[1], t] <= r[2].max^2 ```

where r in rating data and t in time steps.

# LaTeX

`` x_1 + x_2 \leq r_{max}^2 ``

# Arguments
* ps_m::CanonicalModel : the canonical model built in PowerSimulations
* rating_data::Vector{NamedMinMax} : rating data name (1) and min/max (2)
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol} : the names of the variables
- : var_names[1] : var1
- : var_names[2] : var2
"""
function norm_two_constraint(ps_m::CanonicalModel,
                            rating_data::Vector{NamedMinMax},
                            cons_name::Symbol,
                            var_names::Tuple{Symbol, Symbol})
    time_steps = model_time_steps(ps_m)
    var1 = var(ps_m, var_names[1])
    var2 = var(ps_m, var_names[2])
    _add_cons_container!(ps_m, cons_name, (r[1] for r in rating_data), time_steps)
    constraint = con(ps_m, cons_name)        

    for r in rating_data
        for t in time_steps
          constraint[r[1], t] = JuMP.@constraint(ps_m.JuMPmodel, var1[r[1], t] + var2[r[1], t] <= r[2].max^2)
        end
    end

    return

end