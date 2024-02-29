
"""
Creates a DataFrame from a JuMP DenseAxisArray or SparseAxisArray.

# Arguments

  - `array`: JuMP DenseAxisArray or SparseAxisArray to convert
  - `key::IS.OptimizationContainerKey`:
"""
function to_dataframe(
    array::DenseAxisArray{T, 2},
    key::IS.OptimizationContainerKey,
) where {T <: Number}
    return DataFrames.DataFrame(to_matrix(array), get_column_names(key, array)[1])
end

function to_dataframe(
    array::DenseAxisArray{T, 1},
    key::IS.OptimizationContainerKey,
) where {T <: Number}
    return DataFrames.DataFrame(to_matrix(array), get_column_names(key, array)[1])
end

function to_dataframe(array::SparseAxisArray, key::IS.OptimizationContainerKey)
    return DataFrames.DataFrame(to_matrix(array), get_column_names(key, array)[1])
end

function to_matrix(df::DataFrames.DataFrame)
    return Matrix{Float64}(df)
end

function to_matrix(df_row::DataFrames.DataFrameRow{DataFrames.DataFrame, DataFrames.Index})
    return reshape(Vector(df_row), 1, size(df_row)[1])
end

function write_data(
    vars_results::Dict,
    time::DataFrames.DataFrame,
    save_path::AbstractString,
)
    for (k, v) in vars_results
        var = DataFrames.DataFrame()
        if size(time, 1) == size(v, 1)
            var = hcat(time, v)
        else
            var = v
        end
        file_path = joinpath(save_path, "$(k).csv")
        CSV.write(file_path, var)
    end
end

function write_data(
    data::DataFrames.DataFrame,
    save_path::AbstractString,
    file_name::String,
)
    if isfile(save_path)
        save_path = dirname(save_path)
    end
    file_path = joinpath(save_path, "$(file_name).csv")
    CSV.write(file_path, data)
    return
end

# writing a dictionary of dataframes to files
function write_data(vars_results::Dict, save_path::String; kwargs...)
    name = get(kwargs, :name, "")
    for (k, v) in vars_results
        keyname = encode_key_as_string(k)
        file_path = joinpath(save_path, "$name$keyname.csv")
        @debug "writing" file_path
        if isempty(vars_results[k])
            @debug "$name$k is empty, not writing $file_path"
        else
            CSV.write(file_path, vars_results[k])
        end
    end
end
