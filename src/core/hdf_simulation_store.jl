const HDF_FILENAME = "simulation_store.h5"
const HDF_SIMULATION_ROOT_PATH = "simulation"
const HDF_OPTIMIZER_STATS_PATH = HDF_SIMULATION_ROOT_PATH * "/optimizer_stats"
const HDF_OPTIMIZER_DATASET_PATH = HDF_OPTIMIZER_STATS_PATH * "/data"

mutable struct Dataset
    dataset::HDF5.Dataset
    column_dataset::HDF5.Dataset
    write_index::Int
end

Dataset(dataset, column_dataset) = Dataset(dataset, column_dataset, 1)

# This only applies if chunks are enabled, and that will only likely happen if we enable
# compression.
# The optimal number of chunks to store in memory will vary widely.
# The HDF docs recommend keeping chunk byte sizes between 10 KiB - 1 MiB.
# We want to make it big enough to compress duplicate values.
# The downside to making this larger is that any read causes the
# entire chunk to be read.
# If one variable has 10,000 components and each value is a Float64 then one row would
# consume 10,000 * 8 = 78 KiB
DEFAULT_MAX_CHUNK_BYTES = 128 * KiB

"""
Stores HDF5 datasets for one stage.
"""
mutable struct StageDatasets
    duals::Dict{Symbol, Dataset}
    parameters::Dict{Symbol, Dataset}
    variables::Dict{Symbol, Dataset}
end

get_duals(stage_dataset::StageDatasets) = stage_dataset.duals
get_parameters(stage_dataset::StageDatasets) = stage_dataset.parameters
get_variables(stage_dataset::StageDatasets) = stage_dataset.variables

function StageDatasets()
    return StageDatasets(
        Dict{Symbol, Dataset}(),
        Dict{Symbol, Dataset}(),
        Dict{Symbol, Dataset}(),
    )
end

"""
Stores simulation data in an HDF file.
"""
mutable struct HdfSimulationStore <: SimulationStore
    file::HDF5.File
    params::SimulationStoreParams
    # The key order is the stage execution order.
    datasets::OrderedDict{Symbol, StageDatasets}
    optimizer_stats_index::Int
    cache::ResultCache
end

get_params(store::HdfSimulationStore) = store.params

function HdfSimulationStore(file_path::AbstractString, mode::AbstractString)
    if !(mode == "w" || mode == "r")
        throw(IS.ConflictingInputsError("mode can only be 'w' or 'r'"))
    end

    if isfile(file_path) && mode == "w"
        throw(IS.ConflictingInputsError("$file_path already exists"))
    end

    file = HDF5.h5open(file_path, mode)
    if mode == "w"
        HDF5.create_group(file, HDF_SIMULATION_ROOT_PATH)
        HDF5.create_group(file, HDF_OPTIMIZER_STATS_PATH)
        @debug "Created store" file_path
    end

    datasets = OrderedDict{Symbol, StageDatasets}()
    cache = ResultCache()
    store = HdfSimulationStore(file, SimulationStoreParams(), datasets, 0, cache)
    mode == "r" && _deserialize_attributes!(store)

    finalizer(_check_state, store)
    return store
end

"""
Construct and open an HdfSimulationStore.

When reading or writing results in a program you should use the method that accepts a
function in order to guarantee that the file handle gets closed.

# Examples

```julia
# Assumes a simulation has been executed in the './rts' directory with these parameters.
path = "./rts"
stage = :ED
var_name = :P__ThermalStandard
timestamp = DateTime("2020-01-01T05:00:00")
store = h5_store_open(path)
df = PowerSimulations.read_result(DataFrame, store, stage, :variables, var_name, timestamp)
```
"""
function h5_store_open(directory::AbstractString, mode = "r", filename = HDF_FILENAME)
    return HdfSimulationStore(joinpath(directory, filename), mode)
end

