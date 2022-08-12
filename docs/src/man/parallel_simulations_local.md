## Run a Simulation in Parallel on a local computer

This page describes how to split a simulation into partitions, run each partition in parallel,
and then join the results.

### Setup

Create a Julia script to build and run simulations. It must meet the requirements below.
A full example is in the PowerSimulations repository in `test/run_partitioned_simulation.jl`.

- Call `using PowerSimulations`.

- Implement a build function that matches the signature below.
  It must construct a `Simulation`, call `build!`, and then return the `Simulation` instance.
  It must throw an exception if the build fails.

```
function build_simulation(
    output_dir::AbstractString,
    simulation_name::AbstractString,
    partitions::SimulationPartitions,
    index::Union{Nothing, Integer}=nothing,
)
```

Here is example code to construct the `Simulation` with these parameters:

```
    sim = Simulation(
        name=simulation_name,
        steps=partitions.num_steps,
        models=models,
        sequence=sequence,
        simulation_folder=output_dir,
    )
    status = build!(sim; partitions=partitions, index=index, serialize=isnothing(index))
    if status != PSI.BuildStatus.BUILT
        error("Failed to build simulation: status=$status")
    end
```

- Implement an execute function that matches the signature below. It must throw an exception
  if the execute fails.

```
function execute_simulation(sim, args...; kwargs...)
    status = execute!(sim)
    if status != PSI.RunStatus.SUCCESSFUL
        error("Simulation failed to execute: status=$status")
    end
end
```

### Execution

After loading your script, call the function `run_parallel_simulation` as shown below.

This example splits a year-long simulation into weekly partitions for a total of 53 individual
jobs and then runs them four at a time.

```
julia> include("my_simulation.jl")
julia> run_parallel_simulation(
        build_simulation,
        execute_simulation,
        script="my_simulation.jl",
        output_dir="my_simulation_output",
        name="my_simulation",
        num_steps=365,
        period=7,
        num_overlap_steps=1,
        num_parallel_processes=4,
        exeflags="--project=<path-to-your-julia-environment>",
    )
```

The final results will be in `./my_simulation_otuput/my_simulation`

Note the log files and results for each partition are located in
`./my_simulation_otuput/my_simulation/simulation_partitions`
