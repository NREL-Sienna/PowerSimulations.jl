function update_model!(
    model::IOM.AbstractOptimizationModel,
    source::SimulationState,
    ini_cond_chronology,
)
    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Parameter Updates" begin
        update_parameters!(model, source)
    end
    TimerOutputs.@timeit RUN_SIMULATION_TIMER "Ini Cond Updates" begin
        update_initial_conditions!(model, source, ini_cond_chronology)
    end
    return
end

function update_parameters!(
    model::IOM.AbstractOptimizationModel,
    simulation_state::SimulationState,
)
    container = get_optimization_container(model)
    cost_function_unsynch(container)
    for key in keys(get_parameters(model))
        update_parameter_values!(model, key, simulation_state)
    end
    # A rebuilt model builds its objective from the updated parameters.
    if _edits_in_place(container) && !is_synchronized(model)
        update_objective_function!(container)
        obj_func = get_objective_expression(container)
        set_synchronized_status!(obj_func, true)
    end
    return
end
