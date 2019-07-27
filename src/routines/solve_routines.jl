""" Solves Operational Models"""
function solve_op_model!(op_model::OperationModel; kwargs...)

    optimizer_log_dict = Dict{Symbol, Any}()

    if op_model.canonical_model.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER

        if !(:optimizer in keys(kwargs))

            @error("No Optimizer has been defined, can't solve the operational problem")

        else
            _, optimizer_log_dict[:timed_solve_time],
            optimizer_log_dict[:solve_bytes_alloc],
            optimizer_log_dict[:sec_in_gc] = @timed JuMP.optimize!(op_model.canonical_model.JuMPmodel, kwargs[:optimizer])

        end

    else

        JuMP.optimize!(op_model.canonical_model.JuMPmodel)

    end

    vars_result = get_model_result(op_model.canonical_model)
    optimizer_log!(optimizer_log_dict, op_model.canonical_model)

    return OpertationModelResults(vars_result, optimizer_log_dict)

end


function _run_stage(stage::Stage, results_path::String)

    for run in stage.execution_count
        if stage.model.canonical_model.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER
            error("No Optimizer has been defined, can't solve the operational problem")
        end

        optimizer_log_dict = Dict{Symbol, Any}()

        _, optimizer_log_dict[:timed_solve_time],
        optimizer_log_dict[:solve_bytes_alloc],
        optimizer_log_dict[:sec_in_gc] = @timed JuMP.optimize!(stage.model.canonical_model.JuMPmodel)

        write_model_result(stage.model.canonical_model, results_path)
        write_optimizer_log(optimizer_log_dict, stage.model.canonical_model, results_path)

    end

    return

end


"""Runs Simulations"""
function run_sim_model!(sim::Simulation; verbose::Bool = false)

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
            for run in 1:stage.execution_count
                sim.ref.current_time = sim.ref.date_ref[ix]
                verbose && println("Simulation TimeStamp: $(sim.ref.current_time)")
                raw_results_path = joinpath(sim.ref.raw,"step-$(s)-stage-$(ix)","$(sim.ref.current_time)")
                mkpath(raw_results_path)
                _run_stage(stage, raw_results_path)
                sim.ref.run_count[ix] += 1
                sim.ref.date_ref[ix] = sim.ref.date_ref[ix] + interval
            end
        end
    end

    return

end
