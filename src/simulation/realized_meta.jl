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
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    existing_timestamps = get_timestamps(res)
    interval = existing_timestamps.step
    resolution = get_resolution(res)
    interval_len = Int(interval / resolution)
    realized_timestamps = get_realized_timestamps(res; start_time = start_time, len = len)

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

function _make_dataframe(
    columns::Tuple{Vector{String}},
    results_by_time::ResultsByTime{Matrix{Float64}, 1},
    num_rows::Int,
    meta::RealizedMeta,
    key::IS.OptimizationContainerKey,
)
    num_cols = length(columns[1])
    matrix = Matrix{Float64}(undef, num_rows, num_cols)
    row_index = 1
    for (step, (_, array)) in enumerate(results_by_time)
        first_id = step > 1 ? 1 : meta.start_offset
        last_id =
            step == meta.len ? meta.interval_len - meta.end_offset : meta.interval_len
        if last_id - first_id > size(array, 1)
            error(
                "Variable $(encode_key_as_string(key)) has $(size(array, 1)) number of steps, that is different than the default problem horizon. \
            Can't calculate the realized variables. Use `read_variables` instead and write your own concatenation",
            )
        end
        row_end = row_index + last_id - first_id
        matrix[row_index:row_end, :] = array[first_id:last_id, :]
        row_index += last_id - first_id + 1
    end
    df = DataFrames.DataFrame(matrix, collect(columns[1]); copycols = false)
    DataFrames.insertcols!(
        df,
        1,
        :DateTime => meta.realized_timestamps,
    )
    return df
end

function get_realization(
    results::Dict{IS.OptimizationContainerKey, ResultsByTime{Matrix{Float64}}},
    meta::RealizedMeta,
)
    realized_values = Dict{IS.OptimizationContainerKey, DataFrames.DataFrame}()
    lk = ReentrantLock()
    num_rows = length(meta.realized_timestamps)
    start = time()
    Threads.@threads for key in collect(keys(results))
        results_by_time = results[key]
        columns = get_column_names(results_by_time)
        df = _make_dataframe(columns, results_by_time, num_rows, meta, key)
        lock(lk) do
            realized_values[key] = df
        end
    end

    duration = time() - start
    if Threads.nthreads() == 1 && duration > 10.0
        @info "Time to read results: $duration seconds. You will likely get faster " *
              "results by starting Julia with multiple threads."
    end

    return realized_values
end
