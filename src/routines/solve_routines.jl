"""
    solve_op_problem!(op_problem::OperationsProblem; kwargs...)

This solves the operational model for a single instance and
outputs results of type OperationsProblemResult: objective value, time log,
a dictionary of variables and their dataframe of results, and a time stamp.

# Arguments
- `op_problem::OperationModel = op_problem`: operation model

# Examples
```julia
results = solve_op_problem!(OpModel)
```
# Accepted Key Words
- `save_path::String`: If a file path is provided the results
automatically get written to feather files
- `optimizer::OptimizerFactory`: The optimizer that is used to solve the model
"""
function solve_op_problem!(op_problem::OperationsProblem; kwargs...)
    timed_log = Dict{Symbol, Any}()
    save_path = get(kwargs, :save_path, nothing)

    if op_problem.psi_container.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER
        if !(:optimizer in keys(kwargs))
            error("No Optimizer has been defined, can't solve the operational problem")
        end
        _, timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] = @timed JuMP.optimize!(op_problem.psi_container.JuMPmodel,
                                                        kwargs[:optimizer])
    else
        _, timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] = @timed JuMP.optimize!(op_problem.psi_container.JuMPmodel)
    end

    vars_result = get_model_result(op_problem)
    optimizer_log = get_optimizer_log(op_problem)
    time_stamp = get_time_stamps(op_problem)
    time_stamp = shorten_time_stamp(time_stamp)
    obj_value = Dict(:OBJECTIVE_FUNCTION => JuMP.objective_value(op_problem.psi_container.JuMPmodel))
    merge!(optimizer_log, timed_log)
    results = SimulationResults(vars_result, obj_value, optimizer_log, time_stamp)

    !isnothing(save_path) && write_results(results, save_path)

     return results
end

function _run_stage(stage::Stage, start_time::Dates.DateTime, results_path::String; kwargs...)
    @assert stage.internal.psi_container.JuMPmodel.moi_backend.state != MOIU.NO_OPTIMIZER
    timed_log = Dict{Symbol, Any}()
    _, timed_log[:timed_solve_time],
    timed_log[:solve_bytes_alloc],
    timed_log[:sec_in_gc] = @timed JuMP.optimize!(stage.internal.psi_container.JuMPmodel)
    model_status = JuMP.primal_status(stage.internal.psi_container.JuMPmodel)
    if model_status != MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        error("Stage $(stage.internal.number) status is $(model_status)")
    end
    retrieve_duals = get(kwargs, :duals, nothing)
    if !isnothing(retrieve_duals) && !isnothing(get_constraints(stage.internal.psi_container))
        _export_model_result(stage, start_time, results_path, retrieve_duals)
    else
        _export_model_result(stage, start_time, results_path)
    end
    _export_optimizer_log(timed_log, stage.internal.psi_container, results_path)
    stage.internal.execution_count += 1
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
sim = Simulation("test", 7, stages, "/Users/folder";
verbose = true, system_to_file = false)
execute!!(sim::Simulation; verbose::Bool = false, kwargs...)
```

# Accepted Key Words
- `dual_constraints::Vector{Symbol}`: if dual variables are desired in the
results, include a vector of the variable names to be included
"""

function execute!(sim::Simulation; verbose::Bool = false, kwargs...)
    !sim.internal.compiled_status && error("Simulation not build, build the simulation to execute")
    if sim.internal.reset
        sim.internal.reset = false
    elseif sim.internal.reset == false
        error("Re-build the simulation")
    end
    steps = get_steps(sim)
    for s in 1:steps
        verbose && println("Step $(s)")
        for stage_number in 1:sim.internal.stages_count
            stage_name = sim.sequence.order[stage_number]
            stage = get(sim.stages, stage_name, nothing)
            verbose && println("Stage $(stage_number)-$(stage_name)")
            stage_interval = sim.sequence.intervals[stage_name]
            for run in 1:stage.internal.executions
                sim.internal.current_time = sim.internal.date_ref[stage_number]
                verbose && println("Simulation TimeStamp: $(sim.internal.current_time)")
                raw_results_path = joinpath(sim.internal.raw_dir, "step-$(s)-stage-$(stage_name)", replace_chars("$(sim.internal.current_time)", ":", "-"))
                mkpath(raw_results_path)
                update_stage!(stage, s, sim)
                dual_constraints = get(kwargs, :dual_constraints, nothing)
                _run_stage(stage, sim.internal.current_time, raw_results_path; duals = dual_constraints)
                sim.internal.run_count[s][stage_number] += 1
                sim.internal.date_ref[stage_number] = sim.internal.date_ref[stage_number] + stage_interval
            end
            @assert stage.internal.executions == stage.internal.execution_count
            stage.internal.execution_count = 0 # reset stage execution_count
        end

    end
    sim_results = SimulationResultsReference(sim)
    return sim_results
end
