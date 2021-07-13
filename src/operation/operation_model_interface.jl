# Default implementations of getter/setter functions for OperationModel.
is_built(model::OperationModel) = model.internal.status == BuildStatus.BUILT
is_empty(model::OperationModel) = model.internal.status == BuildStatus.EMPTY
warm_start_enabled(model::OperationModel) =
    get_warm_start(get_optimization_container(model).settings)
built_for_simulation(model::OperationModel) = get_simulation_info(model) !== nothing
get_caches(x::OperationModel) =
    built_for_simulation(x) ? get_simulation_info(x).caches : nothing
get_constraints(model::OperationModel) = get_internal(model).container.constraints
get_end_of_interval_step(model::OperationModel) =
    get_simulation_info(model).end_of_interval_step
get_execution_count(model::OperationModel) = get_simulation_info(model).execution_count
get_executions(model::OperationModel) = get_simulation_info(model).executions
get_initial_time(model::OperationModel) = get_initial_time(get_settings(model))
get_horizon(model::OperationModel) = get_horizon(get_settings(model))
get_internal(model::OperationModel) = model.internal
get_jump_model(model::OperationModel) = get_internal(model).container.JuMPmodel
get_name(x::OperationModel) = built_for_simulation(x) ? get_simulation_info(x).name : ""

get_optimization_container(model::OperationModel) = model.internal.container
function get_resolution(model::OperationModel)
    resolution = PSY.get_time_series_resolution(get_system(model))
    return IS.time_period_conversion(resolution)
end
get_problem_base_power(model::OperationModel) = PSY.get_base_power(model.sys)
get_settings(model::OperationModel) = get_optimization_container(model).settings
get_solve_timed_log(model::OperationModel) =
    get_optimization_container(model).solve_timed_log
get_simulation_info(model::OperationModel) = model.internal.simulation_info
get_simulation_number(model::OperationModel) = model.internal.simulation_info.number
get_status(model::OperationModel) = model.internal.status
get_system(model::OperationModel) = model.sys
get_template(model::OperationModel) = model.template
get_output_dir(model::OperationModel) = model.internal.output_dir
get_variables(model::OperationModel) = get_optimization_container(model).variables
get_parameters(model::OperationModel) = get_optimization_container(model).parameters
get_duals(model::OperationModel) = get_optimization_container(model).duals

get_run_status(model::OperationModel) = model.internal.run_status
set_run_status!(model::OperationModel, status) = model.internal.run_status = status
get_time_series_cache(model::OperationModel) = model.internal.time_series_cache
empty_time_series_cache!(x::OperationModel) = empty!(get_time_series_cache(x))
