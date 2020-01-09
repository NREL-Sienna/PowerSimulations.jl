struct SimulationResults <: Results
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict
    optimizer_log::Dict
    time_stamp::DataFrames.DataFrame
    function SimulationResults(variables::Dict,
                      total_cost::Dict,
                      optimizer_log::Dict,
                      time_stamp::DataFrames.DataFrame)
        results = OperationsProblemResults(variables, total_cost, optimizer_log, time_stamp)
        new(variables, total_cost, optimizer_log, time_stamp)
    end

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
- `write::Bool`: if true, the aggregated results get written back to the results file in the folder structure
"""
function load_simulation_results(SimulationResultsReference::SimulationResultsReference,
                                 stage_name::String,
                                 step::Array,
                                 variable::Array; kwargs...)
    stage = "stage-$stage_name"
    references = SimulationResultsReference.ref
    variables = Dict() # variable dictionary
    duals = Dict()
    time_stamp = DataFrames.DataFrame(Range = Dates.DateTime[])
    time_length = SimulationResultsReference.chronologies[stage]
    dual = _find_duals(collect(keys(references[stage])))

    for l in 1:length(variable)
        date_df = references[stage][variable[l]]
        step_df = DataFrames.DataFrame(Date = Dates.DateTime[], Step = String[], File_Path = String[])
        for n in 1:length(step)
            step_df = vcat(step_df, date_df[date_df.Step .== step[n], :])
        end
        variables[(variable[l])] = DataFrames.DataFrame()
        for (ix,time) in enumerate(step_df.Date)
            file_path = step_df[ix, :File_Path]
            var = Feather.read("$file_path")
            variables[(variable[l])] = vcat(variables[(variable[l])],var[1:time_length,:])
            if l == 1
                time_stamp = vcat(time_stamp, _reading_time(file_path, time_length))
                check_file_integrity(dirname(file_path))
            end
        end
    end
    time_stamp[!,:Range] = convert(Array{Dates.DateTime}, time_stamp[!,:Range])
    file_path = dirname(references[stage][variable[1]][1,:File_Path])
    optimizer = read_json(joinpath(file_path, "optimizer_log.json"))
    obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer["obj_value"])
    if !isempty(dual)
        duals = _reading_references(duals, dual, stage, step, references, time_length)
        results = DualResults(variables, obj_value, optimizer, time_stamp, duals)
    else
        results = SimulationResults(variables, obj_value, optimizer, time_stamp)
    end
    file_type = get(kwargs, :file_type, Feather)
    write = get(kwargs, :write, false)
    if write == true || :file_type in keys(kwargs)
        write_results(results, SimulationResultsReference.results_folder, "results"; file_type = file_type)
    end
    return results
end

"""
    load_simulation_results(stage, SimulationResultsReference)

This function goes through the reference table of file paths and
aggregates the results over time into a struct of type OperationsProblemResults

# Arguments
- `SimulationResultsReference::SimulationResultsReference`: the container for the reference dictionary created in execute!
- `stage_number::Int = 1`: The stage of the results getting parsed: 1 or 2

# Example
```julia
stage = 2
step = ["step-1", "step-2", "step-3"] # has to match the date range
variable = [:P_ThermalStandard, :P_RenewableDispatch]
results = load_simulation_results(stage, step, variable, SimulationResultsReference)
```
# Accepted Key Words
- `write::Bool`: if true, the aggregated results get written back to the results file in the folder structure
"""

function load_simulation_results(SimulationResultsReference::SimulationResultsReference, stage_name::String; kwargs...)
    stage = "stage-$stage_name"
    references = SimulationResultsReference.ref
    variables = Dict()
    duals = Dict()
    variable = (collect(keys(references[stage])))
    dual = _find_duals(variable)
    variable = setdiff(variable, duals)
    time_stamp = DataFrames.DataFrame(Range = Dates.DateTime[])
    time_length = SimulationResultsReference.chronologies[stage]

    for l in 1:length(variable)
        date_df = references[stage][variable[l]]
        variables[(variable[l])] = DataFrames.DataFrame()
        for (ix,time) in enumerate(date_df.Date)
            file_path = date_df[ix, :File_Path]
            var = Feather.read(file_path)
            variables[(variable[l])] = vcat(variables[(variable[l])],var[1:time_length,:])
            if l == 1
                time_stamp = vcat(time_stamp, _reading_time(file_path, time_length))
                check_file_integrity(dirname(file_path))
            end
        end
    end
    time_stamp[!,:Range] = convert(Array{Dates.DateTime}, time_stamp[!,:Range])
    file_path = dirname(references[stage][variable[1]][1,:File_Path])
    optimizer = read_json(joinpath(file_path, "optimizer_log.json"))
    obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer["obj_value"])
    if !isempty(dual)
        duals = _reading_references(duals, dual, stage, references, time_length)
        results = DualResults(variables, obj_value, optimizer, time_stamp, duals)
    else
        results = SimulationResults(variables, obj_value, optimizer, time_stamp)
    end
    file_type = get(kwargs, :file_type, Feather)
    write = get(kwargs, :write, false)
    if write == true
        write_results(results, SimulationResultsReference.results_folder, "results")
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
        throw(IS.HashMismatchError(
            "The hash value in the written files does not match the read files, results may have been tampered."
        ))
    end
end

function get_variable_names(sim::Simulation, stage::Any)
     return collect(keys(sim.stages[stage].internal.psi_container.variables))
end

function get_reference(sim_results::SimulationResultsReference, stage::String, step::Int, variable::Symbol) 
     file_paths = sim_results.ref["stage-$stage"][variable]
     return filter(file_paths -> file_paths.Step == "step-$step", file_paths)[:, :File_Path]
end

get_psi_container(sim::Simulation, stage::Any) = sim.stages[stage].internal.psi_container
