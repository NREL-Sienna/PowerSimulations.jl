"""
Construct OptimizationProblemResults from a solved DecisionModel.
"""
function OptimizationProblemResults(model::DecisionModel)
    status = get_run_status(model)
    status != RunStatus.SUCCESSFULLY_FINALIZED &&
        error("problem was not solved successfully: $status")

    model_store = get_store(model)

    if isempty(model_store)
        error("Model Solved as part of a Simulation.")
    end

    timestamps = get_timestamps(model)
    optimizer_stats = ISOPT.to_dataframe(get_optimizer_stats(model))

    aux_variable_values =
        Dict(x => read_aux_variable(model, x) for x in list_aux_variable_keys(model))
    variable_values = Dict(x => read_variable(model, x) for x in list_variable_keys(model))
    dual_values = Dict(x => read_dual(model, x) for x in list_dual_keys(model))
    parameter_values =
        Dict(x => read_parameter(model, x) for x in list_parameter_keys(model))
    expression_values =
        Dict(x => read_expression(model, x) for x in list_expression_keys(model))

    sys = get_system(model)

    return OptimizationProblemResults(
        get_problem_base_power(model),
        timestamps,
        sys,
        IS.get_uuid(sys),
        aux_variable_values,
        variable_values,
        dual_values,
        parameter_values,
        expression_values,
        optimizer_stats,
        get_metadata(get_optimization_container(model)),
        IS.strip_module_name(typeof(model)),
        get_output_dir(model),
        mkpath(joinpath(get_output_dir(model), "results")),
    )
end

"""
Construct OptimizationProblemResults from a solved EmulationModel.
"""
function OptimizationProblemResults(model::EmulationModel)
    status = get_run_status(model)
    status != RunStatus.SUCCESSFULLY_FINALIZED &&
        error("problem was not solved successfully: $status")

    model_store = get_store(model)

    if isempty(model_store)
        error("Model Solved as part of a Simulation.")
    end

    aux_variables =
        Dict(x => read_aux_variable(model, x) for x in list_aux_variable_keys(model))
    variables = Dict(x => read_variable(model, x) for x in list_variable_keys(model))
    duals = Dict(x => read_dual(model, x) for x in list_dual_keys(model))
    parameters = Dict(x => read_parameter(model, x) for x in list_parameter_keys(model))
    expression = Dict(x => read_expression(model, x) for x in list_expression_keys(model))
    optimizer_stats = read_optimizer_stats(model)
    initial_time = get_initial_time(model)
    container = get_optimization_container(model)
    sys = get_system(model)

    return OptimizationProblemResults(
        get_problem_base_power(model),
        StepRange(initial_time, get_resolution(model), initial_time),
        sys,
        IS.get_uuid(sys),
        aux_variables,
        variables,
        duals,
        parameters,
        expression,
        optimizer_stats,
        get_metadata(container),
        IS.strip_module_name(typeof(model)),
        get_output_dir(model),
        mkpath(joinpath(get_output_dir(model), "results")),
    )
end
