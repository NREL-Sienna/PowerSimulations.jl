struct SimulationResultsReference
    ref::Dict
    results_folder::String
    chronologies::Dict
    base_powers::Dict
end

function SimulationResultsReference(sim::Simulation; kwargs...)
    date_run = convert(String, last(split(dirname(sim.internal.raw_dir), "/")))
    ref = make_references(sim, date_run; kwargs...)
    chronologies = Dict()
    base_powers = Dict()
    for (stage_number, stage_name) in sim.sequence.order
        stage = get_stage(sim, stage_name)
        interval = get_stage_interval(sim, stage_name)
        resolution = PSY.get_forecasts_resolution(get_sys(stage))
        chronologies["stage-$stage_name"] = convert(Int, (interval / resolution))
        base_powers[stage_name] = PSY.get_basepower(sim.stages[stage_name].sys)
    end
    return SimulationResultsReference(
        ref,
        sim.internal.results_dir,
        chronologies,
        base_powers,
    )
end

# internal function for differentiating variables from duals in file names
function _concat_dual(duals::Vector{Symbol})
    dual = []
    for d in duals
        dual = vcat(dual, "dual_" * String(d))
    end
    return dual
end

# internal function for differentiating variables from parameters in file names
function _concat_param(params::Vector{Symbol})
    param = []
    for p in params
        param = vcat(param, "parameter_" * String(p))
    end
    return param
end

"""
    make_references(sim::Simulation, date_run::String; kwargs...)

Creates a dictionary of variables with a dictionary of stages
that contains dataframes of date/step/and desired file path
so that the results can be parsed sequentially by variable
and stage type.

**Note:** make_references can only be run after run_sim_model
or else, the folder structure will not yet be populated with results

# Arguments
- `sim::Simulation = sim`: simulation object created by Simulation()
- `date_run::String = "2019-10-03T09-18-00"``: the name of the file created
that contains the specific simulation run of the date run and "-test"

# Example
```julia
sim = Simulation("Test", 7, stages, "/Users/yourusername/Desktop/"; system_to_file = false)
execute!(sim::Simulation; kwargs...)
references = make_references(sim, "2019-10-03T09-18-00-test")
```
"""
function make_references(sim::Simulation, date_run::String)
    sim.internal.date_ref[1] = sim.initial_time
    sim.internal.date_ref[2] = sim.initial_time
    references = Dict()
    for (stage_number, stage_name) in sim.sequence.order
        stage = sim.stages[stage_name]
        references["stage-$stage_name"] = make_result_reference(stage, sim)
    end
    return references
end

function make_result_reference(
    stage::Stage{T},
    sim::Simulation,
) where {T <: PowerSimulationsOperationsProblem}
    stage_number = get_number(stage)
    stage_name = get_stage_name(sim, stage)
    stage_container = get_psi_container(stage)
    variables = Dict{Symbol, Any}()
    interval = get_stage_interval(sim, stage_name)
    variable_names = (collect(keys(stage_container.variables)))
    if !is_milp(get_psi_container(stage))
        constraint_duals = get_constraint_duals(stage_container.settings)
        constraint_duals_names = Symbol.(_concat_dual(constraint_duals))
        variable_names = vcat(variable_names, constraint_duals_names)
    end
    params = collect(keys(get_parameters_value(get_psi_container(stage))))
    param_keys = Symbol.(_concat_param(params))
    variable_names = vcat(variable_names, param_keys)
    for name in variable_names
        variables[name] = DataFrames.DataFrame(
            Date = Dates.DateTime[],
            Step = String[],
            File_Path = String[],
        )
    end
    for s in 1:(sim.steps)
        for run in 1:(stage.internal.executions)
            sim.internal.current_time = sim.internal.date_ref[stage_number]
            for name in variable_names
                full_path = joinpath(
                    sim.internal.raw_dir,
                    "step-$(s)-stage-$(stage_name)",
                    replace_chars("$(sim.internal.current_time)", ":", "-"),
                    "$(name).feather",
                )
                if isfile(full_path)
                    date_df = DataFrames.DataFrame(
                        Date = sim.internal.current_time,
                        Step = "step-$(s)",
                        File_Path = full_path,
                    )
                    variables[name] = vcat(variables[name], date_df)
                else
                    @error "$full_path, does not contain any simulation result raw data"
                end
            end
            sim.internal.run_count[s][stage_number] += 1
            sim.internal.date_ref[stage_number] =
                sim.internal.date_ref[stage_number] + interval
        end
    end
    return variables
end

make_result_reference(stage::Stage{T}, sim::Simulation) where {T} = nothing

