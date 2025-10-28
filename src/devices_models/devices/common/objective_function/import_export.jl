_include_min_gen_power_in_constraint(::PSY.Source, ::ActivePowerOutVariable, ::AbstractDeviceFormulation) = false
_include_min_gen_power_in_constraint(::PSY.Source, ::ActivePowerInVariable, ::AbstractDeviceFormulation) = false

function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Source,
    cost_function::PSY.ImportExportCost,
    ::U,
) where {
    T <: ActivePowerOutVariable,
    U <: AbstractSourceFormulation,
}
    component_name = PSY.get_name(component)
    @debug "Import Export Cost" _group = PSI.LOG_GROUP_COST_FUNCTIONS component_name
    import_cost_curves = PSY.get_import_offer_curves(cost_function)
    if !isnothing(import_cost_curves)
        add_pwl_term!(
            false,
            container,
            component,
            cost_function,
            T(),
            U(),
        )
    end
    return
end

function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Source,
    cost_function::PSY.ImportExportCost,
    ::U,
) where {
    T <: ActivePowerInVariable,
    U <: AbstractSourceFormulation,
}
    component_name = PSY.get_name(component)
    @debug "Import Export Cost" _group = PSI.LOG_GROUP_COST_FUNCTIONS component_name
    export_cost_curves = PSY.get_export_offer_curves(cost_function)
    if !isnothing(export_cost_curves)
        add_pwl_term!(
            true,
            container,
            component,
            cost_function,
            T(),
            U(),
        )
    end
    return
end

function _add_vom_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    op_cost::PSY.ImportExportCost,
    ::U,
) where {
    T <: ActivePowerOutVariable,
    U <: AbstractSourceFormulation,
}
    import_cost_curves = PSY.get_import_offer_curves(op_cost)
    if !(isnothing(import_cost_curves))
        _add_vom_cost_to_objective_helper!(
            container,
            T(),
            component,
            op_cost,
            import_cost_curves,
            U(),
        )
    end
    return
end

function PSI._add_vom_cost_to_objective!(
    container::PSI.OptimizationContainer,
    ::T,
    component::PSY.Source,
    op_cost::PSY.ImportExportCost,
    ::U,
) where {
    T <: ActivePowerInVariable,
    U <: AbstractSourceFormulation,
}
    export_cost_curves = PSY.get_export_offer_curves(op_cost)
    if !(isnothing(export_cost_curves))
        _add_vom_cost_to_objective_helper!(
            container,
            T(),
            component,
            op_cost,
            export_cost_curves,
            U(),
        )
    end
    return
end
