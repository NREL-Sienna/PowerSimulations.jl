
struct SequentialWriteDataFrame <: DataFrames.AbstractDataFrame
    data::DataFrames.DataFrame
    last_recorded_row::Base.RefValue{Int}
    update_timestamp::Base.RefValue{Dates.DateTime}
    SequentialWriteDataFrame(args...; kw...) =
        new(DataFrames.DataFrame(args...; kw...), Ref(0))
    SequentialWriteDataFrame(df::DataFrames.DataFrame) =
        new(df, Ref(0), Ref(UNSET_INI_TIME))
end

# Don't use .last_recorded_row syntax since it will conflict with the internal df.
# last_recorded_row can only be accessed via get/set functions
get_last_recorded_row(df::SequentialWriteDataFrame) = getfield(df, :last_recorded_row)[]

function set_last_recorded_row!(df::SequentialWriteDataFrame, val::Int)
    getfield(df, :last_recorded_row)[] = val
    return
end

get_update_timestamp(df::SequentialWriteDataFrame) = getfield(df, :update_timestamp)[]

function set_update_timestamp!(df::SequentialWriteDataFrame, val::Dates.DateTime)
    getfield(df, :last_recorded_row)[] = val
    return
end

function get_last_recorded_value(df::SequentialWriteDataFrame)
    if get_last_recorded_row(df) == 0
        error("The DataFrame hasn't been written yet")
    end
    return getfield(df, :data)[get_last_recorded_row(df), :]
end

function set_next_rows!(
    df::SequentialWriteDataFrame,
    vals::Union{AbstractVector, DataFrames.DataFrameRow},
)
    last_recorded_row = get_last_recorded_row(df)
    setindex!(getfield(df, :data), vals, last_recorded_row + 1, :)
    set_last_recorded_row!(df, last_recorded_row + 1)
    return
end

function set_next_rows!(
    df::SequentialWriteDataFrame,
    vals::Union{AbstractMatrix, DataFrames.AbstractDataFrame},
)
    row_count = size(vals)[1]
    last_recorded_row = get_last_recorded_row(df)
    range = (last_recorded_row + 1):(last_recorded_row + row_count)
    setindex!(getfield(df, :data), vals, range, :)
    set_last_recorded_row!(df, range[end])
    return
end

#! format: off

const DataAPI = DataFrames.DataAPI
const InvertedIndices = DataFrames.InvertedIndices

DataFrames.DataFrameRow(df::SequentialWriteDataFrame, p2::AbstractVector, p3::Any; kwargs...) = DataFrames.DataFrameRow(getfield(p1, :data), p2, p3; kwargs...)
DataFrames.DataFrameRow(df::SequentialWriteDataFrame, p2::AbstractVector{<:Integer}, p3::Any; kwargs...) = DataFrames.DataFrameRow(getfield(df, :data), p2, p3; kwargs...)
DataFrames.DataFrameRow(df::SequentialWriteDataFrame, p2::AbstractVector{Bool}, p3::Any; kwargs...) = DataFrames.DataFrameRow(getfield(df, :data), p2, p3; kwargs...)
DataFrames.DataFrameRow(df::SequentialWriteDataFrame, p2::AbstractVector{Int64}, p3::Any; kwargs...) = DataFrames.DataFrameRow(getfield(df, :data), p2, p3; kwargs...)
DataFrames.DataFrameRow(df::SequentialWriteDataFrame, p2::Colon, p3::Any; kwargs...) = DataFrames.DataFrameRow(getfield(df, :data), p2, p3; kwargs...)
DataFrames.DataFrameRow(df::SequentialWriteDataFrame, p2::Integer, p3::Any; kwargs...) = DataFrames.DataFrameRow(getfield(df, :data), p2, p3; kwargs...)

