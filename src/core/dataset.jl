abstract type AbstractDataset end

mutable struct DataFrameDataset <: AbstractDataset
    values::DataFrames.DataFrame
    timestamps::Vector{Dates.DateTime}
    # Resolution is needed because AbstractDataset might have just one entry
    resolution::Dates.Period
    end_of_step_index::Int
    last_recorded_row::Int
    update_timestamp::Dates.DateTime
end

function DataFrameDataset(
    values::DataFrames.DataFrame,
    timestamps::Vector{Dates.DateTime},
    resolution::Dates.Period,
    end_of_step_index::Int,
)
    return DataFrameDataset(
        values,
        timestamps,
        resolution,
        end_of_step_index,
        0,
        UNSET_INI_TIME,
    )
end

function DataFrameDataset(values::DataFrames.DataFrame)
    return DataFrameDataset(
        values,
        Vector{Dates.DateTime}(),
        Dates.Second(0.0),
        1,
        0,
        UNSET_INI_TIME,
    )
end

function make_system_state(
    values::DataFrames.DataFrame,
    timestamp::Dates.DateTime,
    resolution::Dates.Period,
)
    return DataFrameDataset(values, [timestamp], resolution, 0, 1, UNSET_INI_TIME)
end

function get_dataset_value(s::DataFrameDataset, date::Dates.DateTime)
    s_index = find_timestamp_index(get_timestamps(s), date)
    if isnothing(s_index)
        error("Request time stamp $date not in the state")
    end
    return get_values(s)[s_index, :]
end

function get_column_names(::OptimizationContainerKey, s::DataFrameDataset)
    return DataFrames.names(get_values(s))
end

function get_last_recorded_value(s::DataFrameDataset)
    if get_last_recorded_row(s) == 0
        error("The Dataset hasn't been written yet")
    end
    return s.values[get_last_recorded_row(s), :]
end

get_data_resolution(s::DataFrameDataset) = s.resolution

function get_end_of_step_timestamp(s::AbstractDataset)
    return get_timestamps(s)[s.end_of_step_index]
end

get_timestamps(s::DataFrameDataset) = s.timestamps

function get_value_timestamp(s::DataFrameDataset, date::Dates.DateTime)
    s_index = find_timestamp_index(get_timestamps(s), date)
    if isnothing(s_index)
        error("Request time stamp $date not in the state")
    end
    return get_timestamps(s)[s_index]
end

function set_next_rows!(
    s::DataFrameDataset,
    vals::Union{AbstractVector, DataFrames.DataFrameRow},
)
    last_recorded_row = get_last_recorded_row(s)
    setindex!(s.values, vals, last_recorded_row + 1, :)
    set_last_recorded_row!(s, last_recorded_row + 1)
    return
end

function set_next_rows!(
    s::DataFrameDataset,
    vals::Union{AbstractMatrix, DataFrames.AbstractDataFrame},
)
    row_count = size(vals)[1]
    last_recorded_row = get_last_recorded_row(s)
    range = (last_recorded_row + 1):(last_recorded_row + row_count)
    setindex!(s.values, vals, range, :)
    set_last_recorded_row!(df, range[end])
    return
end

mutable struct HDF5Dataset <: AbstractDataset
    values::HDF5.Dataset
    column_dataset::HDF5.Dataset
    write_index::Int
    last_recorded_row::Int
    update_timestamp::Dates.DateTime
end

function get_column_names(::OptimizationContainerKey, s::HDF5Dataset)
    return s.column_dataset[:]
end

Base.length(s::AbstractDataset) = size(s.values)[1]
get_values(s::AbstractDataset) = s.values
get_last_recorded_row(s::AbstractDataset) = s.last_recorded_row

HDF5Dataset(values, column_dataset) =
    HDF5Dataset(values, column_dataset, 1, 0, UNSET_INI_TIME)

"""
Return the timestamp from most recent data row updated in the dataset. This value may not be the same as the result from `get_update_timestamp`
"""
function get_last_updated_timestamp(s::AbstractDataset)
    last_recorded_row = get_last_recorded_row(s)
    if last_recorded_row == 0
        return UNSET_INI_TIME
    end
    return get_timestamps(s)[last_recorded_row]
end

"""
Return the timestamp from the data used in the last update
"""
get_update_timestamp(s::AbstractDataset) = s.update_timestamp

function set_last_recorded_row!(s::AbstractDataset, val::Int)
    s.last_recorded_row = val
    return
end

function set_update_timestamp!(s::AbstractDataset, val::Dates.DateTime)
    s.update_timestamp = val
    return
end
