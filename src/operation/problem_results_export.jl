struct ProblemResultsExport
    name::Symbol
    duals::Set{IS.ConstraintKey}
    expressions::Set{IS.ExpressionKey}
    parameters::Set{IS.ParameterKey}
    variables::Set{IS.VariableKey}
    aux_variables::Set{IS.AuxVarKey}
    optimizer_stats::Bool
    store_all_flags::Dict{Symbol, Bool}

    function ProblemResultsExport(
        name,
        duals,
        expressions,
        parameters,
        variables,
        aux_variables,
        optimizer_stats,
        store_all_flags,
    )
        duals = _check_fields(duals)
        expressions = _check_fields(expressions)
        parameters = _check_fields(parameters)
        variables = _check_fields(variables)
        aux_variables = _check_fields(aux_variables)
        new(
            name,
            duals,
            expressions,
            parameters,
            variables,
            aux_variables,
            optimizer_stats,
            store_all_flags,
        )
    end
end

function ProblemResultsExport(
    name;
    duals = Set{IS.ConstraintKey}(),
    expressions = Set{IS.ExpressionKey}(),
    parameters = Set{IS.ParameterKey}(),
    variables = Set{IS.VariableKey}(),
    aux_variables = Set{IS.AuxVarKey}(),
    optimizer_stats = true,
    store_all_duals = false,
    store_all_expressions = false,
    store_all_parameters = false,
    store_all_variables = false,
    store_all_aux_variables = false,
)
    store_all_flags = Dict(
        :duals => store_all_duals,
        :expressions => store_all_expressions,
        :parameters => store_all_parameters,
        :variables => store_all_variables,
        :aux_variables => store_all_aux_variables,
    )
    return ProblemResultsExport(
        Symbol(name),
        duals,
        expressions,
        parameters,
        variables,
        aux_variables,
        optimizer_stats,
        store_all_flags,
    )
end

function _check_fields(fields)
    if !(typeof(fields) <: Set)
        fields = Set(fields)
    end

    return fields
end

should_export_dual(x::ProblemResultsExport, key) = _should_export(x, :duals, key)
should_export_expression(x::ProblemResultsExport, key) =
    _should_export(x, :expressions, key)
should_export_parameter(x::ProblemResultsExport, key) = _should_export(x, :parameters, key)
should_export_variable(x::ProblemResultsExport, key) = _should_export(x, :variables, key)
should_export_aux_variable(x::ProblemResultsExport, key) =
    _should_export(x, :aux_variables, key)

function _should_export(exports::ProblemResultsExport, field_name, key)
    exports.store_all_flags[field_name] && return true
    container = getproperty(exports, field_name)
    return key in container
end
