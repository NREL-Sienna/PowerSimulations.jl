"""
Defines how a simulation can be partition into partitions and run in parallel.
"""
struct SimulationPartitions <: IS.InfrastructureSystemsType
    "Number of steps in the simulation"
    num_steps::Int
    "Number of steps in each partition"
    period::Int
    "Number of steps that a partition overlaps with the previous partition"
    num_overlap_steps::Int

    function SimulationPartitions(num_steps, period, num_overlap_steps=1)
        if num_overlap_steps > period
            error(
                "period=$period must be greater than num_overlap_steps=$num_overlap_steps",
            )
        end
        if period >= num_steps
            error("period=$period must be less than simulation steps=$num_steps")
        end
        return new(num_steps, period, num_overlap_steps)
    end
end

function SimulationPartitions(; num_steps, period, num_overlap_steps)
    return SimulationPartitions(num_steps, period, num_overlap_steps)
end

"""
Return the number of partitions in the simulation.
"""
get_num_partitions(x::SimulationPartitions) = Int(ceil(x.num_steps / x.period))

"""
Return a UnitRange for the steps in the partition with the given index. Includes overlap.
"""
function get_absolute_step_range(partitions::SimulationPartitions, index::Int)
    num_partitions = _check_partition_index(partitions, index)
    start_index = partitions.period * (index - 1) + 1
    if index < num_partitions
        end_index = start_index + partitions.period - 1
    else
        end_index = partitions.num_steps
    end

    if index > 1
        start_index -= partitions.num_overlap_steps
    end

    return start_index:end_index
end

"""
Return the step offset for valid data at the given index.
"""
function get_valid_step_offset(partitions::SimulationPartitions, index::Int)
    _check_partition_index(partitions, index)
    return index == 1 ? 1 : partitions.num_overlap_steps + 1
end

"""
Return the length of valid data at the given index.
"""
function get_valid_step_length(partitions::SimulationPartitions, index::Int)
    num_partitions = _check_partition_index(partitions, index)
    if index < num_partitions
        return partitions.period
    end

    remainder = partitions.num_steps % partitions.period
    return remainder == 0 ? partitions.period : remainder
end

function _check_partition_index(partitions::SimulationPartitions, index::Int)
    num_partitions = get_num_partitions(partitions)
    if index <= 0 || index > num_partitions
        error("index=$index=inde must be > 0 and <= $num_partitions")
    end

    return num_partitions
end

function IS.serialize(partitions::SimulationPartitions)
    return IS.serialize_struct(partitions)
end

function process_simulation_partition_cli_args(build_function, execute_function, args...)
    length(args) < 2 && error("Usage: setup|execute|join [options]")
    function config_logging(filename)
        return IS.configure_logging(
            console=true,
            console_stream=stderr,
            console_level=Logging.Warn,
            file=true,
            filename=filename,
            file_level=Logging.Info,
            file_mode="w",
            tracker=nothing,
            set_global=true,
        )
    end

    function throw_if_missing(actual, required, label)
        diff = setdiff(required, actual)
        !isempty(diff) && error("Missing required options for $label: $diff")
    end

    operation = args[1]
    options = Dict{String, String}()
    for opt in args[2:end]
        !startswith(opt, "--") && error("All options must start with '--': $opt")
        fields = split(opt[3:end], "=")
        length(fields) != 2 && error("All options must use the format --name=value: $opt")
        options[fields[1]] = fields[2]
    end

    if haskey(options, "output-dir")
        output_dir = options["output-dir"]
    elseif haskey(ENV, "JADE_RUNTIME_OUTPUT")
        output_dir = joinpath(ENV["JADE_RUNTIME_OUTPUT"], "job-outputs")
    else
        error("output-dir must be specified as a CLI option or environment variable")
    end

    if operation == "setup"
        required = Set(("simulation-name", "num-steps", "num-period-steps"))
        throw_if_missing(keys(options), required, operation)
        if !haskey(options, "num-overlap-steps")
            options["num-overlap-steps"] = "0"
        end

        num_steps = parse(Int, options["num-steps"])
        num_period_steps = parse(Int, options["num-period-steps"])
        num_overlap_steps = parse(Int, options["num-overlap-steps"])
        partitions = SimulationPartitions(num_steps, num_period_steps, num_overlap_steps)
        config_logging(joinpath(output_dir, "setup_partition_simulation.log"))
        build_function(output_dir, options["simulation-name"], partitions)
    elseif operation == "execute"
        throw_if_missing(keys(options), Set(("simulation-name", "index")), operation)
        index = parse(Int, options["index"])
        base_dir = joinpath(output_dir, options["simulation-name"])
        partition_output_dir = joinpath(base_dir, "simulation_partitions", string(index))
        config_file = joinpath(base_dir, "simulation_partitions", "config.json")
        config = open(config_file, "r") do io
            JSON3.read(io, Dict)
        end
        partitions = IS.deserialize(SimulationPartitions, config)
        config_logging(joinpath(partition_output_dir, "run_partition_simulation.log"))
        sim = build_function(
            partition_output_dir,
            options["simulation-name"],
            partitions,
            index,
        )
        execute_function(sim)
    elseif operation == "join"
        throw_if_missing(keys(options), Set(("simulation-name",)), operation)
        base_dir = joinpath(output_dir, options["simulation-name"])
        config_file = joinpath(base_dir, "simulation_partitions", "config.json")
        config = open(config_file, "r") do io
            JSON3.read(io, Dict)
        end
        partitions = IS.deserialize(SimulationPartitions, config)
        config_logging(joinpath(base_dir, "logs", "join_partitioned_simulation.log"))
        join_simulation(base_dir)
    else
        error("Unsupported operation=$operation")
    end

    return
