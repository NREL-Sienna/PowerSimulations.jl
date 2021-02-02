@doc raw"""
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
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* initial_conditions::Vector{InitialCondition} : for time zero 'varenergy'
* efficiency_data::Tuple{Vector{String}, Vector{InOut}} :: charging/discharging efficiencies
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol, Symbol} : the names of the variables
- : var_names[1] : varin
- : var_names[2] : varout
- : var_names[3] : varenergy

"""
function power_inflow(
    psi_container::PSIContainer,
    constraint_infos::Vector{HybridPowerInflowConstraintInfo},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    name_index = [d.component_name for d in constraint_infos]
    varin = get_variable(psi_container, var_names[1])
    varload = get_variable(psi_container, var_names[2])
    varstorage = get_variable(psi_container, var_names[3])

    constraint = add_cons_container!(psi_container, cons_name, name_index, time_steps)

    for (ix, info) in enumerate(constraint_infos), t in time_steps
        name = info.component_name
        expr = JuMP.AffExpr(0.0)
        if info.has_load
            JuMP.add_to_expression!(expr, varload[name, t])
        end
        if info.has_storage
            JuMP.add_to_expression!(expr, varstorage[name, t])
        end

        constraint[name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, varin[name, t] == expr)
    end

    return
end

function power_outflow(
    psi_container::PSIContainer,
    constraint_infos::Vector{HybridPowerOutflowConstraintInfo},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol, Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    name_index = [d.component_name for d in constraint_infos]

    varout = get_variable(psi_container, var_names[1])
    varthermal = get_variable(psi_container, var_names[2])
    varrenewable = get_variable(psi_container, var_names[3])
    varstorage = get_variable(psi_container, var_names[4])

    constraint = add_cons_container!(psi_container, cons_name, name_index, time_steps)

    for (ix, info) in enumerate(constraint_infos), t in time_steps
        name = info.component_name
        expr = JuMP.AffExpr(0.0)
        if info.has_thermal
            JuMP.add_to_expression!(expr, varthermal[name, t])
        end
        if info.has_renewable
            JuMP.add_to_expression!(expr, varrenewable[name, t])
        end
        if info.has_storage
            JuMP.add_to_expression!(expr, varstorage[name, t])
        end

        constraint[name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, varout[name, t] == expr)
    end

    return
end

function invertor_rating(
    psi_container::PSIContainer,
    constraint_infos::Vector{HybridInvertorConstraintInfo},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    name_index = [d.component_name for d in constraint_infos]

    var_active_out = get_variable(psi_container, var_names[1])
    var_active_in = get_variable(psi_container, var_names[2])
    var_reactive = get_variable(psi_container, var_names[3])

    constraint = add_cons_container!(psi_container, cons_name, name_index, time_steps)

    for (ix, info) in enumerate(constraint_infos), t in time_steps
        name = info.component_name
        constraint[name, t] = JuMP.@constraint(
            psi_container.JuMPmodel,
            (var_active_out[name, t] - var_active_in[name, t])^2 +
            var_reactive[name, t]^2 == info.rating^2
        )
    end

    return
end

function reactive_balance(
    psi_container::PSIContainer,
    constraint_infos::Vector{HybridReactiveConstraintInfo},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol, Symbol, Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    name_index = [d.component_name for d in constraint_infos]

    var_reactive = get_variable(psi_container, var_names[1])
    var_thermal = get_variable(psi_container, var_names[2])
    var_load = get_variable(psi_container, var_names[3])
    var_storage = get_variable(psi_container, var_names[4])
    var_renewable = get_variable(psi_container, var_names[5])

    constraint = add_cons_container!(psi_container, cons_name, name_index, time_steps)

    for (ix, info) in enumerate(constraint_infos), t in time_steps
        name = info.component_name
        expr = JuMP.AffExpr(0.0)
        if info.has_thermal
            JuMP.add_to_expression!(expr, var_thermal[name, t])
        end
        if info.has_load
            JuMP.add_to_expression!(expr, var_load[name, t])
        end
        if info.has_renewable
            JuMP.add_to_expression!(expr, var_renewable[name, t])
        end
        if info.has_storage
            JuMP.add_to_expression!(expr, var_storage[name, t])
        end
        constraint[name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, var_reactive[name, t] == expr)
    end

    return
end
