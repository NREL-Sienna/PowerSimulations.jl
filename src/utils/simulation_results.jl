struct SimulationResults <: IS.Results
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict
    optimizer_log::Dict
    time_stamp::DataFrames.DataFrame
    results_folder::Union{Nothing, String}
    function SimulationResults(
        variables::Dict,
        total_cost::Dict,
        optimizer_log::Dict,
        time_stamp::DataFrames.DataFrame,
    )
        new(variables, total_cost, optimizer_log, time_stamp, nothing)
    end
    function SimulationResults(
        variables::Dict,
        total_cost::Dict,
        optimizer_log::Dict,
        time_stamp::DataFrames.DataFrame,
        results_folder::String,
    )
        new(variables, total_cost, optimizer_log, time_stamp, results_folder)
    end
end

function deserialize_sim_output(file_path::String)
    path = joinpath(file_path, "output_references")
    list = setdiff(collect(readdir(path)), ["results_folder.json", "chronologies.json"])
    ref = Dict()
    for stage in list
        ref[stage] = Dict{Symbol, Any}()
        for variable in collect(readdir(joinpath(path, stage)))
            var = splitext(variable)[1]
            ref[stage][Symbol(var)] = Feather.read(joinpath(path, stage, variable))
            ref[stage][Symbol(var)][!, :Date] =
                convert(Array{Dates.DateTime}, ref[stage][Symbol(var)][!, :Date])
        end
    end
    results_folder = read_json(joinpath(path, "results_folder.json"))
    chronologies = Dict{Any, Any}(read_json(joinpath(path, "chronologies.json")))
    sim_output = SimulationResultsReference(ref, results_folder, chronologies)
    return sim_output
end

"""
    load_simulation_results(stage, step, variable, SimulationResultsReference)

This function goes through the reference table of file paths and
aggregates the results over time into a struct of type OperationsProblemResults
for the desired step range and variables

# Arguments
- `SimulationResultsReference::SimulationResultsReference`: the container for the reference dictionary created in execute!
- `stage_number::Int = 1``: The stage of the results getting parsed: 1 or 2
- `step::Array{String} = ["step-1", "step-2", "step-3"]`: the steps of the results getting parsed
- `variable::Array{Symbol} = [:P_ThermalStandard, :P_RenewableDispatch]`: the variables to be parsed

# Example
```julia
stage = "stage-1"
step = ["step-1", "step-2", "step-3"] # has to match the date range
variable = [:P_ThermalStandard, :P_RenewableDispatch]
results = load_simulation_results(stage,step, variable, SimulationResultsReference)
```
# Accepted Key Words
"""

function load_simulation_results(
    path::String,
    stage_name::String,
    step::Array,
    variable::Array;
    kwargs...,
)
    sim_results = deserialize_sim_output(path)
    load_simulation_results(sim_results, stage_name, step, variable; kwargs...)
end
function load_simulation_results(
    SimulationResultsReference::SimulationResultsReference,
    stage_name::String,
    step::Array,
    variable::Array;
    kwargs...,
)
    results_folder = SimulationResultsReference.results_folder
    stage = "stage-$stage_name"
    references = SimulationResultsReference.ref
    variables = Dict() # variable dictionary
    duals = Dict()
    time_stamp = DataFrames.DataFrame(Range = Dates.DateTime[])
    time_length = SimulationResultsReference.chronologies[stage]
    dual = _find_duals(collect(keys(references[stage])))
    variable = setdiff(variable, dual)
    for l in 1:length(variable)
        date_df = references[stage][variable[l]]
        step_df = DataFrames.DataFrame(
            Date = Dates.DateTime[],
            Step = String[],
            File_Path = String[],
        )
        for n in 1:length(step)
            step_df = vcat(step_df, date_df[date_df.Step .== step[n], :])
        end
        variables[(variable[l])] = DataFrames.DataFrame()
        for (ix, time) in enumerate(step_df.Date)
            file_path = step_df[ix, :File_Path]
            var = Feather.read("$file_path")
            variables[(variable[l])] = vcat(variables[(variable[l])], var[1:time_length, :])
            if l == 1
                time_stamp = vcat(time_stamp, _read_time(file_path, time_length))
                check_file_integrity(dirname(file_path))
            end
        end
    end
    time_stamp[!, :Range] = convert(Array{Dates.DateTime}, time_stamp[!, :Range])
    file_path = dirname(references[stage][variable[1]][1, :File_Path])
    optimizer = read_json(joinpath(file_path, "optimizer_log.json"))
    obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer["obj_value"])
    if !isempty(dual)
        duals = _read_references(duals, dual, stage, step, references, time_length)
        results =
            DualResults(variables, obj_value, optimizer, time_stamp, duals, results_folder)
    else
        results =
            SimulationResults(variables, obj_value, optimizer, time_stamp, results_folder)
    end
    return results
