
"""
Creates a DataFrame from a JuMP DenseAxisArray or SparseAxisArray.

# Arguments

  - `array`: JuMP DenseAxisArray or SparseAxisArray to convert
  - `key::OptimizationContainerKey`:
"""
function to_dataframe(
    array::DenseAxisArray{T, 2},
    key::OptimizationContainerKey,
) where {T <: Number}
    return DataFrames.DataFrame(to_matrix(array), get_column_names(key, array)[1])
end

function to_dataframe(
    array::DenseAxisArray{T, 1},
    key::OptimizationContainerKey,
) where {T <: Number}
    return DataFrames.DataFrame(to_matrix(array), get_column_names(key, array)[1])
end

function to_dataframe(array::SparseAxisArray, key::OptimizationContainerKey)
    return DataFrames.DataFrame(to_matrix(array), get_column_names(key, array)[1])
end

function to_matrix(df::DataFrames.DataFrame)
    return Matrix{Float64}(df)
end

function to_matrix(df_row::DataFrames.DataFrameRow{DataFrames.DataFrame, DataFrames.Index})
    return reshape(Vector(df_row), 1, size(df_row)[1])
end
