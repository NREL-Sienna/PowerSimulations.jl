struct ResultsByTime{T}
    key::OptimizationContainerKey
    data::SortedDict{Dates.DateTime, T}
    resolution::Dates.Period
    column_names::Vector{String}
end

function ResultsByTime(key, data, resolution, column_names)
    _check_column_consistency(data, column_names)
    ResultsByTime(key, data, resolution, column_names)
end

function _check_column_consistency(
    data::SortedDict{Dates.DateTime, DenseAxisArray{Float64, 2}},
    cols::Vector{String},
)
    for val in values(data)
        if axes(val)[1] != cols
            error("Mismatch in DenseAxisArray column names: $(axes(val)[1]) $cols")
        end
    end
end

function _check_column_consistency(
    data::SortedDict{Dates.DateTime, Matrix{Float64}},
    cols::Vector{String},
)
    for val in values(data)
        if size(val)[2] != length(cols)
            error("Mismatch in length of Matrix columns: $(size(val)[2]) $(length(cols))")
        end
    end
end

# This struct behaves like a dict, delegating to its 'data' field.
Base.length(res::ResultsByTime) = length(res.data)
Base.iterate(res::ResultsByTime) = iterate(res.data)
Base.iterate(res::ResultsByTime, state) = iterate(res.data, state)
Base.getindex(res::ResultsByTime, i) = getindex(res.data, i)
Base.setindex!(res::ResultsByTime, v, i) = setindex!(res.data, v, i)
Base.firstindex(res::ResultsByTime) = firstindex(res.data)
Base.lastindex(res::ResultsByTime) = lastindex(res.data)

get_column_names(x::ResultsByTime) = x.column_names
get_num_rows(::ResultsByTime{DenseAxisArray{Float64, 2}}, data) = length(axes(data)[2])
get_num_rows(::ResultsByTime{Matrix{Float64}}, data) = size(data)[1]

function _add_timestamps!(
    df::DataFrames.DataFrame,
    results::ResultsByTime,
    timestamp::Dates.DateTime,
    data,
)
    time_col =
        range(timestamp; length = get_num_rows(results, data), step = results.resolution)
    DataFrames.insertcols!(df, 1, :DateTime => time_col)
end

function make_dataframe(
    results::ResultsByTime{DenseAxisArray{Float64, 2}},
    timestamp::Dates.DateTime,
)
    array = results.data[timestamp]
    df = DataFrames.DataFrame(permutedims(array.data), axes(array)[1])
    _add_timestamps!(df, results, timestamp, array)
    return df
end

function make_dataframe(results::ResultsByTime{Matrix{Float64}}, timestamp::Dates.DateTime)
    array = results.data[timestamp]
    df = DataFrames.DataFrame(array, results.column_names)
    _add_timestamps!(df, results, timestamp, array)
    return df
end

function make_dataframes(results::ResultsByTime)
    return SortedDict(k => make_dataframe(results, k) for k in keys(results.data))
end

struct ResultsByKeyAndTime
    "Contains all keys stored in the model."
    result_keys::Vector{OptimizationContainerKey}
    "Contains the results that have been read from the store and cached."
    cached_results::Dict{OptimizationContainerKey, ResultsByTime}
end

ResultsByKeyAndTime(result_keys) = ResultsByKeyAndTime(
    collect(result_keys),
    Dict{OptimizationContainerKey, ResultsByTime}(),
)

Base.empty!(res::ResultsByKeyAndTime) = empty!(res.cached_results)
