struct StateInfo
    aux_variable_values::Dict{AuxVarKey, DataFrames.DataFrame}
    variable_values::Dict{VariableKey, DataFrames.DataFrame}
    dual_values::Dict{ConstraintKey, DataFrames.DataFrame}
    parameter_values::Dict{ParameterKey, DataFrames.DataFrame}
    expression_values::Dict{ExpressionKey, DataFrames.DataFrame}
end

struct SimulationState
    decision_states::StateInfo
    system_state::StateInfo
end

#================================================================
function update_cache!(
    sim::Simulation,
    ::CacheKey{StoredEnergy, D},
    model::DecisionModel,
) where {D <: PSY.Device}
    c = get_cache(sim, StoredEnergy, D)
    variable = get_variable(model.internal.container, c.ref)
    t = get_end_of_interval_step(model)
    for name in variable.axes[1]
        device_energy = JuMP.value(variable[name, t])
        @debug name, device_energy
        c.value[name] = device_energy
        @debug("Cache value StoredEnergy for device $name set to $(c.value[name])")
    end

    return
end
=#