DataFrames.SubDataFrame(df::SequentialWriteDataFrame, p2::AbstractVector, p3::Any; kwargs...) = DataFrames.SubDataFrame(getfield(p1, :data), p2, p3; kwargs...)
DataFrames.SubDataFrame(df::SequentialWriteDataFrame, p2::AbstractVector{<:Integer}, p3::Any; kwargs...) = DataFrames.SubDataFrame(getfield(df, :data), p2, p3; kwargs...)
DataFrames.SubDataFrame(df::SequentialWriteDataFrame, p2::AbstractVector{Bool}, p3::Any; kwargs...) = DataFrames.SubDataFrame(getfield(df, :data), p2, p3; kwargs...)
DataFrames.SubDataFrame(df::SequentialWriteDataFrame, p2::AbstractVector{Int64}, p3::Any; kwargs...) = DataFrames.SubDataFrame(getfield(df, :data), p2, p3; kwargs...)
DataFrames.SubDataFrame(df::SequentialWriteDataFrame, p2::Colon, p3::Any; kwargs...) = DataFrames.SubDataFrame(getfield(df, :data), p2, p3; kwargs...)
DataFrames.SubDataFrame(df::SequentialWriteDataFrame, p2::Integer, p3::Any; kwargs...) = DataFrames.SubDataFrame(getfield(df, :data), p2, p3; kwargs...)

DataFrames.allowmissing!(df::SequentialWriteDataFrame, p1; kwargs...) = DataFrames.allowmissing!(getfield(df, :data), p1; kwargs...)
DataFrames.allowmissing!(df::SequentialWriteDataFrame; kwargs...) = DataFrames.allowmissing!(getfield(df, :data); kwargs...)
DataFrames.disallowmissing!(df::SequentialWriteDataFrame, p1; kwargs...) = DataFrames.disallowmissing!(getfield(df, :data), p1; kwargs...)
DataFrames.index(df::SequentialWriteDataFrame) = DataFrames.index(getfield(df, :data))
DataFrames.mapcols!(p1::Union{Function, Type}, df::SequentialWriteDataFrame; kwargs...) = DataFrames.mapcols!(df, getfield(df, :data); kwargs...)
DataFrames.nrow(df::SequentialWriteDataFrame) = DataFrames.nrow(getfield(df, :data))
DataFrames.ncol(df::SequentialWriteDataFrame) = DataFrames.ncol(getfield(df, :data))
DataFrames.repeat!(df::SequentialWriteDataFrame, p1; kwargs...) = DataFrames.repeat!(getfield(df, :data), p1; kwargs...)
DataFrames.repeat!(df::SequentialWriteDataFrame; kwargs...) = DataFrames.repeat!(getfield(df, :data); kwargs...)
DataFrames.select!(df::SequentialWriteDataFrame, p1; kwargs...) = DataFrames.select!(getfield(df, :data), p1; kwargs...)

Base.append!(df1::SequentialWriteDataFrame, df2::DataFrames.DataFrame; kwargs...) = append!(getfield(df1, :data), df2; kwargs...)
Base.append!(df1::DataFrames.DataFrame, df2::SequentialWriteDataFrame; kwargs...) = append!(df1, getfield(df2, :data); kwargs...)
Base.copy(df::SequentialWriteDataFrame; kwargs...) = copy(getfield(df, :data); kwargs...)
Base.delete!(df::SequentialWriteDataFrame, p1; kwargs...) = delete!(getfield(df, :data), p1; kwargs...)
Base.deleteat!(df::SequentialWriteDataFrame, p1; kwargs...) = deleteat!(getfield(df, :data), p1; kwargs...)
Base.empty!(df::SequentialWriteDataFrame; kwargs...) = empty!(getfield(df, :data); kwargs...)