struct SimulationResults <: IS.Results
    base_power::Float64
    variable_values::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict
    optimizer_log::Dict
    time_stamp::DataFrames.DataFrame
    dual_values::Dict{Symbol, Any}
    results_folder::Union{Nothing, String}
    parameter_values::Dict{Symbol, DataFrames.DataFrame}
end

IS.get_base_power(result::SimulationResults) = result.base_power
IS.get_variables(result::SimulationResults) = result.variable_values
IS.get_total_cost(result::SimulationResults) = result.total_cost
IS.get_optimizer_log(results::SimulationResults) = results.optimizer_log
IS.get_time_stamp(result::SimulationResults) = result.time_stamp
get_duals(result::SimulationResults) = result.dual_values
IS.get_parameters(result::SimulationResults) = result.parameter_values

function deserialize_sim_output(file_path::String)
    path = joinpath(file_path, "output_references")
    list = setdiff(
        collect(readdir(path)),
        ["results_folder.json", "chronologies.json", "base_power.json"],
    )
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
    base_powers = Dict{Any, Any}(read_json(joinpath(path, "base_power.json")))
    sim_output = SimulationResultsReference(ref, results_folder, chronologies, base_powers)
    return sim_output
end

# internal function to parse through the reference dictionary and grab the file paths
function _read_references(
    results::Dict,
    list::Array,
    stage::String,
    step::Array,
    references::Dict,
    time_length::Int,
)

    for name in list
        date_df = references[stage][name]
        step_df = DataFrames.DataFrame(
            Date = Dates.DateTime[],
            Step = String[],
            File_Path = String[],
        )
        for n in 1:length(step)
            step_df = vcat(step_df, date_df[date_df.Step .== step[n], :])
        end
        results[name] = DataFrames.DataFrame()
        for (ix, time) in enumerate(step_df.Date)
            file_path = step_df[ix, :File_Path]
            var = Feather.read("$file_path")
            results[name] = vcat(results[name], var[1:time_length, :])
        end
    end
    return results
end
# internal function to parse through the reference dictionary and grab the file paths
function _read_references(
    results::Dict,
    list::Array,
    stage::String,
    references::Dict,
    time_length::Int,
)
    for name in list
        date_df = references[stage][name]
        results[name] = DataFrames.DataFrame()
        for (ix, time) in enumerate(date_df.Date)
            file_path = date_df[ix, :File_Path]
            var = Feather.read(file_path)
            var_length = min(time_length, size(var, 1))
            results[name] = vcat(results[name], var[1:var_length, :])
        end
    end
    return results
end
# internal function to remove the overlapping results and only use the most recent
function _read_time(file_path::String, time_length::Number)
    time_file_path = joinpath(dirname(file_path), "time_stamp.feather")
    temp_time_stamp = Feather.read("$time_file_path")
    time_stamp = temp_time_stamp[(1:time_length), :]
    time_stamp = convert.(Dates.DateTime, time_stamp)
    return time_stamp
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
- `variable::Array{Symbol} = [:P__ThermalStandard, :P__RenewableDispatch]`: the variables to be parsed

