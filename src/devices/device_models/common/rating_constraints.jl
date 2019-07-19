@doc raw"""
    function norm_two_constraint(ps_m::CanonicalModel,
                            rating_data::Tuple{Vector{String}, Vector{Float64}},
                            cons_name::Symbol,
                            var_names::Tuple{Symbol, Symbol})

Constructs multi-timestep constraint from rating data and related variable tuple.

# Constraint

`` var1[r[1], t] + var2[r[1], t] <= rating_data[ix][2]^2 ``

where (ix, r) in enumerate(rating_data[1]).

# Arguments
* ps_m::CanonicalModel : the canonical model built in PowerSimulations
* rating_data::Tuple{Vector{String}, Vector{Float64}} : rating data name (1) and values (2)
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol, Symbol} : the names of the variables
- : var_names[1] : var1
- : var_names[2] : var2
"""
function norm_two_constraint(ps_m::CanonicalModel,
                            rating_data::Tuple{Vector{String}, Vector{Float64}},
                            cons_name::Symbol,
                            var_names::Tuple{Symbol, Symbol})
    time_steps = model_time_steps(ps_m)
    var1 = var(ps_m, var_names[1])
    var2 = var(ps_m, var_names[2])
    _add_cons_container!(ps_m, cons_name, rating_data[1], time_steps)
    constraint = con(ps_m, cons_name)

    for t in time_steps, (ix, r) in enumerate(rating_data[1])
        
        constraint[r, t] = JuMP.@constraint(ps_m.JuMPmodel, var1[r[1], t] + var2[r[1], t] <= rating_data[ix][2]^2)

    end

    return

end