end

"""
Run a partitioned simulation in parallel on a local computer.

# Arguments

  - `build_function`: Function reference that returns a built Simulation.
  - `execute_function`: Function reference that executes a Simulation.
  - `script::AbstractString`: Path to script that includes ``build_function`` and ``execute_function``.
  - `output_dir::AbstractString`: Path for simulation outputs
  - `name::AbstractString`: Simulation name
  - `num_steps::Integer`: Total number of steps in the simulation
  - `period::Integer`: Number of steps in each simulation partition
  - `num_overlap_steps::Integer`: Number of steps that each partition overlaps with the previous partition
  - `num_parallel_processes`: Number of partitions to run in parallel. If nothing, use the number of cores.
  - `exeflags`: Path to Julia project. Forwarded to Distributed.addprocs.
  - `force`: Overwrite the output directory if it already exists.
"""
function run_parallel_simulation(
    build_function,
    execute_function;
    script::AbstractString,
    output_dir::AbstractString,
    name::AbstractString,
    num_steps::Integer,
    period::Integer,
    num_overlap_steps::Integer=1,
    num_parallel_processes=nothing,
    exeflags=nothing,
    force=false,
)
    if isnothing(num_parallel_processes)
        num_parallel_processes = Sys.CPU_THREADS
    end

    partitions = SimulationPartitions(num_steps, period, num_overlap_steps)
    num_partitions = get_num_partitions(partitions)
    if isdir(output_dir)
        if !force
            error(
                "output_dir=$output_dir already exists. Choose a different name or set force=true.",
            )
        end
        rm(output_dir, recursive=true)
    end
    mkdir(output_dir)
    @info "Run parallel simulation" name script output_dir num_steps num_partitions num_parallel_processes

    args = [
        "setup",
        "--simulation-name=$name",
        "--num-steps=$(partitions.num_steps)",
        "--num-period-steps=$(partitions.period)",
        "--num-overlap-steps=$(partitions.num_overlap_steps)",
        "--output-dir=$output_dir",
    ]
    parent_module_name = nameof(parentmodule(build_function))
    build_func_name = nameof(build_function)
    execute_func_name = nameof(execute_function)
    process_simulation_partition_cli_args(build_function, execute_function, args...)
    jobs = Vector{Dict}(undef, num_partitions)
    for i in 1:num_partitions
        args = Dict(
            "parent_module" => parent_module_name,
            "build_function" => build_func_name,
            "execute_function" => execute_func_name,
            "args" => [
                "execute",
                "--simulation-name=$name",
                "--index=$i",
                "--output-dir=$output_dir",
            ],
        )
        jobs[i] = args
    end

    if isnothing(exeflags)
        Distributed.addprocs(num_parallel_processes)
    else
        Distributed.addprocs(num_parallel_processes, exeflags=exeflags)
    end

    Distributed.@everywhere include($script)
    try
        Distributed.pmap(PowerSimulations._run_parallel_simulation, jobs)
    finally
        Distributed.rmprocs(Distributed.workers()...)
    end

    args = ["join", "--simulation-name=$name", "--output-dir=$output_dir"]
    process_simulation_partition_cli_args(build_function, execute_function, args...)
end

function _run_parallel_simulation(params)
    start = time()
    if params["parent_module"] == :Main
        parent_module = Main
    else
        # TODO: not tested
        parent_module = Base.root_module(Base.__toplevel__, Symbol(params["parent_module"]))
    end
    result = process_simulation_partition_cli_args(
        getproperty(parent_module, params["build_function"]),
        getproperty(parent_module, params["execute_function"]),
        params["args"]...,
    )
    duration = time() - start
    args = params["args"]
    @info "Completed partition" args duration
    return result
end
