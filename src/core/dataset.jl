abstract type AbstractDataset end

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

mutable struct InMemoryDataset{N} <: AbstractDataset
    "Data with dimensions (N column names, row indexes)"
    values::DenseAxisArray{Float64, N}
    # We use Array here to allow for overwrites when updating the state
    timestamps::Vector{Dates.DateTime}
    # Resolution is needed because AbstractDataset might have just one row
    resolution::Dates.Millisecond
    end_of_step_index::Int
    last_recorded_row::Int
    update_timestamp::Dates.DateTime
end

function InMemoryDataset(
    values::DenseAxisArray{Float64, N},
    timestamps::Vector{Dates.DateTime},
    resolution::Dates.Millisecond,
    end_of_step_index::Int,
) where {N}
    return InMemoryDataset{N}(
        values,
        timestamps,
        resolution,
        end_of_step_index,
        0,
        UNSET_INI_TIME,
    )
end

function InMemoryDataset(values::DenseAxisArray{Float64, N}) where {N}
    return InMemoryDataset{N}(
        values,
        Vector{Dates.DateTime}(),
        Dates.Second(0.0),
        1,
        0,
        UNSET_INI_TIME,
    )
end

# Helper method for one dimensional cases
function InMemoryDataset(
    fill_val::Float64,
    initial_time::Dates.DateTime,
    resolution::Dates.Millisecond,
    end_of_step_index::Int,
    row_count::Int,
    column_names::Vector{String})
    return InMemoryDataset(
        fill_val,
        initial_time,
        resolution,
        end_of_step_index,
        row_count,
        (column_names,),
    )
end

function InMemoryDataset(
    fill_val::Float64,
    initial_time::Dates.DateTime,
    resolution::Dates.Millisecond,
    end_of_step_index::Int,
    row_count::Int,
    column_names::NTuple{N, <:Any}) where {N}
    return InMemoryDataset(
        fill!(
            DenseAxisArray{Float64}(undef, column_names..., 1:row_count),
            fill_val,
        ),
        collect(
            range(
                initial_time;
                step = resolution,
                length = row_count,
            ),
        ),
        resolution,
        end_of_step_index,
    )
end

get_num_rows(s::InMemoryDataset{N}) where {N} = size(s.values)[N]

function make_system_state(
    timestamp::Dates.DateTime,
    resolution::Dates.Millisecond,
    columns::NTuple{N, <:Any},
) where {N}
    return InMemoryDataset(NaN, timestamp, resolution, 0, 1, columns)
end

function get_dataset_value(
    s::T,
    date::Dates.DateTime,
) where {T <: Union{InMemoryDataset{1}, InMemoryDataset{2}}}
    s_index = find_timestamp_index(s.timestamps, date)
    if isnothing(s_index)
        error("Request time stamp $date not in the state")
    end
    return s.values[:, s_index]
end

function get_dataset_value(s::InMemoryDataset{3}, date::Dates.DateTime)
    s_index = find_timestamp_index(s.timestamps, date)
    if isnothing(s_index)
        error("Request time stamp $date not in the state")
    end
    return s.values[:, :, s_index]
end

function get_column_names(k::OptimizationContainerKey, s::InMemoryDataset)
    return get_column_names_from_axis_array(k, s.values)
end

function get_last_recorded_value(s::InMemoryDataset{2})
    if get_last_recorded_row(s) == 0
        error("The Dataset hasn't been written yet")
    end
    return s.values[:, get_last_recorded_row(s)]
end

function get_last_recorded_value(s::InMemoryDataset{3})
    if get_last_recorded_row(s) == 0
        error("The Dataset hasn't been written yet")
    end
    return s.values[:, :, get_last_recorded_row(s)]
end

function get_end_of_step_timestamp(s::InMemoryDataset)
    return s.timestamps[s.end_of_step_index]
end

"""
Return the timestamp from most recent data row updated in the dataset. This value may not be the same as the result from `get_update_timestamp`
"""
function get_last_updated_timestamp(s::InMemoryDataset)
    last_recorded_row = get_last_recorded_row(s)
    if last_recorded_row == 0
        return UNSET_INI_TIME
    end
    return s.timestamps[last_recorded_row]
