abstract type AbstractDataset end

Base.length(s::AbstractDataset) = size(s.values)[1]
get_data_resolution(s::AbstractDataset)::Dates.Millisecond = s.resolution
get_last_recorded_row(s::AbstractDataset) = s.last_recorded_row

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

# Values field is accessed with dot syntax to avoid type instability

mutable struct DataFrameDataset <: AbstractDataset
    values::DataFrames.DataFrame
    # We use Array here to allow for overwrites when updating the state
    timestamps::Vector{Dates.DateTime}
    # Resolution is needed because AbstractDataset might have just one row
    resolution::Dates.Millisecond
    end_of_step_index::Int
    last_recorded_row::Int
    update_timestamp::Dates.DateTime
end

function DataFrameDataset(
    values::DataFrames.DataFrame,
    timestamps::Vector{Dates.DateTime},
    resolution::Dates.Millisecond,
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
    resolution::Dates.Millisecond,
)
    return DataFrameDataset(values, [timestamp], resolution, 0, 1, UNSET_INI_TIME)
end

function get_dataset_value(s::DataFrameDataset, date::Dates.DateTime)
    s_index = find_timestamp_index(s.timestamps, date)
    if isnothing(s_index)
        error("Request time stamp $date not in the state")
    end
    return s.values[s_index, :]
end

function get_column_names(::OptimizationContainerKey, s::DataFrameDataset)
    return DataFrames.names(s.values)
end

function get_last_recorded_value(s::DataFrameDataset)
    if get_last_recorded_row(s) == 0
        error("The Dataset hasn't been written yet")
    end
    return s.values[get_last_recorded_row(s), :]
end

function get_end_of_step_timestamp(s::DataFrameDataset)
    return s.timestamps[s.end_of_step_index]
end

"""
Return the timestamp from most recent data row updated in the dataset. This value may not be the same as the result from `get_update_timestamp`
"""
function get_last_updated_timestamp(s::DataFrameDataset)
    last_recorded_row = get_last_recorded_row(s)
    if last_recorded_row == 0
        return UNSET_INI_TIME
    end
    return s.timestamps[last_recorded_row]
end

function get_value_timestamp(s::DataFrameDataset, date::Dates.DateTime)
    s_index = find_timestamp_index(s.timestamps, date)
    if isnothing(s_index)
        error("Request time stamp $date not in the state")
    end
    return s.timestamps[s_index]
end

function set_value!(s::DataFrameDataset, vals, index::Int)
    setindex!(s.values, vals, index, :)
    return
end

function set_value!(s::DataFrameDataset, vals::DataFrames.DataFrame, index::Int)
    @assert_op size(vals)[1] == 1
    set_value!(s, vals[1, :], index)
    return
end

# HDF5Dataset does not account of overwrites in the data. Values are written sequentially.
mutable struct HDF5Dataset <: AbstractDataset
    values::HDF5.Dataset
    column_dataset::HDF5.Dataset
    write_index::Int
    last_recorded_row::Int
    resolution::Dates.Millisecond
    initial_timestamp::Dates.DateTime
    update_timestamp::Dates.DateTime
end

HDF5Dataset(values, column_dataset, resolution, initial_time) =
    HDF5Dataset(values, column_dataset, 1, 0, resolution, initial_time, UNSET_INI_TIME)

function get_column_names(::OptimizationContainerKey, s::HDF5Dataset)
    return s.column_dataset[:]
end

"""
Return the timestamp from most recent data row updated in the dataset. This value may not be the same as the result from `get_update_timestamp`
"""
function get_last_updated_timestamp(s::HDF5Dataset)
    last_recorded_row = get_last_recorded_row(s)
    if last_recorded_row == 0
        return UNSET_INI_TIME
    end
    return s.initial_timestamp + s.resolution * (last_recorded_row - 1)
end

function get_value_timestamp(s::HDF5Dataset, date::Dates.DateTime)
    s_index = find_timestamp_index(s.timestamps, date)
    if isnothing(s_index)
        error("Request time stamp $date not in the state")
    end
    return s.initial_timestamp + s.resolution * (s_index - 1)
end

function set_value!(s::HDF5Dataset, vals, index::Int)
    # Temporary while there is no implementation of caching of em_data
    _write_dataset!(s.values, vals, index:index)
    return
end