# Specific getindex methods are needed to avoid ambiguity with AbstractDataFrame
Base.getindex(df::SequentialWriteDataFrame, p2::AbstractVector, p3::Union{AbstractString, Signed, Symbol, Unsigned}; kwargs...) = getindex(getfield(df, :data), p2, p3; kwargs...)
Base.getindex(df::SequentialWriteDataFrame, p2::AbstractVector, p3::Union{Colon, Regex, AbstractVector, DataAPI.All, DataAPI.Between, DataAPI.Cols, InvertedIndices.InvertedIndex}; kwargs...) = getindex(getfield(df, :data), p2, p3; kwargs...)
Base.getindex(df::SequentialWriteDataFrame, p2::Colon, p3::Union{AbstractString, Signed, Symbol, Unsigned}; kwargs...) = getindex(getfield(df, :data), p2, p3; kwargs...)
Base.getindex(df::SequentialWriteDataFrame, p2::Colon, p3::Union{Colon, Regex, AbstractVector, DataAPI.All, DataAPI.Between, DataAPI.Cols, InvertedIndices.InvertedIndex}; kwargs...) = getindex(getfield(df, :data), p2, p3; kwargs...)
Base.getindex(df::SequentialWriteDataFrame, p2::Integer, p3::Union{AbstractString, Symbol}; kwargs...) = getindex(getfield(df, :data), p2, p3; kwargs...)
Base.getindex(df::SequentialWriteDataFrame, p2::Integer, p3::Union{Signed, Unsigned}; kwargs...) = getindex(getfield(df, :data), p2, p3; kwargs...)
Base.getindex(df::SequentialWriteDataFrame, p2::InvertedIndices.InvertedIndex, p3::Union{AbstractString, Signed, Symbol, Unsigned}; kwargs...) = getindex(getfield(df, :data), p2, p3; kwargs...)
Base.getindex(df::SequentialWriteDataFrame, p2::InvertedIndices.InvertedIndex, p3::Union{Colon, Regex, AbstractVector, DataAPI.All, DataAPI.Between, DataAPI.Cols, InvertedIndices.InvertedIndex}; kwargs...) = getindex(getfield(df, :data), p2, p3; kwargs...)
Base.getindex(df::SequentialWriteDataFrame, p2::typeof(!), p3::Union{AbstractString, Symbol}; kwargs...) = getindex(getfield(df, :data), p2, p3; kwargs...)
Base.getindex(df::SequentialWriteDataFrame, p2::typeof(!), p3::Union{Colon, Regex, AbstractVector, DataAPI.All, DataAPI.Between, DataAPI.Cols, InvertedIndices.InvertedIndex}; kwargs...) = getindex(getfield(df, :data), p2, p3; kwargs...)
Base.getindex(df::SequentialWriteDataFrame, p2::typeof(!), p3::Union{Signed, Unsigned}; kwargs...) = getindex(getfield(df, :data), p2, p3; kwargs...)

