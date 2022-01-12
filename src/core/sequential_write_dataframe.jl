struct SequentialWriteDataFrame <: DataFrames.AbstractDataFrame
    data::DataFrames.DataFrame
    last_recorded_row::Base.RefValue{Int}
    SequentialWriteDataFrame(args...; kw...) =
        new(DataFrames.DataFrame(args...; kw...), Ref(0))
    SequentialWriteDataFrame(df::DataFrames.DataFrame) = new(df, Ref(0))
end

get_last_recorded_row(df::SequentialWriteDataFrame) = df.last_recorded_row[]

function set_last_recorded_row!(df::SequentialWriteDataFrame, val::Int)
    df.last_recorded_row[] = val
    return
end

function get_last_recorded_value(df::SequentialWriteDataFrame)
    if get_last_recorded_row(s) == 0
        error("The DataFrame hasn't been written yet")
    end
    return df.data[get_last_recorded_row(df), :]
end

function set_value!(df::SequentialWriteDataFrame, val)
    df.data = val
end

#! format: off
Base.append!(df1::SequentialWriteDataFrame, df2::DataFrames.DataFrame; kwargs...) = append!(getfield(df1, :data), df2; kwargs...)
Base.append!(df1::DataFrames.DataFrame, df2::SequentialWriteDataFrame; kwargs...) = append!(df1, getfield(df2, :data); kwargs...)
Base.copy(df::SequentialWriteDataFrame; kwargs...) = copy(getfield(df, :data); kwargs...)
Base.delete!(df::SequentialWriteDataFrame, p1; kwargs...) = delete!(getfield(df, :data), p1; kwargs...)
Base.deleteat!(df::SequentialWriteDataFrame, p1; kwargs...) = deleteat!(getfield(df, :data), p1; kwargs...)
Base.empty!(df::SequentialWriteDataFrame; kwargs...) = empty!(getfield(df, :data); kwargs...)
Base.getindex(df::SequentialWriteDataFrame, p1, p2; kwargs...) = getindex(getfield(df, :data), p1, p2; kwargs...)
Base.parent(df::SequentialWriteDataFrame) = parent(getfield(df, :data))
Base.push!(df::SequentialWriteDataFrame, p1::Any; kwargs...) = push!(getfield(df, :data), p1; kwargs...)
Base.setindex!(df::DataFrames.DataFrame, p1::SequentialWriteDataFrame, p2, p3; kwargs...) = setindex!(df, getfield(p1, :data), p2, p3; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p1, p2, p3; kwargs...) = setindex!(getfield(df, :data), p1, p2, p3; kwargs...)
Base.setproperty!(df::SequentialWriteDataFrame, p1, p2; kwargs...) = setproperty!(getfield(df, :data), p1, p2; kwargs...)

DataFrames.DataFrameRow(df::SequentialWriteDataFrame, p1, p2; kwargs...) = DataFrames.DataFrameRow(getfield(df, :data), p1, p2; kwargs...)
DataFrames.SubDataFrame(df::SequentialWriteDataFrame, p1, p2; kwargs...) = DataFrames.SubDataFrame(getfield(df, :data), p1, p2; kwargs...)
DataFrames.allowmissing!(df::SequentialWriteDataFrame, p1; kwargs...) = DataFrames.allowmissing!(getfield(df, :data), p1; kwargs...)
DataFrames.allowmissing!(df::SequentialWriteDataFrame; kwargs...) = DataFrames.allowmissing!(getfield(df, :data); kwargs...)
DataFrames.disallowmissing!(df::SequentialWriteDataFrame, p1; kwargs...) = DataFrames.disallowmissing!(getfield(df, :data), p1; kwargs...)
DataFrames.index(df::SequentialWriteDataFrame) = DataFrames.index(getfield(df, :data))
DataFrames.mapcols!(df::Union{Function, Type}, p1::SequentialWriteDataFrame; kwargs...) = DataFrames.mapcols!(df, getfield(p1, :data); kwargs...)
DataFrames.nrow(df::SequentialWriteDataFrame) = DataFrames.nrow(getfield(df, :data))
DataFrames.ncol(df::SequentialWriteDataFrame) = DataFrames.ncol(getfield(df, :data))
DataFrames.repeat!(df::SequentialWriteDataFrame, p1; kwargs...) = DataFrames.repeat!(getfield(df, :data), p1; kwargs...)
DataFrames.repeat!(df::SequentialWriteDataFrame; kwargs...) = DataFrames.repeat!(getfield(df, :data); kwargs...)
DataFrames.select!(df::SequentialWriteDataFrame, p1; kwargs...) = DataFrames.select!(getfield(df, :data), p1; kwargs...)
