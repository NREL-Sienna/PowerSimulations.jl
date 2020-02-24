"""
    solve_op_problem!(op_problem::OperationsProblem; kwargs...)

This solves the operational model for a single instance and
outputs results of type OperationsProblemResult

# Arguments
- `op_problem::OperationModel = op_problem`: operation model

# Examples
```julia
results = solve_op_problem!(OpModel)
```
# Accepted Key Words
- `save_path::String`: If a file path is provided the results
automatically get written to feather files
- `optimizer::MOI.OptimizerWithAttributes`: The optimizer that is used to solve the model
- `constraints_duals::Array`: Array of the constraints duals to be in the results
"""
function solve_op_problem!(op_problem::OperationsProblem; kwargs...)
    timed_log = Dict{Symbol, Any}()
    save_path = get(kwargs, :save_path, nothing)

    if op_problem.psi_container.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER
        if !(:optimizer in keys(kwargs))
            error("No Optimizer has been defined, can't solve the operational problem")
        end
        _,
        timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] =
            @timed JuMP.optimize!(op_problem.psi_container.JuMPmodel, kwargs[:optimizer])
    else
        _,
        timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] = @timed JuMP.optimize!(op_problem.psi_container.JuMPmodel)
    end

    vars_result = get_model_result(op_problem)
    optimizer_log = get_optimizer_log(op_problem)
    time_stamp = get_time_stamps(op_problem)
    time_stamp = shorten_time_stamp(time_stamp)
    obj_value = Dict(
        :OBJECTIVE_FUNCTION => JuMP.objective_value(op_problem.psi_container.JuMPmodel),
    )
    merge!(optimizer_log, timed_log)
    if :constraints_duals in keys(kwargs)
        dual_result = get_model_duals(op_problem.psi_container, kwargs[:constraints_duals])
        results =
            _make_results(vars_result, obj_value, optimizer_log, time_stamp, dual_result)
    else
        results =
            OperationsProblemResults(vars_result, obj_value, optimizer_log, time_stamp)
    end
    !isnothing(save_path) && write_results(results, save_path)

    return results
end
