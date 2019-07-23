@doc raw"""
    device_commitment(ps_m::CanonicalModel,
                        initial_conditions::Vector{InitialCondition},
                        cons_name::Symbol,
                        var_names::Tuple{Symbol, Symbol, Symbol})

Constructs multi-timestep constraint from initial conditions and binary variable tuple.

# Constraints

``` varstart + varstop <= 1.0 ```

If t = 1:

``` varon[name, 1] == ic.value + varstart[name, 1] - varstop[name, 1] ```

where ic in initial_condtions.

If t > 1:

``` varon[name, t] == varon[name, t-1] + varstart[name, t] - varstop[name, t] ```

# LaTeX

`` x^{on}_t + x^{off}_t \leq 1.0 \forall t ``

`` x^{on}_1 = x^{on}_{init} + x^{start}_1 - x^{stop}_1, \text{ for } t = 1 ``

`` x^{on}_t = x^{on}_{t-1} + x^{start}_t - x^{stop}_t, \forall t \geq 2 ``


# Arguments
* ps_m::CanonicalModel : the canonical model built in PowerSimulations
* initial_conditions::Vector{InitialCondition} : for time zero 'varon'
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol, Symbol} : the names of the variables
-  : var_names[1] : varstart
-  : var_names[2] : varstop
-  : var_names[3] : varon
"""
function device_commitment(ps_m::CanonicalModel,
                        initial_conditions::Vector{InitialCondition},
                        cons_name::Symbol,
                        var_names::Tuple{Symbol, Symbol, Symbol})

    time_steps = model_time_steps(ps_m)
    varstart = var(ps_m, var_names[1])
    varstop = var(ps_m, var_names[2])
    varon = var(ps_m, var_names[3])
    varstart_names = axes(varstart, 1)
    _add_cons_container!(ps_m, cons_name, varstart_names, time_steps)
    constraint = con(ps_m, cons_name)
    aux_cons_name = _middle_rename(cons_name, "_", "aux")
    _add_cons_container!(ps_m, aux_cons_name, varstart_names, time_steps)
    aux_constraint = con(ps_m, aux_cons_name)

    for ic in initial_conditions
        name = PSY.get_name(ic.device)
        constraint[name, 1] = JuMP.@constraint(ps_m.JuMPmodel,
                               varon[name, 1] == ic.value + varstart[name, 1] - varstop[name, 1])
        aux_constraint[name, 1] = JuMP.@constraint(ps_m.JuMPmodel,
                               varstart[name, 1] + - varstop[name, 1] <= 1.0)
    end

    for t in time_steps[2:end], i in initial_conditions
        name = PSY.get_name(i.device)
        constraint[name, t] = JuMP.@constraint(ps_m.JuMPmodel,
                        varon[name, t] == varon[name, t-1] + varstart[name, t] - varstop[name, t])
        aux_constraint[name, 1] = JuMP.@constraint(ps_m.JuMPmodel,
                                varstart[name, t] + - varstop[name, t] <= 1.0)
    end

    return

end