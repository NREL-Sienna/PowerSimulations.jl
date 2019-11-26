struct SimulationResultsContainer
    ref::Dict
    results_folder::String
    chronologies::Dict
end

function get_sim_resolution(stage::_Stage)
    resolution = stage.sys.data.forecast_metadata.resolution
    return resolution
end

function sim_results_container(sim::Simulation)
    date_run = convert(String, last(split(dirname(sim.ref.raw), "/")))
    ref = make_references(sim, date_run)
    chronologies = Dict()
    for (ix, stage) in enumerate(sim.stages)
        interval = convert(Dates.Minute,stage.interval)
        resolution = convert(Dates.Minute,get_sim_resolution(stage))
        chronologies["stage-$ix"] = convert(Int64,(interval/resolution))
    end
    sim_results = SimulationResultsContainer(ref, sim.ref.results, chronologies)
    return sim_results
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
sim = Simulation("test", 7, stages, "/Users/yourusername/Desktop/";
verbose = true, system_to_file = false)
execute!(sim::Simulation; verbose::Bool = false, kwargs...)
references = make_references(sim, "2019-10-03T09-18-00-test")
```

# Accepted Key Words
- `dual_constraints::Vector{Symbol}`: name of dual constraints to be added to results
"""
function make_references(sim::Simulation, date_run::String; kwargs...)
    sim.ref.date_ref[1] = sim.daterange[1]
    sim.ref.date_ref[2] = sim.daterange[1]
    references = Dict()
    for (ix, stage) in enumerate(sim.stages)
        variables = Dict{Symbol, Any}()
        interval = stage.interval
        variable_names = (collect(keys(sim.stages[ix].psi_container.variables)))
        if :dual_constraints in keys(kwargs) && !isnothing(get_constraints(stage.psi_container))
            dual_cons = _concat_string(kwargs[:dual_constraint])
            variable_names = vcat(variable_names, dual_cons)
        end
        for name in variable_names
            variables[name] = DataFrames.DataFrame(Date = Dates.DateTime[],
                                           Step = String[], File_Path = String[])
        end
        for s in 1:(sim.steps)
            for run in 1:stage.executions
                sim.ref.current_time = sim.ref.date_ref[ix]
                for name in variable_names
                    full_path = joinpath(sim.ref.raw, "step-$(s)-stage-$(ix)",
                                replace_chars("$(sim.ref.current_time)", ":", "-"), "$(name).feather")
                    if isfile(full_path)
                        date_df = DataFrames.DataFrame(Date = sim.ref.current_time,
                                                       Step = "step-$(s)", File_Path = full_path)
                        variables[name] = vcat(variables[name], date_df)
                    else
                        @info("$full_path, no such file path")
                     end
                end
                sim.ref.run_count[s][ix] += 1
                sim.ref.date_ref[ix] = sim.ref.date_ref[ix] + interval
            end
        end
        references["stage-$ix"] = variables
        stage.execution_count = 0
    end
    return references
end
"""This function outputs the step range correlated to a given date range"""
function find_step_range(rsim_result::SimulationResultsContainer, stage::String, Dates::StepRange{Dates.DateTime, Any})
    references = sim_results.ref
    variable = (collect(keys(references[stage])))
    date_df = references[stage][variable[1]]
    steps = date_df[findall(in(Dates), date_df.Date), :].Step
    unique!(steps)
    return steps
end

"""
    load_simulation_results(stage, step, variable, sim_results_container)

This function goes through the reference table of file paths and
aggregates the results over time into a struct of type OperationsProblemResults
for the desired step range and variables

# Arguments
- `stage::String = "stage-1"``: The stage of the results getting parsed, stage-1 or stage-2
- `step::Array{String} = ["step-1", "step-2", "step-3"]`: the steps of the results getting parsed
- `variable::Array{Symbol} = [:P_ThermalStandard, :P_RenewableDispatch]`: the variables to be parsed
- `sim_results_container::SimulationResultsContainer`: the container for the reference dictionary created in execute!
or with make_references