# Example
```julia
stage = "stage-1"
step = ["step-1", "step-2", "step-3"] # has to match the date range
variable = [:P__ThermalStandard, :P__RenewableDispatch]
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
    sim_output::SimulationResultsReference,
    stage_name::String,
    step::Array,
    variable::Array;
    kwargs...,
)
    results_folder = sim_output.results_folder
    stage = "stage-$stage_name"
    references = sim_output.ref
    base_power = sim_output.base_powers[stage_name]
    variables = Dict{Symbol, DataFrames.DataFrame}()
    duals = Dict{Symbol, Any}()
    params = Dict{Symbol, DataFrames.DataFrame}()
    time_stamp = DataFrames.DataFrame(Range = Dates.DateTime[])
    time_length = sim_output.chronologies[stage]
    dual = _find_duals(collect(keys(references[stage])))
    param = _find_params(collect(keys(references[stage])))
    variable = setdiff(variable, vcat(param, dual))
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
    duals = _read_references(duals, dual, stage, step, references, time_length)
    param_values = _read_references(params, param, stage, step, references, time_length)
    return SimulationResults(
        base_power,
        variables,
        obj_value,
        optimizer,
        time_stamp,
        duals,
        results_folder,
        param_values,
    )
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
    load_simulation_results(sim_output, stage)

This function goes through the reference table of file paths and
aggregates the results over time into a struct of type OperationsProblemResults

# Arguments
- `sim_output::SimulationResultsReference`: the container for the reference dictionary created in execute!
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
    base_power = sim_output.base_powers[stage_name]
    variables = Dict{Symbol, DataFrames.DataFrame}()
    duals = Dict{Symbol, Any}()
    params = Dict{Symbol, DataFrames.DataFrame}()
    variable = (collect(keys(references[stage])))
    dual = _find_duals(variable)
    param = _find_params(collect(keys(references[stage])))
    variable = setdiff(variable, vcat(param, dual))
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
    param_values = _read_references(params, param, stage, references, time_length)
    duals = _read_references(duals, dual, stage, references, time_length)
    return SimulationResults(
        base_power,
        variables,
        obj_value,
        optimizer,
        time_stamp,
        duals,
        results_folder,
        param_values,
    )
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

"""
    write_results(results::SimulationResults)

Exports Simulations Results to the path where they come from in the results folder

# Arguments
- `results::SimulationResults`: results from the simulation
- `save_path::String`: folder path where the files will be written
- `results_folder`: name of the folder where the results will be written

# Accepted Key Words
- `file_type = CSV`: only CSV and featherfile are accepted
"""

function IS.write_results(res::SimulationResults; kwargs...)
    folder_path = res.results_folder
    if !isdir(folder_path)
        throw(IS.ConflictingInputsError("Specified path is not valid. Set up results folder."))
    end
    write_data(res.variable_values, res.time_stamp, folder_path; kwargs...)
    write_optimizer_log(res.optimizer_log, folder_path)
    write_data(res.time_stamp, folder_path, "time_stamp"; kwargs...)
    write_data(res.base_power, folder_path)
    write_data(res.dual_values, folder_path; kwargs...)
    write_data(res.parameter_values, folder_path; kwargs...)
    files = collect(readdir(folder_path))
    compute_file_hash(folder_path, files)
    @info("Files written to $folder_path folder.")
    return
end

function serialize_sim_output(sim_results::SimulationResultsReference)
    file_path = mkdir(joinpath(dirname(sim_results.results_folder), "output_references"))
    for (k, stage) in sim_results.ref
        try
            for (i, v) in stage
                path = joinpath(file_path, "$k")
                !isdir(path) && mkdir(path)
                # TODO: Remove this line. There shouldn't be empties coming here.
                !isempty(v) && Feather.write(joinpath(path, "$i.feather"), v)
            end
        catch
            @warn("Results Reference not compatible with serialization")
        end
    end
    JSON.write(
        joinpath(file_path, "results_folder.json"),
        JSON.json(sim_results.results_folder),
    )
    JSON.write(
        joinpath(file_path, "chronologies.json"),
        JSON.json(sim_results.chronologies),
    )
    JSON.write(joinpath(file_path, "base_power.json"), JSON.json(sim_results.base_powers))
end

# writes the results to CSV files in a folder path, but they can't be read back
function write_to_CSV(res::SimulationResults; kwargs...)
    folder_path = res.results_folder
    if !isdir(folder_path)
        throw(IS.ConflictingInputsError("Specified path is not valid. Set up results folder."))
    end
    for (k, v) in IS.get_variables(res)
        if decode_symbol(k)[1] == "P"
            IS.get_variables(res)[k] = IS.get_base_power(res) .* v
        end
    end
    for (p, v) in IS.get_parameters(res)
        IS.get_parameters(res)[p] = IS.get_base_power(res) .* v
    end
    write_data(
        IS.get_variables(res),
        res.time_stamp,
        folder_path;
        file_type = CSV,
        kwargs...,
    )
    write_optimizer_log(IS.get_total_cost(res), folder_path)
    write_data(
        IS.get_time_stamp(res),
        folder_path,
        "time_stamp";
        file_type = CSV,
        kwargs...,
    )
    write_data(get_duals(res), folder_path; file_type = CSV, kwargs...)
    write_data(IS.get_parameters(res), folder_path; file_type = CSV, kwargs...)
    files = collect(readdir(folder_path))
    compute_file_hash(folder_path, files)
    @info("Files written to $folder_path folder.")
    return
end

"""
    get_result_variable(IS.results, Symbol, PSY.DataType)

Retrieve a specific variable dataframe from the results.

# Arguments
- `results::IS.Results`
- `name::Symbol`: The prefix for a type of variable or parameter
- `PSY.DataType`: The datatype of the variable from Power Systems

# Example
```julia
variable = get_result_variable(results, :ON, ThermalStandard)
```
"""

function get_result_variable(results::IS.Results, sym::Symbol, data_type::PSY.DataType)
    variable_name = encode_symbol(data_type, sym)
    if variable_name in keys(IS.get_variables(results))
        variable = get_result_variable(results, variable_name)
        return variable
    else
        @info "Variable $variable_name not found in results."
    end
end

function get_result_variable(results::IS.Results, variable_name::Symbol)
    return IS.get_variables(results)[variable_name]
end

function get_variable_names(results::IS.Results)
    return collect(keys(results.variable_values))
end
