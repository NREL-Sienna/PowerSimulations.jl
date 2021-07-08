# Default implementations of getter/setter functions for OperationsProblem.
is_built(problem::OperationsProblem) = problem.internal.status == BuildStatus.BUILT
is_empty(problem::OperationsProblem) = problem.internal.status == BuildStatus.EMPTY
warm_start_enabled(problem::OperationsProblem) =
    get_warm_start(get_optimization_container(problem).settings)
built_for_simulation(problem::OperationsProblem) = get_simulation_info(problem) !== nothing
get_caches(x::OperationsProblem) =
    built_for_simulation(x) ? get_simulation_info(x).caches : nothing
get_constraints(problem::OperationsProblem) = get_internal(problem).container.constraints
get_end_of_interval_step(problem::OperationsProblem) =
    get_simulation_info(problem).end_of_interval_step
get_execution_count(problem::OperationsProblem) =
    get_simulation_info(problem).execution_count
get_executions(problem::OperationsProblem) = get_simulation_info(problem).executions
get_initial_time(problem::OperationsProblem) = get_initial_time(get_settings(problem))
get_horizon(problem::OperationsProblem) = get_horizon(get_settings(problem))
get_internal(problem::OperationsProblem) = problem.internal
get_jump_model(problem::OperationsProblem) = get_internal(problem).container.JuMPmodel
get_name(x::OperationsProblem) = built_for_simulation(x) ? get_simulation_info(x).name : ""

get_optimization_container(problem::OperationsProblem) = problem.internal.container
function get_resolution(problem::OperationsProblem)
    resolution = PSY.get_time_series_resolution(get_system(problem))
    return IS.time_period_conversion(resolution)
end
get_problem_base_power(problem::OperationsProblem) = PSY.get_base_power(problem.sys)
get_settings(problem::OperationsProblem) = get_optimization_container(problem).settings
get_solve_timed_log(problem::OperationsProblem) =
    get_optimization_container(problem).solve_timed_log
get_simulation_info(problem::OperationsProblem) = problem.internal.simulation_info
get_simulation_number(problem::OperationsProblem) = problem.internal.simulation_info.number
get_status(problem::OperationsProblem) = problem.internal.status
get_system(problem::OperationsProblem) = problem.sys
get_template(problem::OperationsProblem) = problem.template
get_output_dir(problem::OperationsProblem) = problem.internal.output_dir
get_variables(problem::OperationsProblem) = get_optimization_container(problem).variables
get_parameters(problem::OperationsProblem) = get_optimization_container(problem).parameters
get_duals(problem::OperationsProblem) = get_optimization_container(problem).duals

get_run_status(problem::OperationsProblem) = problem.internal.run_status
set_run_status!(problem::OperationsProblem, status) = problem.internal.run_status = status
get_time_series_cache(problem::OperationsProblem) = problem.internal.time_series_cache
empty_time_series_cache!(x::OperationsProblem) = empty!(get_time_series_cache(x))
