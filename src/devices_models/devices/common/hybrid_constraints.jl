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
* psi_container::OptimizationContainer : the psi_container model built in PowerSimulations
* initial_conditions::Vector{InitialCondition} : for time zero 'varenergy'
* efficiency_data::Tuple{Vector{String}, Vector{InOut}} :: charging/discharging efficiencies
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol, Symbol} : the names of the variables
- : var_names[1] : varin
- : var_names[2] : varout
- : var_names[3] : varenergy

"""
function power_inflow(
    psi_container::OptimizationContainer,
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
            idx = get_index(name, t, PSY.ElectricLoad)
            JuMP.add_to_expression!(expr, varload[idx])
        end
        if info.has_storage
            idx = get_index(name, t, PSY.Storage)
            JuMP.add_to_expression!(expr, varstorage[idx])
        end

        constraint[name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, varin[name, t] == expr)
    end

    return
end

function power_inflow(
    psi_container::OptimizationContainer,
    constraint_infos::Vector{
        Tuple{HybridPowerInflowConstraintInfo, HybridPowerOutflowConstraintInfo},
    },
    cons_name::Tuple{Symbol, Symbol},
    var_names::Tuple{Symbol, Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    name_index = [d.component_name for d in constraint_infos]
    varin = get_variable(psi_container, var_names[1])
    varin_subcomp = get_variable(psi_container, var_names[2])
    varin_storage = get_variable(psi_container, var_names[3])

    constraint_in = add_cons_container!(psi_container, cons_name[1], name_index, time_steps)
    constraint_batt =
        add_cons_container!(psi_container, cons_name[2], name_index, time_steps)

    for (inflow, outflow) in enumerate(constraint_infos), t in time_steps
        name = inflow.component_name
        expr = JuMP.AffExpr(0.0)
        if inflow.has_load
            idx = get_index(name, t, PSY.ElectricLoad)
            JuMP.add_to_expression!(expr, varin[idx])
        end
        constraint_in[name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, varin[name, t] == expr)

        expr_batt = JuMP.AffExpr(0.0)
        if inflow.has_storage
            idx = get_index(name, t, PSY.Storage)
            JuMP.add_to_expression!(expr_batt, varin_storage[idx])
        end
        if outflow.has_thermal
            idx = get_index(name, t, PSY.ThermalGen)
            JuMP.add_to_expression!(expr_batt, -varin[idx])
        end
        if outflow.has_renewable
            idx = get_index(name, t, PSY.RenewableGen)
            JuMP.add_to_expression!(expr_batt, -varin[idx])
        end
        constraint_batt[name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, expr_batt == 0.0)
    end
    return
end

function power_outflow(
    psi_container::OptimizationContainer,
    constraint_infos::Vector{HybridPowerOutflowConstraintInfo},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    name_index = [d.component_name for d in constraint_infos]

    varout = get_variable(psi_container, var_names[1])
    varp = get_variable(psi_container, var_names[2])
    varstorage = get_variable(psi_container, var_names[3])

    constraint = add_cons_container!(psi_container, cons_name, name_index, time_steps)

    for (ix, info) in enumerate(constraint_infos), t in time_steps
        name = info.component_name
        expr = JuMP.AffExpr(0.0)
        if info.has_thermal
            idx = get_index(name, t, PSY.ThermalGen)
            JuMP.add_to_expression!(expr, varp[idx])
        end
        if info.has_renewable
            idx = get_index(name, t, PSY.RenewableGen)
            JuMP.add_to_expression!(expr, varp[idx])
        end
        if info.has_storage
            idx = get_index(name, t, PSY.Storage)
            JuMP.add_to_expression!(expr, varstorage[idx])
        end

        constraint[name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, varout[name, t] == expr)
    end

    return
end

function invertor_rating(
    psi_container::OptimizationContainer,
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
    psi_container::OptimizationContainer,
    constraint_infos::Vector{HybridReactiveConstraintInfo},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol},
)
    time_steps = model_time_steps(psi_container)
    name_index = [d.component_name for d in constraint_infos]

    var_reactive = get_variable(psi_container, var_names[1])
    var_subcomp = get_variable(psi_container, var_names[2])

    constraint = add_cons_container!(psi_container, cons_name, name_index, time_steps)

    for (ix, info) in enumerate(constraint_infos), t in time_steps
        name = info.component_name
        expr = JuMP.AffExpr(0.0)
        if info.has_thermal
            idx = get_index(name, t, PSY.ThermalGen)
            JuMP.add_to_expression!(expr, var_subcomp[idx])
        end
        if info.has_load
            idx = get_index(name, t, PSY.ElectricLoad)
            JuMP.add_to_expression!(expr, var_subcomp[idx])
        end
        if info.has_renewable
            idx = get_index(name, t, PSY.RenewableGen)
            JuMP.add_to_expression!(expr, var_subcomp[idx])
        end
        if info.has_storage
            idx = get_index(name, t, PSY.Storage)
            JuMP.add_to_expression!(expr, var_subcomp[idx])
        end
        constraint[name, t] =
            JuMP.@constraint(psi_container.JuMPmodel, var_reactive[name, t] == expr)
    end

    return
end