end

function get_value_timestamp(s::InMemoryDataset, date::Dates.DateTime)
    s_index = find_timestamp_index(s.timestamps, date)
    if isnothing(s_index)
        error("Request time stamp $date not in the state")
    end
    return s.timestamps[s_index]
end

# These set_value! methods expect a single time_step value because they are used to update
#the state so the incoming vals will have one dimension less than the DataSet. The exception
# is for vals of Dimension 1 which are still stored in DataSets of dimension 2.
function set_value!(s::InMemoryDataset{2}, vals::DenseAxisArray{Float64, 2}, index::Int)
    s.values[:, index] = vals[:, index]
    return
end

function set_value!(s::InMemoryDataset{2}, vals::DenseAxisArray{Float64, 1}, index::Int)
    s.values[:, index] = vals
    return
end

function set_value!(s::InMemoryDataset{3}, vals::DenseAxisArray{Float64, 2}, index::Int)
    s.values[:, :, index] = vals
    return
end

function set_value!(s::InMemoryDataset{2}, vals::Array{Float64, 1}, index::Int)
    s.values[:, index] = vals
    return
end

# HDF5Dataset does not account of overwrites in the data. Values are written sequentially.
mutable struct HDF5Dataset{N} <: AbstractDataset
    values::HDF5.Dataset
    column_dataset::HDF5.Dataset
    write_index::Int
    last_recorded_row::Int
    resolution::Dates.Millisecond
    initial_timestamp::Dates.DateTime
    update_timestamp::Dates.DateTime
    column_names::NTuple{N, Vector{String}}

    function HDF5Dataset{N}(values,
        column_dataset,
        write_index,
        last_recorded_row,
        resolution,
        initial_timestamp,
        update_timestamp,
        column_names::NTuple{N, Vector{String}},
    ) where {N}
        new{N}(values, column_dataset, write_index, last_recorded_row, resolution,
            initial_timestamp,
            update_timestamp, column_names)
    end
end

function HDF5Dataset{1}(
    values::HDF5.Dataset,
    column_dataset::HDF5.Dataset,
    ::NTuple{1, Int},
    resolution::Dates.Millisecond,
    initial_time::Dates.DateTime,
)
    HDF5Dataset{1}(
        values,
        column_dataset,
        1,
        0,
        resolution,
        initial_time,
        UNSET_INI_TIME,
        (column_dataset[:],),
    )
end

function HDF5Dataset{2}(
    values::HDF5.Dataset,
    column_dataset::HDF5.Dataset,
    column_lengths::NTuple{2, Int},
    resolution::Dates.Period,
    initial_time::Dates.DateTime,
)
    # The indexing is done in this way because we save all the names in an
    # adjacent column entry in the HDF5 Datatset. The indexes for each column
    # are known because we know how many elements are in each dimension.
    # the names for the first column are store in the 1:first_column_number_of_elements.
    col1 = column_dataset[1:column_lengths[1]]
    # the names for the second column are store in the first_column_number_of elements + 1:end of the column with the names.
    col2 = column_dataset[(column_lengths[1] + 1):end]
    HDF5Dataset{2}(
        values,
        column_dataset,
        1,
        0,
        resolution,
        initial_time,
        UNSET_INI_TIME,
        (col1, col2),
    )
end

function get_column_names(::OptimizationContainerKey, s::HDF5Dataset)
    return s.column_names
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
    error("Not implemented for HDF5Dataset. Required if it is used for simulation state.")
    # TODO: This code is broken because timestamps is not a field.
    #s_index = find_timestamp_index(s.timestamps, date)
    #if isnothing(s_index)
    #    error("Request time stamp $date not in the state")
    #end
    #return s.initial_timestamp + s.resolution * (s_index - 1)
end

function set_value!(s::HDF5Dataset, vals, index::Int)
    # Temporary while there is no implementation of caching of em_data
    _write_dataset!(s.values, vals, index)
    return
end
