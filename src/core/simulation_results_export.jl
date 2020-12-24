
const _SUPPORTED_FORMATS = ("csv",)

struct StageResultsExport
    name::String
    duals::Set{Symbol}
    parameters::Set{Symbol}
    variables::Set{Symbol}

    function StageResultsExport(name, duals, parameters, variables)
        duals = _check_fields(duals)
        parameters = _check_fields(parameters)
        variables = _check_fields(variables)
        new(name, duals, parameters, variables)
    end
end

function StageResultsExport(
    name::AbstractString;
    duals = Set{Symbol}(),
    parameters = Set{Symbol}(),
    variables = Set{Symbol}(),
)
    return StageResultsExport(name, duals, parameters, variables)
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

should_export_dual(x::StageResultsExport, name) = _should_export(x, :duals, name)
should_export_parameter(x::StageResultsExport, name) = _should_export(x, :parameters, name)
should_export_variable(x::StageResultsExport, name) = _should_export(x, :variables, name)

function _should_export(exports::StageResultsExport, field_name, name)
    container = getfield(exports, field_name)
    isempty(container) && return false
    first(container) == :all && return true
    return name in container
end

mutable struct SimulationResultsExport
    stages::Dict{String, StageResultsExport}
    start_time::Dates.DateTime
    end_time::Dates.DateTime
    path::Union{Nothing, String}
    format::String
end

function SimulationResultsExport(
    stages::Vector{StageResultsExport},
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
        Dict(x.name => x for x in stages),
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
    stages = Vector{StageResultsExport}()
    for stage in get(data, "stages", [])
        if !haskey(stage, "name")
            throw(IS.InvalidValue("stage data does not define 'name'"))
        end

        stage_export = StageResultsExport(
            stage["name"],
            Set(Symbol(x) for x in get(stage, "duals", Set{String}())),
            Set(Symbol(x) for x in get(stage, "parameters", Set{String}())),
            Set(Symbol(x) for x in get(stage, "variables", Set{String}())),
        )
        push!(stages, stage_export)
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
        stages,
        params;
        start_time = start_time,
        end_time = end_time,
        path = get(data, "path", nothing),
        format = get(data, "format", "csv"),
    )
end

function get_stage_exports(x::SimulationResultsExport, stage_name)
    if !haskey(x.stages, stage_name)
        throw(IS.InvalidValue("stage $stage_name is not stored"))
    end

    return x.stages[stage_name]
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

function should_export_dual(exports::SimulationResultsExport, tstamp, stage, name)
    return _should_export(exports, tstamp, stage, :duals, name)
end

function should_export_parameter(exports::SimulationResultsExport, tstamp, stage, name)
    return _should_export(exports, tstamp, stage, :parameters, name)
end

function should_export_variable(exports::SimulationResultsExport, tstamp, stage, name)
    return _should_export(exports, tstamp, stage, :variables, name)
end

function _should_export(exports::SimulationResultsExport, tstamp, stage, field_name, name)
    if tstamp < exports.start_time || tstamp >= exports.end_time
        return false
    end

    stage_exports = get_stage_exports(exports, stage)
    return _should_export(stage_exports, field_name, name)
end
