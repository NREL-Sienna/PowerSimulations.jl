include("get_results.jl")

function solve_op_model!(op_model::OperationModel; kwargs...)

    optimizer_log = Dict{Symbol, Any}()

    if op_model.canonical_model.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER

        if !(:optimizer in keys(kwargs))

            @error("No Optimizer has been defined, can't solve the operational problem")

        else
            _, optimizer_log[:timed_solve_time],
               optimizer_log[:solve_bytes_alloc],
               optimizer_log[:sec_in_gc] = @timed JuMP.optimize!(op_model.canonical_model.JuMPmodel, kwargs[:optimizer])

        end

    else

        JuMP.optimize!(op_model.canonical_model.JuMPmodel)

    end

    vars_result = get_model_result(op_model.canonical_model)
    optimizer_log(optimizer_log, op_model.canonical_model)

    return OpertationModelResults(vars_result, optimizer_log)

end


function run_stage(stage::Stage, results_path::String)

    for run in stage.execution_count
        if stage.model.canonical_model.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER
            error("No Optimizer has been defined, can't solve the operational problem")
        end

        optimizer_log = Dict{Symbol, Any}()

        _, optimizer_log[:timed_solve_time],
        optimizer_log[:solve_bytes_alloc],
        optimizer_log[:sec_in_gc] = @timed JuMP.optimize!(stage.model.canonical_model.JuMPmodel)

        write_model_result(stage.model.canonical_model, results_path)
        write_optimizer_log(optimizer_log, stage.model.canonical_model, results_path)

    end

    return

end
