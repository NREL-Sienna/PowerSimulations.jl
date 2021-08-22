
const _SUPPORTED_FORMATS = ("csv",)

mutable struct SimulationResultsExport
    problems::Dict{String, ProblemResultsExport}
    start_time::Dates.DateTime
    end_time::Dates.DateTime
    path::Union{Nothing, String}
    format::String
end

function SimulationResultsExport(
    problems::Vector{ProblemResultsExport},
    params::SimulationStoreParams;
    start_time = nothing,
    end_time = nothing,
    path = nothing,
    format = "csv",
)
    # This end time is outside the bounds of the simulation.
    sim_end_time = params.initial_time + params.step_resolution * params.num_steps

    if start_time === nothing
        start_time = params.initial_time
    elseif start_time < params.initial_time || start_time >= sim_end_time
        throw(IS.InvalidValue("invalid start_time: $start_time"))
    end

    if end_time === nothing
        # Reduce the end_time to be within the simulation.
        end_time = sim_end_time - Dates.Second(1)
    elseif end_time < params.initial_time || end_time >= sim_end_time
        throw(IS.InvalidValue("invalid end_time: $end_time"))
    end

    if !(format in list_supported_formats(SimulationResultsExport))
        throw(IS.InvalidValue("format = $format is not supported"))
    end

    return SimulationResultsExport(
        Dict(x.name => x for x in problems),
        start_time,
        end_time,
        path,
        format,
    )
end

function SimulationResultsExport(filename::AbstractString, params::SimulationStoreParams)
    if splitext(filename)[2] != ".json"
        throw(IS.InvalidValue("only JSON files are supported: $filename"))
    end

    return SimulationResultsExport(read_json(filename), params)
end

function SimulationResultsExport(data::AbstractDict, params::SimulationStoreParams)
    problems = Vector{ProblemResultsExport}()
    for problem in get(data, "problems", [])
        if !haskey(model, "name")
            throw(IS.InvalidValue("problem data does not define 'name'"))
        end

        problem_export = ProblemResultsExport(
            problem["name"],
            Set(Symbol(x) for x in get(model, "duals", Set{String}())),
            Set(Symbol(x) for x in get(model, "parameters", Set{String}())),
            Set(Symbol(x) for x in get(model, "variables", Set{String}())),
            get(model, "optimizer_stats", false),
        )
        push!(problems, problem_export)
    end

    start_time = get(data, "start_time", nothing)
    if start_time isa AbstractString
        start_time = Dates.DateTime(start_time)
    end

    end_time = get(data, "end_time", nothing)
    if end_time isa AbstractString
        end_time = Dates.DateTime(end_time)
    end

    return SimulationResultsExport(
        problems,
        params;
        start_time = start_time,
        end_time = end_time,
        path = get(data, "path", nothing),
        format = get(data, "format", "csv"),
    )
end

function get_problem_exports(x::SimulationResultsExport, problem_name)
    if !haskey(x.problems, problem_name)
        throw(IS.InvalidValue("problem $problem_name is not stored"))
    end

    return x.problems[problem_name]
end

function get_export_file_type(exports::SimulationResultsExport)
    if exports.format == "csv"
        return CSV.File
    end

    throw(IS.InvalidValue("format not supported: $(exports.format)"))
end

list_supported_formats(::Type{SimulationResultsExport}) = ("csv",)

function should_export(exports::SimulationResultsExport, tstamp::Dates.DateTime)
    return tstamp >= exports.start_time && tstamp <= exports.end_time
end

function should_export_dual(exports::SimulationResultsExport, tstamp, model, name)
    return _should_export(exports, tstamp, model, :duals, name)
end

function should_export_parameter(exports::SimulationResultsExport, tstamp, model, name)
    return _should_export(exports, tstamp, model, :parameters, name)
end

function should_export_variable(exports::SimulationResultsExport, tstamp, model, name)
    return _should_export(exports, tstamp, model, :variables, name)
end

function _should_export(exports::SimulationResultsExport, tstamp, model, field_name, name)
    if tstamp < exports.start_time || tstamp >= exports.end_time
        return false
    end

    problem_exports = get_problem_exports(exports, problem)
    return _should_export(problem_exports, field_name, name)
end
