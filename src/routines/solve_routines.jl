include("get_results.jl")

function solve_op_model!(op_model::OperationModel; kwargs...)

    if op_model.canonical_model.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER

        if !(:optimizer in keys(kwargs))

            @error("No Optimizer has been defined, can't solve the operational problem")

        else

            JuMP.optimize!(op_model.canonical_model.JuMPmodel, kwargs[:optimizer])

        end

    else

        JuMP.optimize!(op_model.canonical_model.JuMPmodel)

    end

    vars_result = get_model_result(op_model.canonical_model)
    obj_value = Dict(:ED => JuMP.objective_value(op_model.canonical_model.JuMPmodel))
    opt_log = optimizer_log(op_model.canonical_model)

    return OpertationModelResults(vars_result, obj_value, opt_log)

end


