
IS.@scoped_enum(ControlCommandOp, COLLECT_OUTPUTS = 1, DISABLE_OUTPUT_COLLECTION = 2, ENABLE_OUTPUT_COLLECTION = 3)

struct ControlCommand
    op::ControlCommandOp
    args::Dict
end

@Base.kwdef mutable struct SimulationProgressEvent
    model_name::String
    step::Int
    index::Int
    timestamp::Dates.DateTime
    wall_time::Dates.DateTime
    exec_time_s::Float64
end

struct SimulationIntermediateResult
    progress_event::SimulationProgressEvent
    results::Vector{Dict{String, DataFrames.DataFrame}}

    function SimulationIntermediateResult(
        progress,
        results = Vector{Dict{String, DataFrames.DataFrame}}(),
    )
        new(progress, results)
    end
end

mutable struct SimulationResultTransfer
    models::Dict{Symbol, ProblemResultsExport}
    is_enabled::Bool
end
