struct ProblemResultsExport
    name::String
    duals::Set{Symbol}
    parameters::Set{Symbol}
    variables::Set{Symbol}
    optimizer_stats::Bool

    function ProblemResultsExport(name, duals, parameters, variables, optimizer_stats)
        duals = _check_fields(duals)
        parameters = _check_fields(parameters)
        variables = _check_fields(variables)
        new(name, duals, parameters, variables, optimizer_stats)
    end
end

function ProblemResultsExport(
    name::AbstractString;
    duals = Set{Symbol}(),
    parameters = Set{Symbol}(),
    variables = Set{Symbol}(),
    optimizer_stats = true,
)
    return ProblemResultsExport(name, duals, parameters, variables, optimizer_stats)
end

function _check_fields(fields)
    if !(typeof(fields) <: Set{Symbol})
        fields = Set(Symbol.(fields))
    end

    if :all in fields && length(fields) > 1
        throw(IS.InvalidValue("'all' can only be present if the array has one element"))
    end

    return fields
end

should_export_dual(x::ProblemResultsExport, name) = _should_export(x, :duals, name)
should_export_parameter(x::ProblemResultsExport, name) =
    _should_export(x, :parameters, name)
should_export_variable(x::ProblemResultsExport, name) = _should_export(x, :variables, name)

function _should_export(exports::ProblemResultsExport, field_name, name)
    container = getfield(exports, field_name)
    isempty(container) && return false
    first(container) == :all && return true
    return name in container
end
