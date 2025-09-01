
function to_matrix(df::DataFrame)
    return Matrix{Float64}(df)
end

function to_matrix(df_row::DataFrameRow{DataFrame, DataFrames.Index})
    return reshape(Vector(df_row), 1, size(df_row)[1])
end
