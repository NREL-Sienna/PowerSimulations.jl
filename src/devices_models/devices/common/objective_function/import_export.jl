_include_min_gen_power_in_constraint(
    ::PSY.Source,
    ::ActivePowerOutVariable,
    ::AbstractDeviceFormulation,
) = false
_include_min_gen_power_in_constraint(
    ::PSY.Source,
    ::ActivePowerInVariable,
    ::AbstractDeviceFormulation,
) = false

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

# _process_occ_parameters_helper and the helpers it depends on (even purely IEC ones) are in objective_function/market_bid.jl
function process_import_export_parameters!(
    container::OptimizationContainer,
    devices_in,
    model::DeviceModel,
)
    devices = filter(_has_import_export_cost, collect(devices_in))

    for param in (
        IncrementalPiecewiseLinearSlopeParameter(),
        IncrementalPiecewiseLinearBreakpointParameter(),
        DecrementalPiecewiseLinearSlopeParameter(),
        DecrementalPiecewiseLinearBreakpointParameter(),
    )
        # Validate and add the parameters
        _process_occ_parameters_helper(param, container, model, devices)
    end
end
