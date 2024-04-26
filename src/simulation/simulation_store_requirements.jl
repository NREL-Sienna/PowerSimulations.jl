struct SimulationModelStoreRequirements
    duals::Dict{ConstraintKey, Dict{String, Any}}
    parameters::Dict{ParameterKey, Dict{String, Any}}
    variables::Dict{VariableKey, Dict{String, Any}}
    aux_variables::Dict{AuxVarKey, Dict{String, Any}}
    expressions::Dict{ExpressionKey, Dict{String, Any}}
end

function SimulationModelStoreRequirements()
    return SimulationModelStoreRequirements(
        Dict{ConstraintKey, Dict{String, Any}}(),
        Dict{ParameterKey, Dict{String, Any}}(),
        Dict{VariableKey, Dict{String, Any}}(),
        Dict{AuxVarKey, Dict{String, Any}}(),
        Dict{ExpressionKey, Dict{String, Any}}(),
    )
end