function h5_store_open(
    func::Function,
    directory::AbstractString,
    mode = "r",
    filename = HDF_FILENAME,
)
    store = nothing
    try
        store = HdfSimulationStore(joinpath(directory, filename), mode)
        func(store)
    finally
        !isnothing(store) && close(store)
    end

    return
end

# TODO: Interfaces to add
# - list_stages(store)
# - list_names(store, type) for duals/parameters/variables by stage
# - get_step_resolution(store)
# - get_resolution(store, stage)

function Base.close(store::HdfSimulationStore)
    flush(store)
    HDF5.close(store.file)
    @debug "Close store file handle" store.file
end

function Base.isopen(store::HdfSimulationStore)
    return isnothing(store.file) ? false : HDF5.isopen(store.file)
end

function Base.flush(store::HdfSimulationStore)
    for (key, param_cache) in store.cache.data
        _flush_data!(param_cache, store, key, false)
    end

    flush(store.file)
    @debug "Flush store" store.file.file_path
end

function append_optimizer_stats!(store::HdfSimulationStore, stats::OptimizerStats)
    @assert_op store.optimizer_stats_index > 0
    dataset = store.file[HDF_OPTIMIZER_DATASET_PATH]
    @assert_op store.optimizer_stats_index <= size(dataset)[1]

    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Write optimizer stats" begin
        dataset[store.optimizer_stats_index, :] = to_array(stats)
    end

    store.optimizer_stats_index += 1
    return
end

function initialize_optimizer_stats_storage!(store::HdfSimulationStore, num_stats::Int)
    root = _get_root(store)
    group = _get_optimizer_stats_path(store)

    num_columns = length(fieldnames(PSI.OptimizerStats))
    dataset = HDF5.create_dataset(
        group,
        "data",
        HDF5.datatype(Float64),
        HDF5.dataspace((num_stats, num_columns)),
    )

    HDF5.attributes(dataset)["columns"] = get_column_names(OptimizerStats)
    @debug "Created dataset for optimizer stats" dataset size(dataset)
    store.optimizer_stats_index = 1
    return
end

function initialize_stage_storage!(
    store::HdfSimulationStore,
    params,
    stage_reqs,
    flush_rules,
)
    store.params = params
    root = store.file[HDF_SIMULATION_ROOT_PATH]
    stages_group = _get_group_or_create(root, "stages")
    set_max_size!(store.cache, flush_rules.max_size)
    set_min_flush_size!(store.cache, flush_rules.min_flush_size)
    @debug "initialize_stage_storage" store.cache

    for stage in keys(store.params.stages)
        store.datasets[stage] = StageDatasets()
        stage_group = _get_group_or_create(stages_group, string(stage))
        for type in STORE_CONTAINERS
            group = _get_group_or_create(stage_group, string(type))
            for (name, reqs) in getfield(stage_reqs[stage], type)
                dataset = _create_dataset(group, string(name), reqs)
                # Columns can't be stored in attributes because they might be larger than
                # the max size of 64 KiB.
                col = _make_column_name(name)
                HDF5.write_dataset(group, col, string.(reqs["columns"]))
                column_dataset = group[col]
                datasets = getfield(store.datasets[stage], type)
                datasets[name] = Dataset(dataset, column_dataset)
                key = make_cache_key(stage, type, name)
                add_param_cache!(store.cache, key, get_rule(flush_rules, key))
            end
        end
    end

    # This has to run after stage groups are created.
    _serialize_attributes(store, stages_group, stage_reqs)
end

log_cache_hit_percentages(x::HdfSimulationStore) = log_cache_hit_percentages(x.cache)

"""
Return DataFrame, DenseAxisArray, or Array for a model result at a timestamp.
"""
function read_result(
    ::Type{DataFrames.DataFrame},
    store::HdfSimulationStore,
    stage_name,
    type,
    name,
    timestamp::Dates.DateTime,
)
    key = make_cache_key(stage_name, type, name)
    data, columns = _read_data_columns(store, key, timestamp)
    return DataFrames.DataFrame(data, Symbol.(columns))
end

