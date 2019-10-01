function solve_op_model!(op_model::OperationModel; kwargs...)

    timed_log = Dict{Symbol, Any}()

    save_path = get(kwargs, :save_path, nothing)

    if op_model.canonical.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER

        if !(:optimizer in keys(kwargs))
            error("No Optimizer has been defined, can't solve the operational problem")
        end

        _, timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] = @timed JuMP.optimize!(op_model.canonical.JuMPmodel,
                                                        kwargs[:optimizer])

    else

        _, timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] = @timed JuMP.optimize!(op_model.canonical.JuMPmodel)

    end
    #creating the results to print to memory
    vars_result = get_model_result(op_model)
    optimizer_log = get_optimizer_log(op_model)
    time_stamp = get_time_stamp(op_model)
    n = size(time_stamp,1)
    time_stamp = time_stamp[1:n-1, :]
    obj_value = Dict(:OBJECTIVE_FUNCTION => JuMP.objective_value(op_model.canonical.JuMPmodel))
    merge!(optimizer_log, timed_log)

    #results to be printed to memory
    results = OperationModelResults(vars_result, obj_value, optimizer_log, time_stamp)

    !isnothing(save_path) && write_model_results(results, save_path)

     return results

end

function _run_stage(stage::_Stage, results_path::String)

    for run in stage.executions
        if stage.model.canonical.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER
            error("No Optimizer has been defined, can't solve the operational problem stage with key $(stage.key)")
        end

        timed_log = Dict{Symbol, Any}()
        _, timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] =  @timed JuMP.optimize!(stage.model.canonical.JuMPmodel)
        model_status = JuMP.primal_status(stage.model.canonical.JuMPmodel)
        if model_status != MOI.FEASIBLE_POINT::MOI.ResultStatusCode
            error("Stage $(stage.key) status is $(model_status)")
        end
        _export_model_result(stage.model, results_path)
        _export_optimizer_log(timed_log, stage.model, results_path)
        stage.execution_count += 1
    end

    return

end


"""Runs Simulations"""
function run_sim_model!(sim::Simulation; verbose::Bool = false, kwargs...)

    if sim.ref.reset
        sim.ref.reset = false
    elseif sim.ref.reset == false
        error("Reset the simulation")
    end

    steps = get_steps(sim)
    for s in 1:steps
        verbose && println("Step $(s)")
        for (ix, stage) in enumerate(sim.stages)
            verbose && println("Stage $(ix)")
            interval = PSY.get_forecasts_interval(stage.model.sys)
            for run in 1:stage.executions
                sim.ref.current_time = sim.ref.date_ref[ix]
                verbose && println("Simulation TimeStamp: $(sim.ref.current_time)")
                raw_results_path = joinpath(sim.ref.raw,"step-$(s)-stage-$(ix)","$(sim.ref.current_time)")
                mkpath(raw_results_path)
                update_stage!(stage, s, sim)
                _run_stage(stage, raw_results_path)
                sim.ref.run_count[s][ix] += 1
                sim.ref.date_ref[ix] = sim.ref.date_ref[ix] + interval
            end
            @assert stage.executions == stage.execution_count
            stage.execution_count = 0 # reset stage execution_count
        end
    end

    return

end
