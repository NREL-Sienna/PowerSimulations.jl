struct ProblemResultsExport
    name::Symbol
    duals::Set{ConstraintKey}
    parameters::Set{ParameterKey}
    variables::Set{VariableKey}
    optimizer_stats::Bool
    store_all_flags::Dict{Symbol, Bool}

    function ProblemResultsExport(
        name,
        duals,
        parameters,
        variables,
        optimizer_stats,
        store_all_flags,
    )
        duals = _check_fields(duals)
        parameters = _check_fields(parameters)
        variables = _check_fields(variables)
        new(name, duals, parameters, variables, optimizer_stats, store_all_flags)
    end
end

function ProblemResultsExport(
    name;
    duals = Set{ConstraintKey}(),
    parameters = Set{ParameterKey}(),
    variables = Set{VariableKey}(),
    optimizer_stats = true,
    store_all_duals = false,
    store_all_parameters = false,
    store_all_variables = false,
)
    store_all_flags = Dict(
        :duals => store_all_duals,
        :parameters => store_all_parameters,
        :variables => store_all_variables,
    )
    return ProblemResultsExport(
        Symbol(name),
        duals,
        parameters,
        variables,
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
should_export_parameter(x::ProblemResultsExport, key) = _should_export(x, :parameters, key)
should_export_variable(x::ProblemResultsExport, key) = _should_export(x, :variables, key)

function _should_export(exports::ProblemResultsExport, field_name, key)
    exports.store_all_flags[field_name] && return true
    container = getproperty(exports, field_name)
    return key in container
end
