struct SimulationResultsReference
    ref::Dict
    results_folder::String
    chronologies::Dict
    function SimulationResultsReference(sim::Simulation)
        date_run = convert(String, last(split(dirname(sim.ref.raw_dir), "/")))
        ref = make_references(sim, date_run)
        chronologies = Dict()
        for (ix, stage) in enumerate(sim.stages)
            interval = convert(Dates.Minute,stage.interval)
            resolution = convert(Dates.Minute,get_sim_resolution(stage))
            chronologies["stage-$ix"] = convert(Int64,(interval/resolution))
        end
        new(ref, sim.ref.results_dir, chronologies)
    end
end

function get_sim_resolution(stage::Stage)
    resolution = stage.sys.data.forecast_metadata.resolution
    return resolution
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
                    full_path = joinpath(sim.ref.raw_dir, "step-$(s)-stage-$(ix)",
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
function find_step_range(rsim_result::SimulationResultsReference, stage::String, Dates::StepRange{Dates.DateTime, Any})
    references = sim_results.ref
    variable = (collect(keys(references[stage])))
    date_df = references[stage][variable[1]]
    steps = date_df[findall(in(Dates), date_df.Date), :].Step
    unique!(steps)
    return steps
end
