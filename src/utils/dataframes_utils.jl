
"""
Creates a DataFrame from a JuMP DenseAxisArray or SparseAxisArray.

# Arguments

  - `array`: JuMP DenseAxisArray or SparseAxisArray to convert
  - `key::OptimizationContainerKey`:
"""
function to_dataframe(
    array::DenseAxisArray{T, 2},
    key::OptimizationContainerKey,
) where {T <: JumpSupportedLiterals}
    return DataFrames.DataFrame(to_matrix(array), get_column_names(key, array)[1])
end

function to_dataframe(
    array::DenseAxisArray{T, 1},
    key::OptimizationContainerKey,
) where {T <: JumpSupportedLiterals}
    return DataFrames.DataFrame(to_matrix(array), get_column_names(key, array)[1])
end

function to_dataframe(array::SparseAxisArray, key::OptimizationContainerKey)
    return DataFrames.DataFrame(to_matrix(array), get_column_names(key, array)[1])
end

"""
Convert a DenseAxisArray containing components to a results DataFrame consumable by users.

# Arguments
- `array: DenseAxisArray`: JuMP DenseAxisArray to convert
- `timestamps`: Iterable of timestamps for each component or nothing if time is not known.
  The resulting DataFrame will have the column "DateTime" if timestamps is not nothing.
  Otherwise, it will have the column "time_index", representing the index of the time
  dimension.
- `::Val{TableFormat}`: Format of the table to create.
  If it is TableFormat.LONG, the DataFrame will have the column "component", and, if
  the data has three dimensions, "component_x."
  If it is TableFormat.WIDE, the DataFrame will have columns for each component. Wide
  format does not support arrays with more than two dimensions.
"""
# TODO: Are "component" and "component_x" the right names?
# What if the value is for a system?
# Should they be set at runtime based on an optimization key?
function to_results_dataframe(array::DenseAxisArray, timestamps)
    return to_results_dataframe(array, timestamps, Val(TableFormat.LONG))()
end

function to_results_dataframe(
    array::DenseAxisArray{Float64, 2, <:Tuple{Vector{String}, UnitRange}},
    timestamps,
    ::Val{TableFormat.LONG},
)
    num_timestamps = size(array, 2)
    if length(timestamps) != num_timestamps
        error(
            "The number of timestamps must match the number of rows per component. " *
            "timestamps = $(length(timestamps)) " *
            "num_timestamps = $num_timestamps",
        )
    end
    num_rows = length(array.data)
    timestamps_arr = _collect_timestamps(timestamps)
    time_col = Vector{Dates.DateTime}(undef, num_rows)
    component_col = Vector{String}(undef, num_rows)
    value_col = Vector{Float64}(undef, num_rows)

    row_index = 1
    for component in axes(array, 1)
        for time_index in axes(array, 2)
            time_col[row_index] = timestamps_arr[time_index]
            component_col[row_index] = component
            row_index += 1
        end
    end

    return DataFrames.DataFrame(
        :DateTime => time_col,
        :component => component_col,
        :value => reshape(permutedims(array.data), num_rows),
    )
end

_collect_timestamps(timestamps::Vector{Dates.DateTime}) = timestamps
_collect_timestamps(timestamps) = collect(timestamps)

function to_results_dataframe(
    array::DenseAxisArray{Float64, 2, <:Tuple{Vector{String}, UnitRange}},
    ::Nothing,
    ::Val{TableFormat.LONG},
)
    num_rows = length(array.data)
    time_col = Vector{Int}(undef, num_rows)
    component_col = Vector{String}(undef, num_rows)
    value_col = Vector{Float64}(undef, num_rows)

    row_index = 1
    for component in axes(array, 1)
        for time_index in axes(array, 2)
            time_col[row_index] = time_index
            component_col[row_index] = component
            row_index += 1
        end
    end

    return DataFrames.DataFrame(
        :time_index => time_col,
        :component => component_col,
        :value => reshape(permutedims(array.data), num_rows),
    )
end

function to_results_dataframe(
    array::DenseAxisArray{Float64, 2, <:Tuple{Vector{String}, UnitRange}},
    timestamps,
    ::Val{TableFormat.WIDE},
)
    df = DataFrame(to_matrix(array), axes(array, 1))
    DataFrames.insertcols!(df, 1, :DateTime => timestamps)
    return df
end

function to_results_dataframe(
    array::DenseAxisArray{Float64, 2, <:Tuple{Vector{String}, UnitRange}},
    ::Nothing,
    ::Val{TableFormat.WIDE},
)
    df = DataFrame(to_matrix(array), axes(array, 1))
    DataFrames.insertcols!(df, 1, :time_index => axes(array, 2))
    return df
end

function to_results_dataframe(
    array::DenseAxisArray{Float64, 3, <:Tuple{Vector{String}, Vector{String}, UnitRange}},
    timestamps,
    ::Val{TableFormat.LONG},
)
    num_timestamps = size(array, 3)
    if length(timestamps) != num_timestamps
        error(
            "The number of timestamps must match the number of rows per component. " *
            "timestamps = $(length(timestamps)) " *
            "num_timestamps = $num_timestamps",
        )
    end
    num_rows = length(array.data)
    timestamps_arr = _collect_timestamps(timestamps)
    time_col = Vector{Dates.DateTime}(undef, num_rows)
    component_col = Vector{String}(undef, num_rows)
    component_x_col = Vector{String}(undef, num_rows)
    vals = Vector{Float64}(undef, num_rows)

    row_index = 1
    for component in axes(array, 1)
        for component_x in axes(array, 2)
            for time_index in axes(array, 3)
                time_col[row_index] = timestamps_arr[time_index]
                component_col[row_index] = component
                component_x_col[row_index] = component_x
                vals[row_index] = array[component, component_x, time_index]
                row_index += 1
            end
        end
    end

    return DataFrames.DataFrame(
        :DateTime => time_col,
        :component => component_col,
        :component_x => component_x_col,
        :value => vals,
    )
end

function to_results_dataframe(
    array::DenseAxisArray{Float64, 3, <:Tuple{Vector{String}, Vector{String}, UnitRange}},
    ::Nothing,
    ::Val{TableFormat.LONG},
)
    num_rows = length(array.data)
    time_col = Vector{Int}(undef, num_rows)
    component_col = Vector{String}(undef, num_rows)
    component_x_col = Vector{String}(undef, num_rows)
    vals = Vector{Float64}(undef, num_rows)

    row_index = 1
    for component in axes(array, 1)
        for component_x in axes(array, 2)
            for time_index in axes(array, 3)
                time_col[row_index] = time_index
                component_col[row_index] = component
                component_x_col[row_index] = component_x
                vals[row_index] = array[component, component_x, time_index]
                row_index += 1
            end
        end
    end

    return DataFrames.DataFrame(
        :time_index => time_col,
        :component => component_col,
        :component_x => component_x_col,
        :value => vals,
    )
end

function to_matrix(df::DataFrames.DataFrame)
    return Matrix{Float64}(df)
end

function to_matrix(df_row::DataFrames.DataFrameRow{DataFrames.DataFrame, DataFrames.Index})
    return reshape(Vector(df_row), 1, size(df_row)[1])
end