# Example
```julia
stage = "stage-1"
step = ["step-1", "step-2", "step-3"] # has to match the date range
variable = [:P_ThermalStandard, :P_RenewableDispatch]
results = load_simulation_results(stage,step, variable, sim_results_container)
```
# Accepted Key Words
- `write::Bool`: if true, the aggregated results get written back to the results file in the folder structure
"""
function load_simulation_results(stage::String,
         step::Array,
         variable::Array,
         sim_results_container::SimulationResultsContainer; kwargs...)
    references = sim_results_container.ref
    variables = Dict()
    duals = Dict()
    time_stamp = DataFrames.DataFrame(Range = Dates.DateTime[])
    time_length = sim_results_container.chronologies[stage]
    dual = _find_duals(collect(keys(references[stage])))
    #extra_time_length = _count_time_overlap(stage, step, variable, references)
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
            end
        end
    end
    check_sum = _sum_variable_results(variables)
    time_stamp[!,:Range] = convert(Array{Dates.DateTime}, time_stamp[!,:Range])
    file_path = references[stage][variable[1]][1,:File_Path]
    optimizer = optimizer = JSON.parse(open(joinpath(dirname(file_path), "optimizer_log.json")))
    obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer["obj_value"])
    if !isempty(dual)
        duals = _reading_references(duals, dual, stage, step, references, extra_time_length)
        results = _make_results(variables, obj_value, optimizer, time_stamp, check_sum, duals)
    else
        results = _make_results(variables, obj_value, optimizer, time_stamp, check_sum)
    end
    file_type = get(kwargs, :file_type, Feather)
    write = get(kwargs, :write, false)
    if write == true || :file_type in keys(kwargs)
        write_results(results, sim_results_container.results_folder, "results"; file_type = file_type)
    end
    return results
end

"""
    load_simulation_results(stage, sim_results_container)

This function goes through the reference table of file paths and
aggregates the results over time into a struct of type OperationsProblemResults

# Arguments
- `stage::String = "stage-1"`: The stage of the results getting parsed, stage-1 or stage-2
- `sim_results_container::SimulationResultsContainer`: the container for the reference dictionary created in execute!
or with make_references

# Example
```julia
stage = "stage-1"
step = ["step-1", "step-2", "step-3"] # has to match the date range
variable = [:P_ThermalStandard, :P_RenewableDispatch]
results = load_simulation_results(stage, step, variable, sim_results_container)
```
# Accepted Key Words
- `write::Bool`: if true, the aggregated results get written back to the results file in the folder structure
"""

function load_simulation_results(stage::String, sim_results_container::SimulationResultsContainer; kwargs...)
    references = sim_results_container.ref
    variables = Dict()
    duals = Dict()
    variable = (collect(keys(references[stage])))
    dual = _find_duals(variable)
    variable = setdiff(variable, duals)
    time_stamp = DataFrames.DataFrame(Range = Dates.DateTime[])
    time_length = sim_results_container.chronologies[stage]
  #extra_time_length = _count_time_overlap(stage, references)
    for l in 1:length(variable)
        date_df = references[stage][variable[l]]
        variables[(variable[l])] = DataFrames.DataFrame()
        for (ix,time) in enumerate(date_df.Date)
            file_path = date_df[ix, :File_Path]
            var = Feather.read(file_path)
            variables[(variable[l])] = vcat(variables[(variable[l])],var[1:time_length,:])
            if l == 1
                time_stamp = vcat(time_stamp, _reading_time(file_path, time_length))
            end
        end
    end
    check_sum = _sum_variable_results(variables)
    time_stamp[!,:Range] = convert(Array{Dates.DateTime}, time_stamp[!,:Range])
    file_path = references[stage][variable[1]][1,:File_Path]
    optimizer = optimizer = JSON.parse(open(joinpath(dirname(file_path), "optimizer_log.json")))
    obj_value = Dict{Symbol, Any}(:OBJECTIVE_FUNCTION => optimizer["obj_value"])
    if !isempty(dual)
        duals = _reading_references(duals, dual, stage, references, extra_time_length)
        results = _make_results(variables, obj_value, optimizer, time_stamp, check_sum, duals)
    else
        results = _make_results(variables, obj_value, optimizer, time_stamp, check_sum)
    end
    file_type = get(kwargs, :file_type, Feather)
    write = get(kwargs, :write, false)
    if write == true
        write_results(results, sim_results_container.results_folder, "results")
    end
    return results
end
