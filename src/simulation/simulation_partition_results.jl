const _TEMP_WRITE_POSITION = "__write_position__"

"""
Handles merging of simulation partitions
"""
struct SimulationPartitionResults
    "Directory of main simulation"
    path::String
    "User-defined simulation name"
    simulation_name::String
    "Defines how the simulation is split into partitions"
    partitions::SimulationPartitions
    "Cache of datasets"
    datasets::Dict{String, HDF5.Dataset}
end

function SimulationPartitionResults(path::AbstractString)
    config_file = joinpath(path, "simulation_partitions", "config.json")
    config = open(config_file, "r") do io
        JSON3.read(io, Dict)
    end
    partitions = IS.deserialize(SimulationPartitions, config)
    return SimulationPartitionResults(
        path,
        basename(path),
        partitions,
        Dict{String, HDF5.Dataset}(),
    )
end

"""
Combine all partition simulation files.
"""
function join_simulation(path::AbstractString)
    results = SimulationPartitionResults(path)
    join_simulation(results)
    return
end

function join_simulation(results::SimulationPartitionResults)
    status = _check_jobs(results)
    _merge_store_files!(results)
    _complete(results, status)
    return
end

function _partition_path(x::SimulationPartitionResults, i)
    partition_path = joinpath(x.path, "simulation_partitions", string(i))
    execution_no = _get_most_recent_execution(partition_path, x.simulation_name)
    if execution_no == 1
        execution_path = joinpath(partition_path, x.simulation_name)
    else
        execution_path = joinpath(partition_path, "$(x.simulation_name)-$execution_no")
    end
    return execution_path
end

_store_subpath() = joinpath("data_store", "simulation_store.h5")
_store_path(x::SimulationPartitionResults) = joinpath(x.path, _store_subpath())

function _check_jobs(results::SimulationPartitionResults)
    overall_status = RunStatus.SUCCESSFULLY_FINALIZED
    for i in 1:get_num_partitions(results.partitions)
        job_results_path = joinpath(_partition_path(results, 1), "results")
        status = deserialize_status(job_results_path)
        if status != RunStatus.SUCCESSFULLY_FINALIZED
            @warn "partition job index = $i was not successful: $status"
            overall_status = status
        end
    end

    return overall_status
end

function _merge_store_files!(results::SimulationPartitionResults)
    HDF5.h5open(_store_path(results), "r+") do dst
        for i in 1:get_num_partitions(results.partitions)
            HDF5.h5open(joinpath(_partition_path(results, i), _store_subpath()), "r") do src
                _copy_datasets!(results, i, src, dst)
            end
        end

        for dataset in values(results.datasets)
            if occursin("decision_models", HDF5.name(dataset))
                IS.@assert_op HDF5.attrs(dataset)[_TEMP_WRITE_POSITION] ==
                              size(dataset)[end] + 1
            else
                IS.@assert_op HDF5.attrs(dataset)[_TEMP_WRITE_POSITION] ==
                              size(dataset)[1] + 1
            end
            delete!(HDF5.attrs(dataset), _TEMP_WRITE_POSITION)
        end
    end
end

function _copy_datasets!(
    results::SimulationPartitionResults,
    index::Int,
    src::HDF5.File,
    dst::HDF5.File,
)
    output_types = string.(STORE_CONTAINERS)

    function process_dataset(src_dataset, merge_func)
        if !endswith(HDF5.name(src_dataset), "__columns")
            name = HDF5.name(src_dataset)
            dst_dataset = dst[name]
            if !haskey(results.datasets, name)
                results.datasets[name] = dst_dataset
                HDF5.attrs(dst_dataset)[_TEMP_WRITE_POSITION] = 1
            end
            merge_func(results, index, src_dataset, dst_dataset)
        end
    end

    for src_group in src["simulation/decision_models"]
        for output_type in output_types
            for src_dataset in src_group[output_type]
                process_dataset(src_dataset, _merge_dataset_rows!)
            end
        end
        process_dataset(src_group["optimizer_stats"], _merge_dataset_rows!)
    end

    for output_type in output_types
        for src_dataset in src["simulation/emulation_model/$output_type"]
            process_dataset(src_dataset, _merge_dataset_columns!)
        end
    end
end

function _merge_dataset_columns!(results::SimulationPartitionResults, index, src, dst)
    num_columns = size(src)[1]
    step_range = get_absolute_step_range(results.partitions, index)
    IS.@assert_op num_columns % length(step_range) == 0
    num_columns_per_step = num_columns ÷ length(step_range)
    skip_offset = get_valid_step_offset(results.partitions, index) - 1
    src_start = 1 + num_columns_per_step * skip_offset
    len = get_valid_step_length(results.partitions, index) * num_columns_per_step
    src_end = src_start + len - 1

    IS.@assert_op ndims(src) == ndims(dst)
    dst_start = HDF5.attrs(dst)[_TEMP_WRITE_POSITION]
    if ndims(src) == 2
        IS.@assert_op size(src)[2] == size(dst)[2]
        dst_end = dst_start + len - 1
        dst[dst_start:dst_end, :] = src[src_start:src_end, :]
    else
        error("Unsupported dataset ndims: $(ndims(src))")
    end

    HDF5.attrs(dst)[_TEMP_WRITE_POSITION] = dst_end + 1
    return
end

function _merge_dataset_rows!(results::SimulationPartitionResults, index, src, dst)
    num_rows = size(src)[end]
    step_range = get_absolute_step_range(results.partitions, index)
    IS.@assert_op num_rows % length(step_range) == 0
    num_rows_per_step = num_rows ÷ length(step_range)
    skip_offset = get_valid_step_offset(results.partitions, index) - 1
    src_start = 1 + num_rows_per_step * skip_offset
    len = get_valid_step_length(results.partitions, index) * num_rows_per_step
    src_end = src_start + len - 1

    IS.@assert_op ndims(src) == ndims(dst)
    dst_start = HDF5.attrs(dst)[_TEMP_WRITE_POSITION]
    if ndims(src) == 2
        IS.@assert_op size(src)[1] == size(dst)[1]
        dst_end = dst_start + len - 1
        dst[:, dst_start:dst_end] = src[:, src_start:src_end]
    elseif ndims(src) == 3
        IS.@assert_op size(src)[1] == size(dst)[1]
        IS.@assert_op size(src)[2] == size(dst)[2]
        dst_end = dst_start + len - 1
        IS.@assert_op dst_end <= size(dst)[3]
        dst[:, :, dst_start:dst_end] = src[:, :, src_start:src_end]
    else
        error("Unsupported dataset ndims: $(ndims(src))")
    end

    HDF5.attrs(dst)[_TEMP_WRITE_POSITION] = dst_end + 1
    return
end

function _complete(results::SimulationPartitionResults, status)
    serialize_status(status, joinpath(results.path, "results"))
    store_path = _store_path(results)
    IS.compute_file_hash(dirname(store_path), basename(store_path))
    return
end
