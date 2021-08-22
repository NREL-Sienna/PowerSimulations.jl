@doc raw"""
Constructs constraint from rating data and related variable tuple.

# Constraint

``` var1[r[1], t]^2 + var2[r[1], t]^2 <= r[2]^2 ```

where r in rating data and t in time steps.

# LaTeX

`` x_1^2 + x_2^2 \leq r^2 ``

# Arguments
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* rating_data::Vector{Tuple{String, Float64}} : rating data name (1) and value (2)
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol} : the names of the variables
- : var_keys[1] : var1
- : var_keys[2] : var2
"""
function rating_constraint!(
    container::OptimizationContainer,
    rating_data::Vector{Tuple{String, Float64}},
    cons_type::ConstraintType,
    var_types::Tuple{VariableType, VariableType},
    ::Type{T},
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    var1 = get_variable(container, var_types[1], T)
    var2 = get_variable(container, var_types[2], T)
    add_cons_container!(container, cons_type, T, [r[1] for r in rating_data], time_steps)
    constraint = get_constraint(container, cons_type, T)

    for r in rating_data
        for t in time_steps
            constraint[r[1], t] = JuMP.@constraint(
                container.JuMPmodel,
                var1[r[1], t]^2 + var2[r[1], t]^2 <= r[2]^2
            )
        end
    end

    return
end
