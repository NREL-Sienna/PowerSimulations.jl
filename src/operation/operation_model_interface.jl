# Default implementations of getter/setter functions for OperationsModel.
is_built(problem::OperationsModel) = model.internal.status == BuildStatus.BUILT
is_empty(problem::OperationsModel) = model.internal.status == BuildStatus.EMPTY
warm_start_enabled(problem::OperationsModel) =
    get_warm_start(get_optimization_container(model).settings)
built_for_simulation(problem::OperationsModel) = get_simulation_info(model) !== nothing
get_caches(x::OperationsModel) =
    built_for_simulation(x) ? get_simulation_info(x).caches : nothing
get_constraints(problem::OperationsModel) = get_internal(model).container.constraints
get_end_of_interval_step(problem::OperationsModel) =
    get_simulation_info(model).end_of_interval_step
get_execution_count(problem::OperationsModel) =
    get_simulation_info(model).execution_count
get_executions(problem::OperationsModel) = get_simulation_info(model).executions
get_initial_time(problem::OperationsModel) = get_initial_time(get_settings(model))
get_horizon(problem::OperationsModel) = get_horizon(get_settings(model))
get_internal(problem::OperationsModel) = problem.internal
get_jump_model(problem::OperationsModel) = get_internal(model).container.JuMPmodel
get_name(x::OperationsModel) = built_for_simulation(x) ? get_simulation_info(x).name : ""

get_optimization_container(problem::OperationsModel) = model.internal.container
function get_resolution(problem::OperationsModel)
    resolution = PSY.get_time_series_resolution(get_system(model))
    return IS.time_period_conversion(resolution)
end
get_problem_base_power(problem::OperationsModel) = PSY.get_base_power(problem.sys)
get_settings(problem::OperationsModel) = get_optimization_container(model).settings
get_solve_timed_log(problem::OperationsModel) =
    get_optimization_container(model).solve_timed_log
get_simulation_info(problem::OperationsModel) = model.internal.simulation_info
get_simulation_number(problem::OperationsModel) = model.internal.simulation_info.number
get_status(problem::OperationsModel) = model.internal.status
get_system(problem::OperationsModel) = problem.sys
get_template(problem::OperationsModel) = problem.template
get_output_dir(problem::OperationsModel) = model.internal.output_dir
get_variables(problem::OperationsModel) = get_optimization_container(model).variables
get_parameters(problem::OperationsModel) = get_optimization_container(model).parameters
get_duals(problem::OperationsModel) = get_optimization_container(model).duals

get_run_status(problem::OperationsModel) = model.internal.run_status
set_run_status!(problem::OperationsModel, status) = model.internal.run_status = status
get_time_series_cache(problem::OperationsModel) = model.internal.time_series_cache
empty_time_series_cache!(x::OperationsModel) = empty!(get_time_series_cache(x))