Base.parent(df::SequentialWriteDataFrame) = parent(getfield(df, :data))
Base.push!(df::SequentialWriteDataFrame, p1::Any; kwargs...) = push!(getfield(df, :data), p1; kwargs...)
Base.setproperty!(df::SequentialWriteDataFrame, p1::Symbol, p2; kwargs...) = setproperty!(getfield(df, :data), p1, p2; kwargs...)

Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::AbstractVector, p4::AbstractVector; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::AbstractVector, p4::Colon; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::AbstractVector, p4::DataAPI.All; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::AbstractVector, p4::DataAPI.Between; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::AbstractVector, p4::DataAPI.Cols; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::AbstractVector, p4::InvertedIndices.InvertedIndex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::AbstractVector, p4::Regex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::Colon, p4::AbstractVector; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::Colon, p4::Colon; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::Colon, p4::DataAPI.All; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::Colon, p4::DataAPI.Between; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::Colon, p4::DataAPI.Cols; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::Colon, p4::InvertedIndices.InvertedIndex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::Colon, p4::Regex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::InvertedIndices.InvertedIndex, p4::AbstractVector; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::InvertedIndices.InvertedIndex, p4::Colon; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::InvertedIndices.InvertedIndex, p4::DataAPI.All; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::InvertedIndices.InvertedIndex, p4::DataAPI.Between; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::InvertedIndices.InvertedIndex, p4::DataAPI.Cols; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::InvertedIndices.InvertedIndex, p4::InvertedIndices.InvertedIndex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::InvertedIndices.InvertedIndex, p4::Regex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::typeof(!), p4::AbstractVector; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::typeof(!), p4::Colon; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::typeof(!), p4::DataAPI.All; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::typeof(!), p4::DataAPI.Between; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::typeof(!), p4::DataAPI.Cols; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::typeof(!), p4::InvertedIndices.InvertedIndex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractMatrix, p3::typeof(!), p4::Regex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractVector, p3::AbstractVector, p4::Union{AbstractString, Signed, Symbol, Unsigned}; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractVector, p3::Colon, p4::Union{AbstractString, Signed, Symbol, Unsigned}; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractVector, p3::InvertedIndices.InvertedIndex, p4::Union{AbstractString, Signed, Symbol, Unsigned}; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::AbstractVector, p3::typeof(!), p4::Union{AbstractString, Signed, Symbol, Unsigned}; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::Any, p3::Integer, p4::Union{AbstractString, Signed, Symbol, Unsigned}; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::AbstractVector, p4::AbstractVector; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::AbstractVector, p4::Colon; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::AbstractVector, p4::DataAPI.All; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::AbstractVector, p4::DataAPI.Between; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::AbstractVector, p4::DataAPI.Cols; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::AbstractVector, p4::InvertedIndices.InvertedIndex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::AbstractVector, p4::Regex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::Colon, p4::AbstractVector; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::Colon, p4::Colon; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::Colon, p4::DataAPI.All; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::Colon, p4::DataAPI.Between; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::Colon, p4::DataAPI.Cols; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::Colon, p4::InvertedIndices.InvertedIndex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::Colon, p4::Regex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::InvertedIndices.InvertedIndex, p4::AbstractVector; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::InvertedIndices.InvertedIndex, p4::Colon; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::InvertedIndices.InvertedIndex, p4::DataAPI.All; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::InvertedIndices.InvertedIndex, p4::DataAPI.Between; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::InvertedIndices.InvertedIndex, p4::DataAPI.Cols; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::InvertedIndices.InvertedIndex, p4::InvertedIndices.InvertedIndex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::InvertedIndices.InvertedIndex, p4::Regex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::typeof(!), p4::AbstractVector; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::typeof(!), p4::Colon; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::typeof(!), p4::DataAPI.All; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::typeof(!), p4::DataAPI.Between; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::typeof(!), p4::DataAPI.Cols; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::typeof(!), p4::InvertedIndices.InvertedIndex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::DataFrames.AbstractDataFrame, p3::typeof(!), p4::Regex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::Union{AbstractDict, NamedTuple, DataFrames.DataFrameRow}, p3::Integer, p4::AbstractVector; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::Union{AbstractDict, NamedTuple, DataFrames.DataFrameRow}, p3::Integer, p4::Colon; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::Union{AbstractDict, NamedTuple, DataFrames.DataFrameRow}, p3::Integer, p4::DataAPI.All; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::Union{AbstractDict, NamedTuple, DataFrames.DataFrameRow}, p3::Integer, p4::DataAPI.Between; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::Union{AbstractDict, NamedTuple, DataFrames.DataFrameRow}, p3::Integer, p4::DataAPI.Cols; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::Union{AbstractDict, NamedTuple, DataFrames.DataFrameRow}, p3::Integer, p4::InvertedIndices.InvertedIndex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::Union{AbstractDict, NamedTuple, DataFrames.DataFrameRow}, p3::Integer, p4::Regex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::Union{Tuple, AbstractArray}, p3::Integer, p4::AbstractVector; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::Union{Tuple, AbstractArray}, p3::Integer, p4::Colon; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::Union{Tuple, AbstractArray}, p3::Integer, p4::DataAPI.All; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::Union{Tuple, AbstractArray}, p3::Integer, p4::DataAPI.Between; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::Union{Tuple, AbstractArray}, p3::Integer, p4::DataAPI.Cols; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::Union{Tuple, AbstractArray}, p3::Integer, p4::InvertedIndices.InvertedIndex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
Base.setindex!(df::SequentialWriteDataFrame, p2::Union{Tuple, AbstractArray}, p3::Integer, p4::Regex; kwargs...) = setindex!(getfield(df, :data), p2, p3, p4; kwargs...)
