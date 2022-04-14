struct RealizedMeta
    start_time::Dates.DateTime
    resolution::Dates.TimePeriod
    len::Int
    start_offset::Int
    end_offset::Int
    interval_len::Int
    realized_timestamps::AbstractVector{Dates.DateTime}
end

function RealizedMeta(
    res::SimulationProblemResults;
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Int, Nothing}=nothing,
)
    existing_timestamps = get_timestamps(res)
    interval = existing_timestamps.step
    resolution = get_resolution(res)
    interval_len = Int(interval / resolution)
    realized_timestamps = get_realized_timestamps(res, start_time=start_time, len=len)

    result_start_time = existing_timestamps[findlast(
        x -> x .<= first(realized_timestamps),
        existing_timestamps,
    )]
    result_end_time = existing_timestamps[findlast(
        x -> x .<= last(realized_timestamps),
        existing_timestamps,
    )]

    len = length(result_start_time:interval:result_end_time)

    start_offset = length(result_start_time:resolution:first(realized_timestamps))
    end_offset = length(
        (last(realized_timestamps) + resolution):resolution:(result_end_time + interval - resolution),
    )

    return RealizedMeta(
        result_start_time,
        resolution,
        len,
        start_offset,
        end_offset,
        interval_len,
        realized_timestamps,
    )
end

function get_realization(
    result_values::Dict{
        OptimizationContainerKey,
        SortedDict{Dates.DateTime, DataFrames.DataFrame},
    },
    meta::RealizedMeta,
)
    realized_values = Dict{OptimizationContainerKey, DataFrames.DataFrame}()
    for (key, result_value) in result_values
        results_concat = Dict{Symbol, Vector{Float64}}()
        for (step, (t, df)) in enumerate(result_value)
            first_id = step > 1 ? 1 : meta.start_offset
            last_id =
                step == meta.len ? meta.interval_len - meta.end_offset : meta.interval_len
            for colname in propertynames(df)
                colname == :DateTime && continue
                col = df[!, colname][first_id:last_id]
                if !haskey(results_concat, colname)
                    results_concat[colname] = col
                else
                    results_concat[colname] = vcat(results_concat[colname], col)
                end
            end
        end
        realized_values[key] = DataFrames.DataFrame(results_concat, copycols=false)
        DataFrames.insertcols!(
            realized_values[key],
            1,
            :DateTime => meta.realized_timestamps,
        )
    end
    return realized_values
end
