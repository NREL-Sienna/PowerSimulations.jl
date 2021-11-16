const HDF_FILENAME = "simulation_store.h5"
const HDF_SIMULATION_ROOT_PATH = "simulation"
const OPTIMIZER_STATS_PATH = "optimizer_stats"

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
Stores HDF5 datasets for one problem.
"""
mutable struct ModelDatasets
    duals::Dict{ConstraintKey, Dataset}
    parameters::Dict{ParameterKey, Dataset}
    variables::Dict{VariableKey, Dataset}
    aux_variables::Dict{AuxVarKey, Dataset}
    expressions::Dict{ExpressionKey, Dataset}
end

function ModelDatasets()
    return ModelDatasets(
        Dict{ConstraintKey, Dataset}(),
        Dict{ParameterKey, Dataset}(),
        Dict{VariableKey, Dataset}(),
        Dict{AuxVarKey, Dataset}(),
        Dict{ExpressionKey, Dataset}(),
    )
end

"""
Stores simulation data in an HDF file.
"""
mutable struct HdfSimulationStore <: SimulationStore
    file::HDF5.File
    params::SimulationStoreParams
    # The key order is the problem execution order.
    datasets::OrderedDict{Symbol, ModelDatasets}
    # The key is the problem name.
    optimizer_stats_datasets::Dict{Symbol, HDF5.Dataset}
    optimizer_stats_write_index::Dict{Symbol, Int}
    cache::OptimizationResultCache
end

function HdfSimulationStore(
    file_path::AbstractString,
    mode::AbstractString;
    problem_path = nothing,
)
    if !(mode == "w" || mode == "r")
        throw(IS.ConflictingInputsError("mode can only be 'w' or 'r'"))
    end

    if isfile(file_path) && mode == "w"
        throw(IS.ConflictingInputsError("$file_path already exists"))
    end

    file = HDF5.h5open(file_path, mode)
    if mode == "w"
        HDF5.create_group(file, HDF_SIMULATION_ROOT_PATH)
        @debug "Created store" file_path
    end

    datasets = OrderedDict{Symbol, ModelDatasets}()
    cache = OptimizationResultCache()
    store = HdfSimulationStore(
        file,
        SimulationStoreParams(),
        datasets,
        Dict{Symbol, HDF5.Dataset}(),
        Dict{Symbol, Int}(),
        cache,
    )
    mode == "r" && _deserialize_attributes!(store, problem_path)

    finalizer(_check_state, store)
    return store
end

"""
Construct and open an HdfSimulationStore.

When reading or writing results in a program you should use the method that accepts a
function in order to guarantee that the file handle gets closed.

# Arguments
- `directory::AbstractString`: Directory containing the store file
- `mode::AbstractString`: Mode to use to open the store file
- `filename::AbstractString`: Base name of the store file
- `problem_path::AbstractString`: Path to the directory containing serialized problem
   information. Required when reading an existing simulation.

# Examples

