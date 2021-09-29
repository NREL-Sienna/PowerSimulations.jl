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
get_recorder_dir(model::OperationModel) = joinpath(model.internal.output_dir, "recorder")
get_variables(model::OperationModel) = get_variables(get_optimization_container(model))
get_parameters(model::OperationModel) = get_parameters(get_optimization_container(model))
get_duals(model::OperationModel) = get_duals(get_optimization_container(model))
get_initial_conditions(model::OperationModel) =
    get_initial_conditions(get_optimization_container(model))

get_interval(model::OperationModel) = model.internal.store_parameters.interval
get_run_status(model::OperationModel) = model.internal.run_status
set_run_status!(model::OperationModel, status) = model.internal.run_status = status
get_time_series_cache(model::OperationModel) = model.internal.time_series_cache
empty_time_series_cache!(x::OperationModel) = empty!(get_time_series_cache(x))

function get_current_timestamp(model::OperationModel)
    # For EmulationModel interval and resolution are the same.
    # TODO: make a field to store an updated timestamp
    return get_initial_time(model) + get_execution_count(model) * get_interval(model)
end

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

function build_initial_conditions!(model::OperationModel)
    @assert model.internal.ic_model_container === nothing
    requires_init = false
    for (device_type, device_model) in get_device_models(get_template(model))
        requires_init = requires_initialization(get_formulation(device_model)())
        if requires_init
            @debug "initial_conditions required for $device_type"
            build_initial_conditions_problem!(model)
            break
        end
    end
    if !requires_init
        @info "No initial conditions in the model"
    end
    return
end

function write_initial_conditions_data(model::OperationModel)
    write_initial_conditions_data(
        get_optimization_container(model),
        model.internal.ic_model_container,
    )
    return
end

function initialize!(model::OperationModel)
    container = get_optimization_container(model)
    if model.internal.ic_model_container === nothing
        return
    end
    @info "Solving initial_conditions Model"
    solve_impl!(model.internal.ic_model_container, get_system(model), Dict{Symbol, Any}())

    write_initial_conditions_data(container, model.internal.ic_model_container)
    return
end

function build_impl!(model::OperationModel)
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Problem $(get_name(model))" begin
        try
            build_pre_step!(model)
            build_problem!(model)
            init_model_store!(model)
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

function build_if_not_already_built!(model; kwargs...)
    if !is_built(model)
        if !haskey(kwargs, :output_dir)
            error(
                "'output_dir' must be provided as a kwarg if the model build status is $(get_status(model))",
            )
        else
            new_kwargs = Dict(k => v for (k, v) in kwargs if k != :optimizer)
            status = build!(model; new_kwargs...)
            if status != BuildStatus.BUILT
                error("build! of the $(typeof(model)) failed: $status")
            end
        end
    end
end

function _check_numerical_bounds(model::OperationModel)
    variable_bounds = get_variable_numerical_bounds(model)
    if variable_bounds.bounds.max - variable_bounds.bounds.min > 1e9
        @warn "Variable bounds range is $(variable_bounds.bounds.max - variable_bounds.bounds.min) and can result in numerical problems for the solver. \\
        max_bound_variable = $(encode_key_as_string(variable_bounds.bounds.max_index)) \\
        min_bound_variable = $(encode_key_as_string(variable_bounds.bounds.min_index)) \\
        Run get_detailed_variable_numerical_bounds on the model for a deeper analysis"
    else
        @info "Variable bounds [$(variable_bounds.bounds.min) $(variable_bounds.bounds.max)]"
    end

    constraint_bounds = get_constraint_numerical_bounds(model)
    if constraint_bounds.coefficient.max - constraint_bounds.coefficient.min > 1e9
        @warn "Constraint coefficient bounds range is $(constraint_bounds.coefficient.max - constraint_bounds.coefficient.min) and can result in numerical problems for the solver. \\
        max_bound_constraint = $(encode_key_as_string(constraint_bounds.coefficient.max_index)) \\
        min_bound_constraint = $(encode_key_as_string(constraint_bounds.coefficient.min_index)) \\
        Run get_detailed_constraint_numerical_bounds on the model for a deeper analysis"
    else
        @info "Constraint coefficient bounds [$(constraint_bounds.coefficient.min) $(constraint_bounds.coefficient.max)]"
    end

    if constraint_bounds.rhs.max - constraint_bounds.rhs.min > 1e9
        @warn "Constraint right-hand-side bounds range is $(constraint_bounds.rhs.max - constraint_bounds.rhs.min) and can result in numerical problems for the solver. \\
        max_bound_constraint = $(encode_key_as_string(constraint_bounds.rhs.max_index)) \\
        min_bound_constraint = $(encode_key_as_string(constraint_bounds.rhs.min_index)) \\
        Run get_detailed_constraint_numerical_bounds on the model for a deeper analysis"
    else
        @info "Constraint right-hand-side bounds [$(constraint_bounds.rhs.min) $(constraint_bounds.rhs.max)]"
    end
    return
end

function _pre_solve_model_checks(model::OperationModel, optimizer)
    jump_model = get_jump_model(model)
    if optimizer !== nothing
        JuMP.set_optimizer(jump_model, optimizer)
    end

    if jump_model.moi_backend.state == MOIU.NO_OPTIMIZER
        error("No Optimizer has been defined, can't solve the operational problem")
    end

    optimizer_name = JuMP.solver_name(jump_model)
    _check_numerical_bounds(model)
    @info "Solving $(typeof(model)) with optimizer = $optimizer_name"
    @info "Solver backend: $(JuMP.backend(jump_model))"

    return
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

function add_recorders!(model::OperationModel, recorders)
    internal = get_internal(model)
    for name in union(REQUIRED_RECORDERS, recorders)
        add_recorder!(internal, name)
    end
end

function register_recorders!(model::OperationModel, file_mode)
    recorder_dir = get_recorder_dir(model)
    mkpath(recorder_dir)
    for name in get_recorders(get_internal(model))
        IS.register_recorder!(name; mode = file_mode, directory = recorder_dir)
    end
end

function unregister_recorders!(model::OperationModel)
    for name in get_recorders(get_internal(model))
        IS.unregister_recorder!(name)
    end
end

const _JUMP_MODEL_FILENAME = "jump_model.json"

function serialize_optimization_model(model::OperationModel)
    serialize_optimization_model(
        get_optimization_container(model),
        joinpath(get_output_dir(model), _JUMP_MODEL_FILENAME),
    )
    return
end
