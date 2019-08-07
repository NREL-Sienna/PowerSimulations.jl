""" Solves Operational Models"""

function _write_op_model(results::OperationModelResults, save_path::String)
 
    try 

        isdir(save_path)
        new_folder = mkdir("$save_path/$(round(Dates.now(),Dates.Minute))")
        folder_path = new_folder
        write_variable_results(results.variables, folder_path) 
        write_optimizer_results(results.optimizer_log, folder_path)
        write_time_stamps(results.times, folder_path)
        println("Files written to $folder_path folder.")

    catch 
        
        @error("Specified path is not valid. Run write_results to save results.")
        
    end

end

function solve_op_model!(op_model::OperationModel; kwargs...)

    timed_log = Dict{Symbol, Any}()

    save_path = get(kwargs, :save_path, nothing)
    
        if op_model.canonical.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER

            if !(:optimizer in keys(kwargs))

                error("No Optimizer has been defined, can't solve the operational problem")

            else
                _, timed_log[:timed_solve_time],
                timed_log[:solve_bytes_alloc],
                timed_log[:sec_in_gc] = @timed JuMP.optimize!(op_model.canonical.JuMPmodel,
                                                                kwargs[:optimizer])

            end

        else

            _, timed_log[:timed_solve_time],
            timed_log[:solve_bytes_alloc],
            timed_log[:sec_in_gc] = @timed JuMP.optimize!(op_model.canonical.JuMPmodel)

        end
        #creating the results to print to memory
        vars_result = get_model_result(op_model)
        optimizer_log = get_optimizer_log(op_model)
        time_stamp = get_time_stamp(op_model)
        obj_value = Dict(:OBJECTIVE_FUNCTION => JuMP.objective_value(op_model.canonical.JuMPmodel))
        merge!(optimizer_log, timed_log)

        #results to be printed to memory
        results = OperationModelResults(vars_result, obj_value, optimizer_log, time_stamp)

         if isnothing(save_path)
         else
             _write_op_model(results, save_path)
         end
     return results
end


function _run_stage(stage::_Stage, results_path::String)

    for run in stage.execution_count
        if stage.model.canonical.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER
            error("No Optimizer has been defined, can't solve the operational problem")
        end

        timed_log = Dict{Symbol, Any}()
        _, timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] =  @timed JuMP.optimize!(stage.model.canonical.JuMPmodel)

        write_model_result(stage.model, results_path)
        write_optimizer_log(timed_log, stage.model, results_path)

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
            for run in 1:stage.execution_count
                sim.ref.current_time = sim.ref.date_ref[ix]
                verbose && println("Simulation TimeStamp: $(sim.ref.current_time)")
                raw_results_path = joinpath(sim.ref.raw,"step-$(s)-stage-$(ix)","$(sim.ref.current_time)")
                mkpath(raw_results_path)
                _run_stage(stage, raw_results_path)
                sim.ref.run_count[s][ix] += 1
                sim.ref.date_ref[ix] = sim.ref.date_ref[ix] + interval
                update_stage!(stage, sim)
            end
        end
    end

    return

end
