# Default implementations of getter/setter functions for OperationModel.
is_built(model::OperationModel) = model.internal.status == BuildStatus.BUILT
is_empty(model::OperationModel) = model.internal.status == BuildStatus.EMPTY
warm_start_enabled(model::OperationModel) =
    get_warm_start(get_optimization_container(model).settings)
built_for_recurrent_solves(model::OperationModel) =
    get_optimization_container(model).built_for_recurrent_solves
#get_caches(x::OperationModel) =
#    built_for_recurrent_solves(x) ? get_simulation_info(x).caches : nothing
get_constraints(model::OperationModel) = get_internal(model).container.constraints
get_execution_count(model::OperationModel) = get_internal(model).execution_count
get_executions(model::OperationModel) = get_internal(model).executions
get_initial_time(model::OperationModel) = get_initial_time(get_settings(model))
get_internal(model::OperationModel) = model.internal
get_jump_model(model::OperationModel) = get_internal(model).container.JuMPmodel
get_name(model::OperationModel) = model.name
get_store(model::OperationModel) = model.store

get_optimization_container(model::OperationModel) = get_internal(model).container
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
get_variables(model::OperationModel) = get_variables(get_optimization_container(model))
get_parameters(model::OperationModel) = get_parameters(get_optimization_container(model))
get_duals(model::OperationModel) = get_duals(get_optimization_container(model))
get_initial_conditions(model::OperationModel) =
    get_initial_conditions(get_optimization_container(model))

get_run_status(model::OperationModel) = model.internal.run_status
set_run_status!(model::OperationModel, status) = model.internal.run_status = status
get_time_series_cache(model::OperationModel) = model.internal.time_series_cache
empty_time_series_cache!(x::OperationModel) = empty!(get_time_series_cache(x))

function get_timestamps(model::OperationModel)
    start_time = get_initial_time(get_optimization_container(model))
    resolution = get_resolution(model)
    horizon = get_horizon(model)
    return range(start_time, length = horizon, step = resolution)
end

function write_data(model::OperationModel, output_dir::AbstractString; kwargs...)
    write_data(get_optimization_container(model), output_dir; kwargs...)
    return
end

function get_initial_conditions(
    model::OperationModel,
    ic::InitialConditionType,
    device::PSY.Device,
)
    return get_initial_conditions(get_optimization_container(model), ICKey(ic, device))
end

set_console_level!(model::OperationModel, val) = get_internal(model).console_level = val
set_file_level!(model::OperationModel, val) = get_internal(model).file_level = val
set_executions!(model::OperationModel, val::Int) = model.internal.executions = val
set_execution_count!(model::OperationModel, val::Int) =
    get_internal(model).execution_count = val
set_initial_time!(model::OperationModel, val::Dates.DateTime) =
    set_initial_time!(get_settings(model), val)
set_simulation_info!(model::OperationModel, info) = model.internal.simulation_info = info
function set_status!(model::OperationModel, status::BuildStatus)
    model.internal.status = status
    return
end
set_output_dir!(model::OperationModel, path::AbstractString) =
    get_internal(model).output_dir = path

function advance_execution_count!(model::OperationModel)
    internal = get_internal(model)
    internal.execution_count += 1
    # Reset execution count at the end of step
    #if get_execution_count(model) == get_executions(model)
    #    internal.execution_count = 0
    #end
    return
end

function write_initialization_data(model::OperationModel)
    write_initialization_data(
        get_optimization_container(model),
        model.internal.ic_model_container,
    )
    return
end

function build_impl!(model::OperationModel, serialize::Bool)
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Problem $(get_name(model))" begin
        try
            build_pre_step!(model)
            build_problem!(model)
            init_model_store!(model)
            if serialize
                serialize_problem(model)
                serialize_optimization_model(model)
            end
            serialize_metadata!(get_optimization_container(model), get_output_dir(model))
            set_status!(model, BuildStatus.BUILT)
            log_values(get_settings(model))
            !built_for_recurrent_solves(model) && @info "\n$(BUILD_PROBLEMS_TIMER)\n"
        catch e
            set_status!(model, BuildStatus.FAILED)
            bt = catch_backtrace()
            @error "Operation Problem Build Failed" exception = e, bt
        end
    end
    return get_status(model)
end

function _pre_solve_model_checks(model::OperationModel, optimizer; kwargs...)
    if !is_built(model)
        if !haskey(kwargs, :output_dir)
            error(
                "'output_dir' must be provided as a kwarg if the model build status is $(get_status(model))",
            )
        else
            status = build!(model; kwargs...)
            if status != BuildStatus.BUILT
                error("build! of the $(typeof(model)) failed: $status")
            end
        end
    end
    jump_model = get_jump_model(model)
    if optimizer !== nothing
        JuMP.set_optimizer(jump_model, optimizer)
    end
    if jump_model.moi_backend.state == MOIU.NO_OPTIMIZER
        @error("No Optimizer has been defined, can't solve the operational problem")
        return RunStatus.FAILED
    end
    @assert jump_model.moi_backend.state != MOIU.NO_OPTIMIZER
    return RunStatus.RUNNING
end

# TODO v015: DecisionModel needs to implement a store and the method get_store
# in order for the methods below to work.

list_aux_variable_keys(x::OperationModel) =
    list_keys(get_store(x), STORE_CONTAINER_AUX_VARIABLES)
list_aux_variable_names(x::OperationModel) = _list_names(x, STORE_CONTAINER_AUX_VARIABLES)
list_variable_keys(x::OperationModel) = list_keys(get_store(x), STORE_CONTAINER_VARIABLES)
list_variable_names(x::OperationModel) = _list_names(x, STORE_CONTAINER_VARIABLES)
list_parameter_keys(x::OperationModel) = list_keys(get_store(x), STORE_CONTAINER_PARAMETERS)
list_parameter_names(x::OperationModel) = _list_names(x, STORE_CONTAINER_PARAMETERS)
list_dual_keys(x::OperationModel) = list_keys(get_store(x), STORE_CONTAINER_DUALS)
list_dual_names(x::OperationModel) = _list_names(x, STORE_CONTAINER_DUALS)

function _list_names(model::OperationModel, container_type)
    return encode_keys_as_strings(list_keys(get_store(model), container_type))
end

function read_dual(model::OperationModel, key::ConstraintKey)
    return read_results(get_store(model), STORE_CONTAINER_DUALS, key)
end

function read_parameter(model::OperationModel, key::ParameterKey)
    return read_results(get_store(model), STORE_CONTAINER_PARAMETERS, key)
end

function read_aux_variable(model::OperationModel, key::AuxVarKey)
    return read_results(get_store(model), STORE_CONTAINER_AUX_VARIABLES, key)
end

function read_variable(model::OperationModel, key::VariableKey)
    return read_results(get_store(model), STORE_CONTAINER_VARIABLES, key)
end

read_optimizer_stats(model::OperationModel) = read_optimizer_stats(get_store(model))

const _JUMP_MODEL_FILENAME = "jump_model.json"

function serialize_optimization_model(model::OperationModel)
    serialize_optimization_model(
        get_optimization_container(model),
        joinpath(get_output_dir(model), _JUMP_MODEL_FILENAME),
    )
    return
end
