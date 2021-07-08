# Default implementations of getter/setter functions for OperationModel.
is_built(problem::OperationModel) = model.internal.status == BuildStatus.BUILT
is_empty(problem::OperationModel) = model.internal.status == BuildStatus.EMPTY
warm_start_enabled(problem::OperationModel) =
    get_warm_start(get_optimization_container(model).settings)
built_for_simulation(problem::OperationModel) = get_simulation_info(model) !== nothing
get_caches(x::OperationModel) =
    built_for_simulation(x) ? get_simulation_info(x).caches : nothing
get_constraints(problem::OperationModel) = get_internal(model).container.constraints
get_end_of_interval_step(problem::OperationModel) =
    get_simulation_info(model).end_of_interval_step
get_execution_count(problem::OperationModel) = get_simulation_info(model).execution_count
get_executions(problem::OperationModel) = get_simulation_info(model).executions
get_initial_time(problem::OperationModel) = get_initial_time(get_settings(model))
get_horizon(problem::OperationModel) = get_horizon(get_settings(model))
get_internal(problem::OperationModel) = problem.internal
get_jump_model(problem::OperationModel) = get_internal(model).container.JuMPmodel
get_name(x::OperationModel) = built_for_simulation(x) ? get_simulation_info(x).name : ""

get_optimization_container(problem::OperationModel) = model.internal.container
function get_resolution(problem::OperationModel)
    resolution = PSY.get_time_series_resolution(get_system(model))
    return IS.time_period_conversion(resolution)
end
get_problem_base_power(problem::OperationModel) = PSY.get_base_power(problem.sys)
get_settings(problem::OperationModel) = get_optimization_container(model).settings
get_solve_timed_log(problem::OperationModel) =
    get_optimization_container(model).solve_timed_log
get_simulation_info(problem::OperationModel) = model.internal.simulation_info
get_simulation_number(problem::OperationModel) = model.internal.simulation_info.number
get_status(problem::OperationModel) = model.internal.status
get_system(problem::OperationModel) = problem.sys
get_template(problem::OperationModel) = problem.template
get_output_dir(problem::OperationModel) = model.internal.output_dir
get_variables(problem::OperationModel) = get_optimization_container(model).variables
get_parameters(problem::OperationModel) = get_optimization_container(model).parameters
get_duals(problem::OperationModel) = get_optimization_container(model).duals

get_run_status(problem::OperationModel) = model.internal.run_status
set_run_status!(problem::OperationModel, status) = model.internal.run_status = status
get_time_series_cache(problem::OperationModel) = model.internal.time_series_cache
empty_time_series_cache!(x::OperationModel) = empty!(get_time_series_cache(x))