end

"""
    load_simulation_results(file_path, stage)

This function goes through the reference table of file paths and
aggregates the results over time into a struct of type OperationsProblemResults

# Arguments
- `file_path::String`: the file path to the dated folder with the raw results
- `stage_number::String`: The stage of the results getting parsed

# Example
```julia
execute!(simulation)
results = load_simulation_results("file_path", "stage_name")
```
# Accepted Key Words
"""
function load_simulation_results(path::String, stage_name::String, kwargs...)
    sim_results = deserialize_sim_output(path)
    load_simulation_results(sim_results, stage_name; kwargs...)
end
"""
    load_simulation_results(SimulationResultsReference, stage)

This function goes through the reference table of file paths and
aggregates the results over time into a struct of type OperationsProblemResults

# Arguments
- `SimulationResultsReference::SimulationResultsReference`: the container for the reference dictionary created in execute!
- `stage_number::String`: The stage of the results getting parsed

# Example
```julia
sim_output = execute!(simulation)
results = load_simulation_results(sim_output, "stage_name")
```
# Accepted Key Words
"""
function load_simulation_results(
    sim_output::SimulationResultsReference,
    stage_name::String;
    kwargs...,
)
    results_folder = sim_output.results_folder
    stage = "stage-$stage_name"
    references = sim_output.ref
    variables = Dict()
    duals = Dict()
    variable = (collect(keys(references[stage])))
    dual = _find_duals(variable)
    variable = setdiff(variable, dual)
    time_stamp = DataFrames.DataFrame(Range = Dates.DateTime[])
    time_length = sim_output.chronologies[stage]

    for l in 1:length(variable)
        date_df = references[stage][variable[l]]
        variables[(variable[l])] = DataFrames.DataFrame()
        for (ix, time) in enumerate(date_df.Date)
            file_path = date_df[ix, :File_Path]
            var = Feather.read(file_path)
            variables[(variable[l])] = vcat(variables[(variable[l])], var[1:time_length, :])
            if l == 1
                time_stamp = vcat(time_stamp, _read_time(file_path, time_length))
                check_file_integrity(dirname(file_path))
            end
        end
    end
    time_stamp[!, :Range] = convert(Array{Dates.DateTime}, time_stamp[!, :Range])
    file_path = dirname(references[stage][variable[1]][1, :File_Path])
    optimizer = read_json(joinpath(file_path, "optimizer_log.json"))
    obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer["obj_value"])
    if !isempty(dual)
        duals = _read_references(duals, dual, stage, references, time_length)
        results =
            DualResults(variables, obj_value, optimizer, time_stamp, duals, results_folder)
    else
        results =
            SimulationResults(variables, obj_value, optimizer, time_stamp, results_folder)
    end
    return results
end
"""
    check_file_integrity(path::String)

Checks the hash value for each file made with the file is written with the new hash_value to verify the file hasn't been tampered with since written

# Arguments
- `path::String`: this is the folder path that contains the results and the check.sha256 file
"""
function check_file_integrity(path::String)
    file_path = joinpath(path, "check.sha256")
    text = open(file_path, "r") do io
        return readlines(io)
    end

    matched = true
    for line in text
        expected_hash, file_name = split(line)
        actual_hash = compute_sha256(file_name)
        if expected_hash != actual_hash
            @error "hash mismatch for file" file_name expected_hash actual_hash
            matched = false
        end
    end

    if !matched
        throw(IS.HashMismatchError("The hash value in the written files does not match the read files, results may have been tampered."))
    end
end

function get_variable_names(sim::Simulation, stage::Any)
    return get_variable_names(sim.stages[stage].internal.psi_container)
end

function get_reference(
    sim_results::SimulationResultsReference,
    stage::String,
    step::Int,
    variable::Symbol,
)
    file_paths = sim_results.ref["stage-$stage"][variable]
    return filter(file_paths -> file_paths.Step == "step-$step", file_paths)[:, :File_Path]
end

get_psi_container(sim::Simulation, stage::Any) = sim.stages[stage].internal.psi_container
