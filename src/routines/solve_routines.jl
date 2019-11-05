"""
    solve_op_problem!(op_problem::OperationsProblem; kwargs...)

This solves the operational model for a single instance and
outputs results of type OperationsProblemResult: objective value, time log,
a dictionary of variables and their dataframe of results, and a time stamp.

# Arguments
-`op_problem::OperationModel = op_problem`: operation model

# Examples
```julia
results = solve_op_problem!(OpModel)
```
# Accepted Key Words
-`save_path::String`: If a file path is provided the results
automatically get written to feather files
-`optimizer::OptimizerFactory`: The optimizer that is used to solve the model
"""
function solve_op_problem!(op_problem::OperationsProblem; kwargs...)

    timed_log = Dict{Symbol, Any}()

    save_path = get(kwargs, :save_path, nothing)

    if op_problem.canonical.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER

        if !(:optimizer in keys(kwargs))
            error("No Optimizer has been defined, can't solve the operational problem")
        end

        _, timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] = @timed JuMP.optimize!(op_problem.canonical.JuMPmodel,
                                                        kwargs[:optimizer])

    else

        _, timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] = @timed JuMP.optimize!(op_problem.canonical.JuMPmodel)

    end

    vars_result = get_model_result(op_problem)
    optimizer_log = get_optimizer_log(op_problem)
    time_stamp = get_time_stamps(op_problem)
    time_stamp = shorten_time_stamp(time_stamp)
    obj_value = Dict(:OBJECTIVE_FUNCTION => JuMP.objective_value(op_problem.canonical.JuMPmodel))
    merge!(optimizer_log, timed_log)

    results = make_results(vars_result, obj_value, optimizer_log, time_stamp)

    !isnothing(save_path) && write_results(results, save_path)

     return results

end

function _run_stage(stage::_Stage, start_time::Dates.DateTime, results_path::String;kwargs...)

    if stage.canonical.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER
        error("No Optimizer has been defined, can't solve the operational problem stage with key $(stage.key)")
    end
    timed_log = Dict{Symbol, Any}()
    _, timed_log[:timed_solve_time],
    timed_log[:solve_bytes_alloc],
    timed_log[:sec_in_gc] = @timed JuMP.optimize!(stage.canonical.JuMPmodel)
    model_status = JuMP.primal_status(stage.canonical.JuMPmodel)
    if model_status != MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        error("Stage $(stage.key) status is $(model_status)")
    end
    if duals in keys(kwargs) && !isnothing(get_constraints(stage.canonical))
        _export_model_result(stage, start_time, results_path, kwargs[:duals])
    else
        _export_model_result(stage, start_time, results_path)
    end
    _export_optimizer_log(timed_log, stage.canonical, results_path)
    stage.execution_count += 1
    return
end

"""
    execute!(sim::Simulation; verbose::Bool = false, kwargs...)

Solves the simulation model for sequential Simulations
and populates a nested folder structure created in Simulation()
with a dated folder of featherfiles that contain the results for
each stage and step.

# Arguments
- `sim::Simulation=sim`: simulation object created by Simulation()

# Example
```julia
sim = Simulation("test", 7, stages, "/Users/lhanig/Downloads/";
verbose = true, system_to_file = false)
execute!!(sim::Simulation; verbose::Bool = false, kwargs...)
```

# Accepted Key Words
`dual_constraints::Vector{Symbol}`: if dual variables are desired in the
results, include a vector of the variable names to be included
"""
function execute!(sim::Simulation; verbose::Bool = false, kwargs...)
    _prepare_workspace!(sim_ref, base_name, simulation_folder)
    if sim.ref.reset
        sim.ref.reset = false
    elseif sim.ref.reset == false
        error("Reset the simulation")
    end
    variable_names = Dict()
    steps = get_steps(sim)
    for s in 1:steps
        verbose && println("Step $(s)")
        for (ix, stage) in enumerate(sim.stages)
            verbose && println("Stage $(ix)")
            interval = PSY.get_forecasts_interval(stage.sys)
            for run in 1:stage.executions
                sim.ref.current_time = sim.ref.date_ref[ix]
                verbose && println("Simulation TimeStamp: $(sim.ref.current_time)")
                raw_results_path = joinpath(sim.ref.raw,"step-$(s)-stage-$(ix)",replace_chars("$(sim.ref.current_time)",":","-"))
                mkpath(raw_results_path)
                update_stage!(stage, s, sim)
                if :dual_constraints in keys(kwargs)
                    _run_stage(stage, sim.ref.current_time, raw_results_path; duals = kwargs[:dual_constraints])
                else
                    _run_stage(stage, sim.ref.current_time, raw_results_path)
                end
                sim.ref.run_count[s][ix] += 1
                sim.ref.date_ref[ix] = sim.ref.date_ref[ix] + interval
            end
            @assert stage.executions == stage.execution_count
            stage.execution_count = 0 # reset stage execution_count
        end

    end
    date_run = convert(String,last(split(dirname(sim.ref.raw),"/")))
    ref = make_references(sim, date_run)
    return reference
end
