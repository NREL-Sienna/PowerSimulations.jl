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
    cost_function_unsynch(get_optimization_container(model))
    for key in keys(get_parameters(model))
        update_parameter_values!(model, key, simulation_state)
    end
    container = get_optimization_container(model)
    if _edits_in_place(container) && !is_synchronized(container)
        update_objective_function!(container)
        set_synchronized_status!(get_objective_expression(container), true)
    end
    return
end