function read_result(
    ::Type{JuMP.Containers.DenseAxisArray},
    store::HdfSimulationStore,
    stage_name,
    type,
    name,
    timestamp::Dates.DateTime,
)
    key = make_cache_key(stage_name, type, name)
    data, columns = _read_data_columns(store, key, timestamp)
    return JuMP.Containers.DenseAxisArray(data, size(data[1]), columns)
end

function read_result(
    ::Type{<:Array},
    store::HdfSimulationStore,
    stage_name,
    type,
    name,
    timestamp::Dates.DateTime,
)
    key = make_cache_key(stage_name, type, name)
    if is_cached!(store.cache, key, timestamp)
        data = read_result(store.cache, key, timestamp)
    else
        # PERF: If this will be commonly used then we need to remove reading of columns.
        data, _ = read_result(store, key, timestamp)
    end
end

function read_result(store::HdfSimulationStore, key, timestamp::Dates.DateTime)
    simulation_step, execution_index = _get_indices(store, key.stage, timestamp)
    return read_result(store, key, simulation_step, execution_index)
end

function read_result(
    store::HdfSimulationStore,
    key,
    simulation_step::Int,
    execution_index::Int,
)
    @assert key.type in STORE_CONTAINERS "$(key.type)"

    !isopen(store) && throw(ArgumentError("store must be opened prior to reading"))

    horizon = store.params.stages[key.stage].horizon
    num_executions = store.params.stages[key.stage].num_executions
    if execution_index > num_executions
        throw(ArgumentError("execution_index = $execution_index cannot be larger than $num_executions"))
    end

    dataset = get_dataset(store, key)
    row_index = (simulation_step - 1) * num_executions + execution_index
    columns = dataset.column_dataset[:]

    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Read dataset" begin
        data = dataset.dataset[:, :, row_index]
    end

    # TODO DT: this doesn't handle 4d datasets

    return data, columns
end

"""
Write a model result for a timestamp to the store.
"""
function write_result!(
    store::HdfSimulationStore,
    stage_name,
    container_type,
    name,
    timestamp,
    array,
)
    key = make_cache_key(stage_name, container_type, name)
    param_cache = get_param_cache(store.cache, key)

    cur_size = get_size(store.cache)
    add_result!(param_cache, timestamp, array, is_full(store.cache, cur_size))

    if get_size(param_cache) >= get_min_flush_size(store.cache)
        discard = !should_keep_in_cache(param_cache)

        # PERF: A potentially significant performance improvement would be to queue several
        # flushes and submit them in parallel.
        size_flushed = _flush_data!(param_cache, store, key, discard)

        @debug "flushed data" key size_flushed discard
        !discard && mark_clean!(param_cache, timestamp)
    end

    # Disabled because this is currently a noop.
    #if is_full(store.cache)
    #    _flush_data!(store.cache, store)
    #end

    @debug "write_result" get_size(store.cache)
    return
end

function _check_state(store::HdfSimulationStore)
    if has_dirty(store.cache)
        error("BUG!!! dirty cache is present at shutdown: $(store.file)")
    end
end

function _compute_chunk_count(dims, dtype; max_chunk_bytes = DEFAULT_MAX_CHUNK_BYTES)
    bytes_per_element = sizeof(dtype)

    if length(dims) == 2
        size_row = dims[1] * bytes_per_element
    elseif length(dims) == 3
        size_row = dims[1] * dims[2] * bytes_per_element
    elseif length(dims) == 4
        size_row = dims[1] * dims[2] * dims[3] * bytes_per_element
    else
        error("unsupported dims = $dims")
    end

    chunk_count = minimum((trunc(max_chunk_bytes / size_row), dims[end]))
    if chunk_count == 0
        error(
            "HDF Max Chunk Bytes is smaller than the size of a row. Please increase it. " *
            "max_chunk_bytes=$max_chunk_bytes dims=$dims " *
            "size_row=$size_row",
        )
    end

    chunk_dims = [x for x in dims]
    chunk_dims[end] = chunk_count
    return chunk_dims
