@doc raw"""
    energy_balance(canonical::Canonical,
                        initial_conditions::Vector{InitialCondition},
                        efficiency_data::Tuple{Vector{String}, Vector{InOut}},
                        cons_name::Symbol,
                        var_names::Tuple{Symbol, Symbol, Symbol})

Constructs multi-timestep constraint from initial condition, efficiency data, and variable tuple

# Constraints

If t = 1:

``` varenergy[name, 1] == initial_conditions[ix].value + varin[name, 1]*eff_in*fraction_of_hour - varout[name, 1]*fraction_of_hour/eff_out ```

If t > 1:

``` varenergy[name, t] == varenergy[name, t-1] + varin[name, t]*eff_in*fraction_of_hour - varout[name, t]*fraction_of_hour/eff_out ```

# LaTeX

`` x^{energy}_1 == x^{energy}_{init} + frhr \eta^{in} x^{in}_1 - \frac{frhr}{\eta^{out}} x^{out}_1, \text{ for } t = 1 ``

`` x^{energy}_t == x^{energy}_{t-1} + frhr \eta^{in} x^{in}_t - \frac{frhr}{\eta^{out}} x^{out}_t, \forall t \geq 2 ``

# Arguments
* canonical::Canonical : the canonical model built in PowerSimulations
* initial_conditions::Vector{InitialCondition} : for time zero 'varenergy'
* efficiency_data::Tuple{Vector{String}, Vector{InOut}} :: charging/discharging efficiencies
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol, Symbol} : the names of the variables
- : var_names[1] : varin
- : var_names[2] : varout
- : var_names[3] : varenergy

"""
function energy_balance(canonical::Canonical,
                        initial_conditions::Vector{InitialCondition},
                        efficiency_data::Tuple{Vector{String}, Vector{InOut}},
                        cons_name::Symbol,
                        var_names::Tuple{Symbol, Symbol, Symbol})

    time_steps = model_time_steps(canonical)
    resolution = model_resolution(canonical)
    fraction_of_hour = Dates.value(Dates.Minute(resolution))/60
    name_index = efficiency_data[1]

    varin = get_variable(canonical, var_names[1])
    varout = get_variable(canonical, var_names[2])
    varenergy = get_variable(canonical, var_names[3])

    constraint = _add_cons_container!(canonical, cons_name, name_index, time_steps)

    for (ix, name) in enumerate(name_index)
        eff_in = efficiency_data[2][ix].in
        eff_out = efficiency_data[2][ix].out

        constraint[name, 1] = JuMP.@constraint(canonical.JuMPmodel,
                                   varenergy[name, 1] == initial_conditions[ix].value + varin[name, 1]*eff_in*fraction_of_hour
                                                    - (varout[name, 1])*fraction_of_hour/eff_out)

    end

    for t in time_steps[2:end], (ix, name) in enumerate(name_index)
        eff_in = efficiency_data[2][ix].in
        eff_out = efficiency_data[2][ix].out

        constraint[name, t] = JuMP.@constraint(canonical.JuMPmodel,
                                   varenergy[name, t] == varenergy[name, t-1] + varin[name, t]*eff_in*fraction_of_hour
                                                    - (varout[name, t])*fraction_of_hour/eff_out)
    end

    return

end