```julia
# Assumes a simulation has been executed in the './rts' directory with these parameters.
path = "./rts"
problem = :ED
var_name = :P__ThermalStandard
timestamp = DateTime("2020-01-01T05:00:00")
store = open_store(HdfSimulationStore, path)
df = PowerSimulations.read_result(DataFrame, store, model, :variables, var_name, timestamp)
```
"""
function open_store(
    ::Type{HdfSimulationStore},
    directory::AbstractString,
    mode = "r";
    filename = HDF_FILENAME,
    problem_path = nothing,
)
    return HdfSimulationStore(
        joinpath(directory, filename),
        mode,
        problem_path = problem_path,
    )
end

function open_store(
    func::Function,
    ::Type{HdfSimulationStore},
    directory::AbstractString,
    mode = "r";
    filename = HDF_FILENAME,
    problem_path = nothing,
)
    store = nothing
    try
        store = HdfSimulationStore(
            joinpath(directory, filename),
            mode,
            problem_path = problem_path,
        )
        return func(store)
    finally
        store !== nothing && close(store)
    end
end

function Base.close(store::HdfSimulationStore)
    flush(store)
    HDF5.close(store.file)
    @debug "Close store file handle" store.file
end

function Base.isopen(store::HdfSimulationStore)
    return store.file === nothing ? false : HDF5.isopen(store.file)
end

function Base.flush(store::HdfSimulationStore)
    for (key, output_cache) in store.cache.data
        _flush_data!(output_cache, store, key, false)
    end

    flush(store.file)
    @debug "Flush store"
end

get_params(store::HdfSimulationStore) = store.params
function get_model_params(store::HdfSimulationStore, model_name::Symbol)
    return get_params(store).models_params[model_name]
end

"""
Return the problem names in order of execution.
"""
list_problems(store::HdfSimulationStore) = keys(store.datasets)

"""
Return the fields stored for the `problem` and `container_type` (duals/parameters/variables).
"""
function list_fields(store::HdfSimulationStore, problem::Symbol, container_type::Symbol)
    container = getfield(store.datasets[problem], container_type)
    return keys(container)
end

function write_optimizer_stats!(
    store::HdfSimulationStore,
    model_name,
    stats::OptimizerStats,
    timestamp,  # Unused here. Matches the interface for InMemorySimulationStore.
)
    dataset = _get_dataset(OptimizerStats, store, model_name)

    # Uncomment for performance measures of HDF Store
    #TimerOutputs.@timeit RUN_SIMULATION_TIMER "Write optimizer stats" begin
    dataset[:, store.optimizer_stats_write_index[model_name]] = to_array(stats)
    #end

    store.optimizer_stats_write_index[model_name] += 1
    return
end

"""
Read the optimizer stats for a problem execution.
"""
function read_problem_optimizer_stats(
    store::HdfSimulationStore,
    simulation_step,
    problem,
    execution_index,
)
    optimizer_stats_write_index =
        (simulation_step - 1) * store.params.models_params[problem].num_executions + index
    dataset = _get_dataset(OptimizerStats, store, problem)
    return OptimizerStats(dataset[:, optimizer_stats_write_index])
end

"""
Return the optimizer stats for a problem as a DataFrame.
"""
function read_problem_optimizer_stats(store::HdfSimulationStore, problem)
    dataset = _get_dataset(OptimizerStats, store, problem)
    data = permutedims(dataset[:, :])
    stats = [to_namedtuple(OptimizerStats(data[i, :])) for i in axes(data)[1]]
    return DataFrames.DataFrame(stats)
end

function initialize_problem_storage!(
    store::HdfSimulationStore,
    params,
    problem_reqs,
    flush_rules,
)
    store.params = params
    root = store.file[HDF_SIMULATION_ROOT_PATH]
    problems_group = _get_group_or_create(root, "problems")
    set_max_size!(store.cache, flush_rules.max_size)
    set_min_flush_size!(store.cache, flush_rules.min_flush_size)
    @debug "initialize_problem_storage" store.cache

    for problem in keys(store.params.models_params)
        store.datasets[problem] = ModelDatasets()
        problem_group = _get_group_or_create(problems_group, string(problem))
        for type in STORE_CONTAINERS
            group = _get_group_or_create(problem_group, string(type))
            for (key, reqs) in getfield(problem_reqs[problem], type)
                name = encode_key_as_string(key)
                dataset = _create_dataset(group, name, reqs)
                # Columns can't be stored in attributes because they might be larger than
                # the max size of 64 KiB.
                col = _make_column_name(name)
                HDF5.write_dataset(group, col, string.(reqs["columns"]))
                column_dataset = group[col]
                datasets = getfield(store.datasets[problem], type)
                datasets[key] = Dataset(dataset, column_dataset)
                add_output_cache!(
                    store.cache,
                    problem,
                    key,
                    get_rule(flush_rules, problem, key),
                )
            end
        end

        num_stats = params.num_steps * params.models_params[problem].num_executions
        columns = fieldnames(PSI.OptimizerStats)
        num_columns = length(columns)
        dataset = HDF5.create_dataset(
            problem_group,
            OPTIMIZER_STATS_PATH,
            HDF5.datatype(Float64),
            HDF5.dataspace((num_columns, num_stats)),
        )
        HDF5.attributes(dataset)["columns"] = [string(x) for x in columns]
        store.optimizer_stats_datasets[problem] = dataset
        store.optimizer_stats_write_index[problem] = 1
        @debug "Initialized optimizer_stats_datasets $problem ($num_columns, $num_stats)"
    end

    # This has to run after problem groups are created.
    _serialize_attributes(store, problems_group, problem_reqs)
end

log_cache_hit_percentages(x::HdfSimulationStore) = log_cache_hit_percentages(x.cache)

"""
Return DataFrame, DenseAxisArray, or Array for a model result at a timestamp.
"""
function read_result(
    ::Type{DataFrames.DataFrame},
    store::HdfSimulationStore,
    model_name::Symbol,
    key::OptimizationContainerKey,
    timestamp::Dates.DateTime,
)
    data, columns = _read_data_columns(store, model_name, key, timestamp)
    return DataFrames.DataFrame(data, Symbol.(columns))
end

function read_result(
    ::Type{JuMP.Containers.DenseAxisArray},
    store::HdfSimulationStore,
    model_name::Symbol,
    key::OptimizationContainerKey,
    timestamp::Dates.DateTime,
)
    data, columns = _read_data_columns(store, model_name, key, timestamp)
    return JuMP.Containers.DenseAxisArray(data, size(data[1]), columns)
end

function read_result(
    ::Type{<:Array},
    store::HdfSimulationStore,
    model_name::Symbol,
    key::OptimizationContainerKey,
    timestamp::Dates.DateTime,
)
    if is_cached(store.cache, model_name, key, timestamp)
        data = read_result(store.cache, model_name, key, timestamp)
    else
        # PERF: If this will be commonly used then we need to remove reading of columns.
        data, _ = read_result(store, model_name, key, timestamp)
    end
end

function read_result(
    store::HdfSimulationStore,
    key::OptimizationContainerKey,
    timestamp::Dates.DateTime,
)
    simulation_step, execution_index = _get_indices(store, key.model, timestamp)
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

    horizon = store.params.models_params[key.model].horizon
    num_executions = store.params.models_params[key.model].num_executions
    if execution_index > num_executions
        throw(
            ArgumentError(
                "execution_index = $execution_index cannot be larger than $num_executions",
            ),
        )
    end

    dataset = _get_dataset(store, key)
    dset = dataset.dataset
    row_index = (simulation_step - 1) * num_executions + execution_index
    columns = dataset.column_dataset[:]

    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Read dataset" begin
        num_dims = ndims(dset)
        if num_dims == 3
            data = dset[:, :, row_index]
            #elseif num_dims == 4
            #    data = dset[:, :, :, row_index]
        else
            error("unsupported dims: $num_dims")
        end
    end

    return data, columns
end

"""
Write a model result for a timestamp to the store.
"""
function write_result!(
    store::HdfSimulationStore,
    model_name,
    key::OptimizationContainerKey,
    timestamp,
    data,
    columns = nothing,  # Unused here. Matches the interface for InMemorySimulationStore.
)
    output_cache = get_output_cache(store.cache, model_name, key)

    cur_size = get_size(store.cache)
    add_result!(output_cache, timestamp, to_array(data), is_full(store.cache, cur_size))

    if get_dirty_size(output_cache) >= get_min_flush_size(store.cache)
        discard = !should_keep_in_cache(output_cache)

        # PERF: A potentially significant performance improvement would be to queue several
        # flushes and submit them in parallel.
        size_flushed = _flush_data!(output_cache, store, model_name, key, discard)

        @debug "flushed data" key size_flushed discard
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
        name,
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

function _deserialize_attributes!(store::HdfSimulationStore, problem_path)
    problem_path === nothing && error("problem_path must be set when reading")
    group = store.file["simulation"]
    initial_time = Dates.DateTime(HDF5.read(HDF5.attributes(group)["initial_time"]))
    step_resolution =
        Dates.Millisecond(HDF5.read(HDF5.attributes(group)["step_resolution_ms"]))
    num_steps = HDF5.read(HDF5.attributes(group)["num_steps"])
    store.params = SimulationStoreParams(initial_time, step_resolution, num_steps)
    empty!(store.datasets)
    for problem in HDF5.read(HDF5.attributes(group)["problem_order"])
        problem_group = store.file["simulation/problems/$problem"]
        model_name = Symbol(problem)
        container_metadata =
            deserialize_metadata(OptimizationContainerMetadata, problem_path, problem)
        store.params.models_params[model_name] = ModelStoreParams(
            HDF5.read(HDF5.attributes(problem_group)["num_executions"]),
            HDF5.read(HDF5.attributes(problem_group)["horizon"]),
            Dates.Millisecond(HDF5.read(HDF5.attributes(problem_group)["interval_ms"])),
            Dates.Millisecond(HDF5.read(HDF5.attributes(problem_group)["resolution_ms"])),
            HDF5.read(HDF5.attributes(problem_group)["end_of_interval_step"]),
            HDF5.read(HDF5.attributes(problem_group)["base_power"]),
            Base.UUID(HDF5.read(HDF5.attributes(problem_group)["system_uuid"])),
            container_metadata,
        )
        store.datasets[model_name] = ModelDatasets()
        for type in STORE_CONTAINERS
            group = problem_group[string(type)]
            for name in keys(group)
                if !endswith(name, "columns")
                    dataset = group[name]
                    column_dataset = group[_make_column_name(name)]
                    item = Dataset(dataset, column_dataset)
                    container_key = deserialize_key(container_metadata, name)
                    getfield(store.datasets[model_name], type)[container_key] = item
                    add_output_cache!(store.cache, problem, key, get_rule(flush_rules, key))
                end
            end
        end

        store.optimizer_stats_datasets[model_name] = problem_group[OPTIMIZER_STATS_PATH]
        store.optimizer_stats_write_index[model_name] = 0
    end

    @debug "deserialized store params and datasets" store.params
end

function _serialize_attributes(store::HdfSimulationStore, problems_group, problem_reqs)
    params = store.params
    group = store.file["simulation"]
    HDF5.attributes(group)["problem_order"] =
        [string(k) for k in keys(params.models_params)]
    HDF5.attributes(group)["initial_time"] = string(params.initial_time)
    HDF5.attributes(group)["step_resolution_ms"] =
        Dates.Millisecond(params.step_resolution).value
    HDF5.attributes(group)["num_steps"] = params.num_steps

    for problem in keys(params.models_params)
        problem_group = store.file["simulation/problems/$problem"]
        HDF5.attributes(problem_group)["num_executions"] =
            params.models_params[problem].num_executions
        HDF5.attributes(problem_group)["horizon"] = params.models_params[problem].horizon
        HDF5.attributes(problem_group)["resolution_ms"] =
            Dates.Millisecond(params.models_params[problem].resolution).value
        HDF5.attributes(problem_group)["end_of_interval_step"] =
            params.models_params[problem].end_of_interval_step
        HDF5.attributes(problem_group)["interval_ms"] =
            Dates.Millisecond(params.models_params[problem].interval).value
        HDF5.attributes(problem_group)["base_power"] =
            params.models_params[problem].base_power
        HDF5.attributes(problem_group)["system_uuid"] =
            string(params.models_params[problem].system_uuid)
    end
end

function _flush_data!(
    cache::OptimzationResultCache,
    store::HdfSimulationStore,
    model_name,
    key::OptimizationContainerKey,
    discard,
)
    return _flush_data!(cache, store, OptimizationResultCacheKey(model_name, key), discard)
end

function _flush_data!(
    cache::OptimzationResultCache,
    store::HdfSimulationStore,
    cache_key::OptimizationResultCacheKey,
    discard,
)
    !has_dirty(cache) && return 0
    dataset = _get_dataset(store, cache_key)
    timestamps, data = get_data_to_flush!(cache, get_min_flush_size(store.cache))
    num_results = length(timestamps)
    @assert_op num_results == size(data)[end]
    end_index = dataset.write_index + length(timestamps) - 1
    write_range = (dataset.write_index):end_index
    # Enable only for development and benchmarking
    #TimerOutputs.@timeit RUN_SIMULATION_TIMER "Write $(key.key) array to HDF" begin
    _write_dataset!(dataset.dataset, data, write_range)
    #end

    discard && discard_results!(cache, timestamps)

    dataset.write_index += num_results
    size_flushed = cache.size_per_entry * num_results

    @debug "Flushed cache results to HDF5" key size_flushed
    return size_flushed
end

function _flush_data!(cache::OptimzationResultCache, store::HdfSimulationStore)
    # PERF: may need to optimize memory management
    # Do we need flush down to some ~70% watermark?
    # What are GC implications of doing replacing entries one at a time vs freeing large
    # chunks at once?
end

function _get_columns_dataset(store::HdfSimulationStore, key)
    return getfield(store.datasets[key.model], key.type)[key.name].columns
end

function _get_dataset(::Type{OptimizerStats}, store::HdfSimulationStore, model_name)
    return store.optimizer_stats_datasets[model_name]
end

function _get_dataset(store::HdfSimulationStore, model_name::Symbol)
    return store.datasets[model_name]
end

function _get_dataset(
    store::HdfSimulationStore,
    model_name::Symbol,
    opt_container_key::VariableKey,
)
    return getfield(store.datasets[model_name], STORE_CONTAINER_VARIABLES)[opt_container_key]
end

function _get_dataset(
    store::HdfSimulationStore,
    model_name::Symbol,
    opt_container_key::ConstraintKey,
)
    return getfield(store.datasets[model_name], STORE_CONTAINER_DUALS)[opt_container_key]
end

function _get_dataset(
    store::HdfSimulationStore,
    model_name::Symbol,
    opt_container_key::AuxVarKey,
)
    return getfield(store.datasets[model_name], STORE_CONTAINER_AUX_VARIABLES)[opt_container_key]
end

function _get_dataset(
    store::HdfSimulationStore,
    model_name::Symbol,
    opt_container_key::ParameterKey,
)
    return getfield(store.datasets[model_name], STORE_CONTAINER_PARAMETERS)[opt_container_key]
end

function _get_dataset(
    store::HdfSimulationStore,
    model_name::Symbol,
    opt_container_key::ExpressionKey,
)
    return getfield(store.datasets[model_name], STORE_CONTAINER_EXPRESSIONS)[opt_container_key]
end

function _get_dataset(store::HdfSimulationStore, key::OptimizationResultCacheKey)
    return _get_dataset(store, key.model, key.key)
end

function _get_group_or_create(parent, group_name)
    if haskey(parent, group_name)
        group = parent[group_name]
    else
        group = HDF5.create_group(parent, group_name)
        @debug "Created group" group
    end

    return group
end

_make_column_name(name) = string(name) * "__columns"

function _get_indices(store::HdfSimulationStore, problem::Symbol, timestamp)
    time_diff = Dates.Millisecond(timestamp - store.params.initial_time)
    step = time_diff ÷ store.params.step_resolution + 1
    if step > store.params.num_steps
        throw(
            ArgumentError("timestamp = $timestamp is beyond the simulation: step = $step"),
        )
    end
    problem_params = store.params.models_params[problem]
    initial_time = store.params.initial_time + (step - 1) * store.params.step_resolution
    time_diff = timestamp - initial_time
    if time_diff % problem_params.interval != Dates.Millisecond(0)
        throw(ArgumentError("timestamp = $timestamp is not a valid problem timestamp"))
    end
    execution_index = time_diff ÷ problem_params.interval + 1
    return step, execution_index
end

_get_root(store::HdfSimulationStore) = store.file[HDF_SIMULATION_ROOT_PATH]

function _read_column_names(::Type{OptimizerStats}, store::HdfSimulationStore)
    dataset = _get_dataset(OptimizerStats, store)
    return HDF5.read(HDF5.attributes(dataset), "columns")
end

function _read_data_columns(
    store::HdfSimulationStore,
    model_name::Symbol,
    key::OptimizationContainerKey,
    timestamp,
)
    if is_cached(store.cache, model_name, key, timestamp)
        data = read_result(store.cache, model_name, key, timestamp)
        column_dataset = _get_dataset(store, model_name, key).column_dataset
        columns = column_dataset[:]
    else
        data, columns = read_result(store, model_name, key, timestamp)
    end

    return data, columns
end

function _read_length(::Type{OptimizerStats}, store::HdfSimulationStore)
    dataset = _get_dataset(OptimizerStats, store)
    return HDF5.read(HDF5.attributes(dataset), "columns")
end

function _write_dataset!(dataset, array, row_range)
    if ndims(array) == 2
        dataset[:, 1, row_range] = array
    elseif ndims(array) == 3
        dataset[:, :, row_range] = array
        #elseif ndims(array) == 4
        #    dataset[:, :, :, row_range] = array
    else
        error("ndims not supported: $(ndims(array))")
    end

    @debug "wrote dataset" dataset row_range
end