end

function _create_dataset(group, name, reqs)
    dataset = HDF5.create_dataset(
        group,
        string(name),
        HDF5.datatype(Float64),
        HDF5.dataspace(reqs["dims"]),
        # We are choosing to optimize read performance in the first implementation.
        # Compression would slow that down.
        #chunk = _compute_chunk_count(reqs["dims"], Float64),
        #shuffle = (),
        #deflate = 3,
    )
    @debug "Created dataset for" group name size(dataset)
    return dataset
end

function _deserialize_attributes!(store::HdfSimulationStore)
    group = store.file["simulation"]
    initial_time = Dates.DateTime(HDF5.read(HDF5.attributes(group)["initial_time"]))
    step_resolution =
        Dates.Millisecond(HDF5.read(HDF5.attributes(group)["step_resolution_ms"]))
    num_steps = HDF5.read(HDF5.attributes(group)["num_steps"])
    store.params = SimulationStoreParams(initial_time, step_resolution, num_steps)
    empty!(store.datasets)
    for stage in HDF5.read(HDF5.attributes(group)["stage_order"])
        stage_group = store.file["simulation/stages/$stage"]
        stage_name = Symbol(stage)
        store.params.stages[stage_name] = SimulationStoreStageParams(
            HDF5.read(HDF5.attributes(stage_group)["num_executions"]),
            HDF5.read(HDF5.attributes(stage_group)["horizon"]),
            Dates.Millisecond(HDF5.read(HDF5.attributes(stage_group)["interval_ms"])),
            Dates.Millisecond(HDF5.read(HDF5.attributes(stage_group)["resolution_ms"])),
            HDF5.read(HDF5.attributes(stage_group)["base_power"]),
            Base.UUID(HDF5.read(HDF5.attributes(stage_group)["system_uuid"])),
        )
        store.datasets[stage_name] = StageDatasets()
        for type in STORE_CONTAINERS
            group = stage_group[string(type)]
            for name in names(group)
                if !endswith(name, "columns")
                    dataset = group[name]
                    column_dataset = group[_make_column_name(name)]
                    item = Dataset(dataset, column_dataset)
                    getfield(store.datasets[stage_name], type)[Symbol(name)] = item
                end
                key = make_cache_key(stage_name, type, Symbol(name))
                add_param_cache!(store.cache, key, CacheFlushRule())
            end
        end
    end

    @debug "deserialized store params and datasets" store.params
end

function _serialize_attributes(store::HdfSimulationStore, stages_group, stage_reqs)
    params = store.params
    group = store.file["simulation"]
    HDF5.attributes(group)["stage_order"] = [string(k) for k in keys(params.stages)]
    HDF5.attributes(group)["initial_time"] = string(params.initial_time)
    HDF5.attributes(group)["step_resolution_ms"] =
        Dates.Millisecond(params.step_resolution).value
    HDF5.attributes(group)["num_steps"] = params.num_steps

    for stage in keys(params.stages)
        stage_group = store.file["simulation/stages/$stage"]
        HDF5.attributes(stage_group)["num_executions"] = params.stages[stage].num_executions
        HDF5.attributes(stage_group)["horizon"] = params.stages[stage].horizon
        HDF5.attributes(stage_group)["resolution_ms"] =
            Dates.Millisecond(params.stages[stage].resolution).value
        HDF5.attributes(stage_group)["interval_ms"] =
            Dates.Millisecond(params.stages[stage].interval).value
        HDF5.attributes(stage_group)["base_power"] = params.stages[stage].base_power
        HDF5.attributes(stage_group)["system_uuid"] =
            string(params.stages[stage].system_uuid)
    end
end

