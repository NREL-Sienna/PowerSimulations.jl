const HDF_FILENAME = "simulation_store.h5"
const HDF_SIMULATION_ROOT_PATH = "simulation"
const HDF_OPTIMIZER_STATS_PATH = HDF_SIMULATION_ROOT_PATH * "/optimizer_stats"
const DATASET_TYPE_DUALS = "duals"
const DATASET_TYPE_PARAMETERS = "parameters"
const DATASET_TYPE_VARIABLES = "variables"
const DATASET_TYPES = Set((DATASET_TYPE_PARAMETERS, DATASET_TYPE_VARIABLES))

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
Stores simulation data in an HDF file.
"""
mutable struct HdfSimulationStore <: SimulationStore
    file_path::String
    stages::Vector  # TODO DT
    file::Union{Nothing, Any}  # TODO DT: actual type
    optimizer_stats_index::Int
    metadata_cache::Dict  # Caches frequently-read attributes
end

function HdfSimulationStore(directory::AbstractString; create = false, filename = HDF_FILENAME)
    file_path = joinpath(directory, filename)
    if isfile(file_path) && create
        throw(IS.ConflictingInputsError("$filename already exists"))
    end

    file = nothing
    if create
        HDF5.h5open(file_path, "w") do file
            file = HDF5.g_create(file, HDF_SIMULATION_ROOT_PATH)
            @debug "Created store" file_path
        end
    end

    store = HdfSimulationStore(file_path, [], file, 0, Dict())
    if !create
        HDF5.h5open(file_path, "r") do file
            store.file = file
            _cache_metadata!(store)
        end
    end

    return store
end

_get_root(store::HdfSimulationStore) = store.file[HDF_SIMULATION_ROOT_PATH]
_get_optimizer_stats_path(store::HdfSimulationStore) = store.file[HDF_OPTIMIZER_STATS_PATH]

function _cache_metadata!(store::HdfSimulationStore)
    empty!(store.metadata_cache)
    store.metadata_cache["per_stage_metadata"] = Dict()

    stages = store.file["simulation/stages"]
    for key in ("order", "step_resolution_ms")
        store.metadata_cache[key] = HDF5.read(HDF5.attrs(stages)[key])
    end

    for stage_name in names(store.file["simulation/stages"])
        store.metadata_cache["per_stage_metadata"][stage_name] = Dict{String, Any}()
        stage_group = store.file["simulation/stages/$stage_name"]
        for attr in names(HDF5.attrs(stage_group))
            store.metadata_cache["per_stage_metadata"][stage_name][attr] = HDF5.read(HDF5.attrs(stage_group)[attr])
        end
    end

    @debug "Rebuilt metadata_cache" store
end

function is_open(store::HdfSimulationStore)
    if isnothing(store.file)
        return false
    end
    return HDF5.isopen(store.file)
end

function Base.open(store::HdfSimulationStore, file_mode::AbstractString)
    store.file = HDF5.h5open(store.file_path, file_mode)
    @debug "Opened store" store.file_path, file_mode
end

function Base.flush(store::HdfSimulationStore)
    # TODO DT: probably not valid
    HDF5.h5flush(store.file_path)
    @debug "Flush store" store.file_path
end

function Base.close(store::HdfSimulationStore)
    HDF5.close(store.file)
    @debug "Close store" store.file_path
end

function _get_dataset(store::HdfSimulationStore, stage_name, dataset_type, name)
    return store.file["simulation/stages/$stage_name/$dataset_type/$name"]
end

function _get_stage_group(store::HdfSimulationStore, stage_name)
    return store.file["simulation/stages/$stage_name"]
end

function _get_group_or_create(parent, group_name)
    if HDF5.exists(parent, group_name)
        group = parent[group_name]
    else
        group = HDF5.g_create(parent, group_name)
        @debug "Created group" group
    end

    return group
end

function initialize_stage_storage!(store::HdfSimulationStore, requirements::Dict)
    root = store.file["simulation"]
    stages_group = _get_group_or_create(root, "stages")

    per_stage = requirements["per_stage_data"]
    _initialize_dual_storage!(store, stages_group, per_stage[DATASET_TYPE_DUALS])
    _initialize_parameter_storage!(store, stages_group, per_stage[DATASET_TYPE_PARAMETERS])
    _initialize_variable_storage!(store, stages_group, per_stage[DATASET_TYPE_VARIABLES])

    # This has to run after stage groups are created.
    _initialize_metadata!(store, stages_group, requirements)
end

function _initialize_metadata!(store::HdfSimulationStore, stages_group, requirements)
    for key in ("order", "step_resolution_ms")
        HDF5.attrs(store.file["simulation/stages"])[key] = requirements[key]
    end

    for stage_name in requirements["order"]
        for (key, val) in requirements["per_stage_metadata"]
            HDF5.attrs(store.file["simulation/stages/$stage_name"])[key] = val[stage_name]
        end
    end
end

function _initialize_dual_storage!(store::HdfSimulationStore, stages_group, dual_requirements)
    for (stage, dual_reqs) in dual_requirements
        group = _get_group_or_create(stages_group, stage)
        dual_group = _get_group_or_create(group, DATASET_TYPE_DUALS)
        for (dual_name, _dual_reqs) in dual_reqs
            num_rows = _dual_reqs["num_rows"]
            num_columns = length(_dual_reqs["columns"])
            dataset = HDF5.d_create(
                dual_group,
                string(dual_name),
                HDF5.datatype(Float64),
                HDF5.dataspace((num_rows, num_columns)),
            )
            HDF5.attrs(dataset)["columns"] = _dual_reqs["columns"]
            @debug "Created dataset for dual" dual_name dataset
        end
    end
end

function _initialize_parameter_storage!(store::HdfSimulationStore, stages_group, parameter_requirements)
    # TODO DT: if behavior is the same then there is room for removing the duplication
    # between this and _initialize_variable_storage!
    for (stage, param_reqs) in parameter_requirements
        group = _get_group_or_create(stages_group, stage)
        param_group = _get_group_or_create(group, DATASET_TYPE_PARAMETERS)
        for (parameter_name, _param_reqs) in param_reqs
            num_rows = _param_reqs["num_rows"]
            num_columns = length(_param_reqs["columns"])
            dataset = HDF5.d_create(
                param_group,
                string(parameter_name),
                HDF5.datatype(Float64),
                HDF5.dataspace((num_rows, num_columns)),
            )
            HDF5.attrs(dataset)["columns"] = _param_reqs["columns"]
            @debug "Created dataset for parameter" parameter_name dataset
        end
    end
end

function _initialize_variable_storage!(store::HdfSimulationStore, stages_group, variable_requirements)
    for (stage, var_reqs) in variable_requirements
        group = _get_group_or_create(stages_group, stage)
        var_group = _get_group_or_create(group, DATASET_TYPE_VARIABLES)
        for (variable_name, _var_reqs) in var_reqs
            num_rows = _var_reqs["num_rows"]
            num_columns = length(_var_reqs["columns"])
            dataset = HDF5.d_create(
                var_group,
                string(variable_name),
                HDF5.datatype(Float64),
                HDF5.dataspace((num_rows, num_columns)),
                # We are choosing to optimize read performance in the first implementation.
                # Compression would slow that down.
                #"chunk",
                #(compute_chunk_count(num_rows, num_columns, Float64), num_columns),
                #"shuffle",
                #(),
                #"deflate",
                #4,
            )
            HDF5.attrs(dataset)["columns"] = _var_reqs["columns"]
            @debug "Created dataset for variable" variable_name dataset
        end
    end
end

function append_model_results!(store::HdfSimulationStore, simulation_step, time_step, stage)
    duals = Dict()
    if is_milp(stage.internal.psi_container)
        @warn("Stage $(stage.internal.number) is a MILP, duals can't be exported")
    else
        _append_duals!(store, simulation_step, stage)
    end

    _append_parameters!(store, simulation_step, stage)
    _append_variables!(store, simulation_step, stage)
    #write_data(get_time_stamps(stage, start_time), save_path, "time_stamp")
    return
end

function _append_duals!(store::HdfSimulationStore, simulation_step, stage)
    execution_count = get_execution_count(stage)
    executions = get_executions(stage)
    horizon = get_horizon(get_settings(stage))
    stage_name = get_name(stage)
    psi_container = get_psi_container(stage)
    for name in get_constraint_duals(psi_container.settings)
        array = get_constraint(psi_container, name)
        @assert length(axes(array)) == 1
        dataset = _get_dataset(store, stage_name, DATASET_TYPE_DUALS, name)
        row_index = (simulation_step - 1) * executions * horizon + execution_count * horizon + 1
        @assert row_index <= size(dataset)[1]
        end_row_index = row_index + horizon - 1
        data = [_jump_value(array[x]) for x in array.axes[1]]
        TimerOutputs.@timeit RUN_SIMULATION_TIMER "Write dual DenseAxisArray" begin
            dataset[row_index:end_row_index, :] = data
        end
    end
end

function _append_parameters!(store::HdfSimulationStore, simulation_step, stage)
    psi_container = get_psi_container(stage)
    parameters = get_parameters(psi_container)
    (isnothing(parameters) || isempty(parameters)) && return

    execution_count = get_execution_count(stage)
    executions = get_executions(stage)
    horizon = get_horizon(get_settings(stage))
    stage_name = get_name(stage)
    for (name, container) in parameters
        !isa(container.update_ref, UpdateRef{<:PSY.Component}) && continue
        dataset = _get_dataset(store, stage_name, DATASET_TYPE_PARAMETERS, name)
        row_index = (simulation_step - 1) * executions * horizon + execution_count * horizon + 1
        @assert row_index <= size(dataset)[1]
        end_row_index = row_index + horizon - 1
        num_columns = size(dataset)[2]
        param_array = get_parameter_array(container)
        multiplier_array = get_multiplier_array(container)
        data = Array{Float64}(undef, horizon, num_columns)
        @assert length(axes(param_array)) == 2
        for r_ix in param_array.axes[2], (c_ix, name) in enumerate(param_array.axes[1])
            val1 = _jump_value(param_array[name, r_ix])
            val2 = multiplier_array[name, r_ix]
            data[r_ix, c_ix] = _jump_value(param_array[name, r_ix]) * (multiplier_array[name, r_ix])
        end

        TimerOutputs.@timeit RUN_SIMULATION_TIMER "Write parameter DenseAxisArray" begin
            dataset[row_index:end_row_index, :] = data
        end
    end
end

function _append_variables!(store::HdfSimulationStore, simulation_step, stage)
    execution_count = get_execution_count(stage)
    executions = get_executions(stage)
    horizon = get_horizon(get_settings(stage))
    stage_name = get_name(stage)
    psi_container = get_psi_container(stage)
    for (name, array) in get_variables(psi_container)
        dataset = _get_dataset(store, stage_name, DATASET_TYPE_VARIABLES, name)
        row_index = (simulation_step - 1) * executions * horizon + execution_count * horizon + 1
        @assert row_index <= size(dataset)[1]
        end_row_index = row_index + horizon - 1
        num_columns = size(dataset)[2]
        data = Array{Float64}(undef, horizon, num_columns)
        @assert length(axes(array)) == 2
        for r_ix in array.axes[2], (c_ix, name) in enumerate(array.axes[1])
            data[r_ix, c_ix] = _jump_value(array[name, r_ix])
        end

        TimerOutputs.@timeit RUN_SIMULATION_TIMER "Write variable DenseAxisArray" begin
            dataset[row_index:end_row_index, :] = data
        end
    end
end

"""
Return variable DenseAxisArray for a horizon at an execution count.
"""
function read_value(store::HdfSimulationStore, type, name, simulation_step, stage_name, execution_count)
    if !(type in DATASET_TYPES)
        throw(ArgumentError("unsupported value type: $type"))
    end

    opened = false
    if !is_open(store)
        open(store, "r")
        opened = true
    end

    try
        # TODO DT: if this is called repeatedly in a high-performance path then we need to
        # remove string interpolations.
        stage_group = _get_stage_group(store, stage_name)
        horizon = store.metadata_cache["per_stage_metadata"][stage_name]["horizons"]
        executions = store.metadata_cache["per_stage_metadata"][stage_name]["executions"]
        dataset = _get_dataset(store, stage_name, type, name)
        row_index = (simulation_step - 1) * executions * horizon + execution_count * horizon + 1
        end_row_index = row_index + horizon - 1
        columns = HDF5.read(HDF5.attrs(dataset)["columns"])
        TimerOutputs.@timeit RUN_SIMULATION_TIMER "Read value DenseAxisArray" begin
            data = dataset[row_index:end_row_index, :]
        end
        return JuMP.Containers.DenseAxisArray(data, 1:horizon, columns)
    finally
        opened && close(store)
    end
end

#=
# API options for read_value:
#  Questions: do we always have a Stage object?  If no, write metata as attributes.
#   1. Return value for component at timestamp/time_step at an execution_count/timestamp
#   2. Return DenseAxisArray at timestamp/time_step at an execution_count/timestamp
#   3. Return array for component at at timestamp/time_step at an execution_count/timestamp
#   4. ?
=#

function initialize_optimizer_stats_storage!(store::HdfSimulationStore, num_stats::Int)
    root = store.file["simulation"]
    group = _get_group_or_create(root, "optimizer_stats")

    num_columns = length(fieldnames(PSI.OptimizerStats))
    dataset = HDF5.d_create(
        group,
        "data",
        HDF5.datatype(Float64),
        HDF5.dataspace((num_stats, num_columns)),
    )

    HDF5.attrs(dataset)["columns"] = get_column_names(OptimizerStats)
    @debug "Created dataset for optimizer stats" dataset size(dataset)
    store.optimizer_stats_index = 1
end

function append_optimizer_stats!(store::HdfSimulationStore, stats::OptimizerStats)
    @assert HDF5.isopen(store.file)
    @assert store.optimizer_stats_index > 0
    dataset = store.file["simulation/optimizer_stats/data"]
    @assert store.optimizer_stats_index <= size(dataset)[1] "$(store.optimizer_stats_index) $(size(dataset))"

    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Write optimizer stats" begin
        dataset[store.optimizer_stats_index, :] = to_array(stats)
    end

    store.optimizer_stats_index += 1
    return
end

function _get_dataset(::Type{OptimizerStats}, store::HdfSimulationStore)
    return store.file["simulation/optimizer_stats/data"]
end

function read_optimizer_stats(store::HdfSimulationStore)
    dataset = _get_dataset(OptimizerStats, store)
    len = _read_length(OptimizerStats, store)
    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Read optimizer stats" begin
        stats = dataset[1:len, :]
        columns = _read_column_names(OptimizerStats, store)
    end
    return from_array(OptimizerStats, stats, columns)
end

function _read_column_names(::Type{OptimizerStats}, store::HdfSimulationStore)
    dataset = _get_dataset(OptimizerStats, store)
    return HDF5.read(HDF5.attrs(dataset), "columns")
end

function _read_length(::Type{OptimizerStats}, store::HdfSimulationStore)
    dataset = _get_dataset(OptimizerStats, store)
    return HDF5.read(HDF5.attrs(dataset), "columns")
end

function compute_chunk_count(num_rows, num_columns, dtype; max_chunk_bytes = DEFAULT_MAX_CHUNK_BYTES)
    # Is there a library function for this?
    num_bytes = 0
    if dtype == Float64
        num_bytes = 8
    elseif dtype == Float32
        num_bytes = 4
    elseif dtype == Int64
        num_bytes = 8
    elseif dtype == Int32
        num_bytes = 4
    else
        error("unsupported dtype=$dtype")
    end

    size_row = num_bytes * num_columns
    chunk_count = minimum((trunc(max_chunk_bytes / size_row), num_rows))
    if chunk_count == 0
        error("HDF Max Chunk Bytes is smaller than the size of a row. Please increase it. " *
              "max_chunk_bytes=$max_chunk_bytes num_columns=$num_columns " *
              "size_row=$size_row"
        )
    end

    return chunk_count
end