function _flush_data!(cache::ParamResultCache, store::HdfSimulationStore, key, discard)
    !has_dirty(cache) && return 0
    dataset = get_dataset(store, key)
    timestamps, data = get_data_to_flush!(cache, get_min_flush_size(store.cache))
    num_results = length(timestamps)
    @assert_op num_results == size(data)[end]
    end_index = dataset.write_index + length(timestamps) - 1
    write_range = (dataset.write_index):end_index
    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Write $(key.type) array to HDF" begin
        _write_dataset!(dataset.dataset, data, write_range)
    end

    discard && discard_results!(cache, timestamps)

    dataset.write_index += num_results
    size_flushed = cache.size_per_entry * num_results

    @debug "Flushed cache results to HDF5" key size_flushed
    return size_flushed
end

function _flush_data!(cache::ResultCache, store::HdfSimulationStore)
    # PERF: may need to optimize memory management
    # Do we need flush down to some ~70% watermark?
    # What are GC implications of doing replacing entries one at a time vs freeing large
    # chunks at once?
end

function _get_columns_dataset(store::HdfSimulationStore, key)
    return getfield(store.datasets[key.stage], key.type)[key.name].columns
end

function get_dataset(::Type{OptimizerStats}, store::HdfSimulationStore)
    return store.file[OPTIMIZER_DATASET_PATH]
end

function get_dataset(store::HdfSimulationStore, stage_name::Symbol)
    return store.datasets[stage_name]
end

function get_dataset(store::HdfSimulationStore, key)
    return getfield(store.datasets[key.stage], key.type)[key.name]
end

function _get_group_or_create(parent, group_name)
    if HDF5.exists(parent, group_name)
        group = parent[group_name]
    else
        group = HDF5.create_group(parent, group_name)
        @debug "Created group" group
    end

    return group
end

_make_column_name(name) = string(name) * "__columns"

function _get_indices(store::HdfSimulationStore, stage, timestamp)
    time_diff = Dates.Millisecond(timestamp - store.params.initial_time)
    if time_diff % store.params.step_resolution == 0
        step = Int(time_diff / store.params.step_resolution)
    else
        step = trunc(Int, time_diff / store.params.step_resolution) + 1
    end
    if step > store.params.num_steps
        throw(ArgumentError("timestamp = $timestamp is beyond the simulation: step = $step"))
    end
    stage_params = store.params.stages[stage]
    initial_time = store.params.initial_time + (step - 1) * store.params.step_resolution
    time_diff = timestamp - initial_time
    if time_diff % stage_params.interval != Dates.Millisecond(0)
        throw(ArgumentError("timestamp = $timestamp is not a valid stage timestamp"))
    end
    execution_index = Int(time_diff / stage_params.interval) + 1
    return step, execution_index
end

_get_optimizer_stats_path(store::HdfSimulationStore) = store.file[HDF_OPTIMIZER_STATS_PATH]
_get_optimizer_data_path(store::HdfSimulationStore) = store.file[HDF_OPTIMIZER_DATASET_PATH]
_get_root(store::HdfSimulationStore) = store.file[HDF_SIMULATION_ROOT_PATH]

function _read_column_names(::Type{OptimizerStats}, store::HdfSimulationStore)
    dataset = get_dataset(OptimizerStats, store)
    return HDF5.read(HDF5.attributes(dataset), "columns")
end

function _read_data_columns(store, key, timestamp)
    if is_cached!(store.cache, key, timestamp)
        data = read_result(store.cache, key, timestamp)
        column_dataset = get_dataset(store, key).column_dataset
        columns = column_dataset[:]
    else
        data, columns = read_result(store, key, timestamp)
    end

    return data, columns
end

function _read_length(::Type{OptimizerStats}, store::HdfSimulationStore)
    dataset = get_dataset(OptimizerStats, store)
    return HDF5.read(HDF5.attributes(dataset), "columns")
end

function _write_dataset!(dataset, array, row_range)
    if ndims(array) == 2
        # TODO DT: hack
        dataset[:, 1, row_range] = array
    elseif ndims(array) == 3
        dataset[:, :, row_range] = array
    elseif ndims(array) == 4
        dataset[:, :, :, row_range] = array
    else
        error("ndims not supported: $(ndims(array))")
    end

    @debug "wrote dataset" dataset row_range
end
