"""
Abstract type for models than employ PowerSimulations methods. For custom decision problems
    use DecisionProblem as the super type.
"""
abstract type DefaultDecisionProblem <: DecisionProblem end

"""
Generic PowerSimulations Operation Problem Type for unspecified models
"""
struct GenericOpProblem <: DefaultDecisionProblem end

mutable struct DecisionModel{M <: DecisionProblem} <: OperationModel
    name::Symbol
    template::AbstractProblemTemplate
    sys::PSY.System
    internal::Union{Nothing, ModelInternal}
    store::DecisionModelStore
    ext::Dict{String, Any}
end

"""
    DecisionModel{M}(
        template::AbstractProblemTemplate,
        sys::PSY.System,
        jump_model::Union{Nothing, JuMP.Model}=nothing;
        kwargs...) where {M<:DecisionProblem}

Build the optimization problem of type M with the specific system and template.

# Arguments

  - `::Type{M} where M<:DecisionProblem`: The abstract operation model type
  - `template::AbstractProblemTemplate`: The model reference made up of transmission, devices, branches, and services.
  - `sys::PSY.System`: the system created using Power Systems
  - `jump_model::Union{Nothing, JuMP.Model}`: Enables passing a custom JuMP model. Use with care
  - `name = nothing`: name of model, string or symbol; defaults to the type of template converted to a symbol.
  - `optimizer::Union{Nothing,MOI.OptimizerWithAttributes} = nothing` : The optimizer does
    not get serialized. Callers should pass whatever they passed to the original problem.
  - `horizon::Int = UNSET_HORIZON`: Manually specify the length of the forecast Horizon
  - `warm_start::Bool = true`: True will use the current operation point in the system to initialize variable values. False initializes all variables to zero. Default is true
  - `system_to_file::Bool = true:`: True to create a copy of the system used in the model.
  - `initialize_model::Bool = true`: Option to decide to initialize the model or not.
  - `initialization_file::String = ""`: This allows to pass pre-existing initialization values to avoid the solution of an optimization problem to find feasible initial conditions.
  - `deserialize_initial_conditions::Bool = false`: Option to deserialize conditions
  - `export_pwl_vars::Bool = false`: True to export all the pwl intermediate variables. It can slow down significantly the build and solve time.
  - `allow_fails::Bool = false`: True to allow the simulation to continue even if the optimization step fails. Use with care.
  - `optimizer_solve_log_print::Bool = false`: Uses JuMP.unset_silent() to print the optimizer's log. By default all solvers are set to MOI.Silent()
  - `detailed_optimizer_stats::Bool = false`: True to save detailed optimizer stats log.
  - `calculate_conflict::Bool = false`: True to use solver to calculate conflicts for infeasible problems. Only specific solvers are able to calculate conflicts.
  - `direct_mode_optimizer::Bool = false`: True to use the solver in direct mode. Creates a [JuMP.direct_model](https://jump.dev/JuMP.jl/dev/reference/models/#JuMP.direct_model).
  - `store_variable_names::Bool = false`: to store variable names in optimization model. Decreases the build times.
  - `rebuild_model::Bool = false`: It will force the rebuild of the underlying JuMP model with each call to update the model. It increases solution times, use only if the model can't be updated in memory.
  - `initial_time::Dates.DateTime = UNSET_INI_TIME`: Initial Time for the model solve.
  - `time_series_cache_size::Int = IS.TIME_SERIES_CACHE_SIZE_BYTES`: Size in bytes to cache for each time array. Default is 1 MiB. Set to 0 to disable.

# Example

```julia
template = ProblemTemplate(CopperPlatePowerModel, devices, branches, services)
OpModel = DecisionModel(MockOperationProblem, template, system)
```
"""
function DecisionModel{M}(
    template::AbstractProblemTemplate,
    sys::PSY.System,
    settings::Settings,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    name = nothing,
) where {M <: DecisionProblem}
    if name === nothing
        name = nameof(M)
    elseif name isa String
        name = Symbol(name)
    end
    internal = ModelInternal(
        OptimizationContainer(sys, settings, jump_model, PSY.Deterministic),
    )
    template_ = deepcopy(template)
    finalize_template!(template_, sys)
    return DecisionModel{M}(
        name,
        template_,
        sys,
        internal,
        DecisionModelStore(),
        Dict{String, Any}(),
    )
end

function DecisionModel{M}(
    template::AbstractProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    name = nothing,
    optimizer = nothing,
    horizon = UNSET_HORIZON,
    warm_start = true,
    system_to_file = true,
    initialize_model = true,
    initialization_file = "",
    deserialize_initial_conditions = false,
    export_pwl_vars = false,
    allow_fails = false,
    optimizer_solve_log_print = false,
    detailed_optimizer_stats = false,
    calculate_conflict = false,
    direct_mode_optimizer = false,
    store_variable_names = false,
    rebuild_model = false,
    check_numerical_bounds = true,
    initial_time = UNSET_INI_TIME,
    time_series_cache_size::Int = IS.TIME_SERIES_CACHE_SIZE_BYTES,
) where {M <: DecisionProblem}
    settings = Settings(
        sys;
        horizon = horizon,
        initial_time = initial_time,
        optimizer = optimizer,
        time_series_cache_size = time_series_cache_size,
        warm_start = warm_start,
        system_to_file = system_to_file,
        initialize_model = initialize_model,
        initialization_file = initialization_file,
        deserialize_initial_conditions = deserialize_initial_conditions,
        export_pwl_vars = export_pwl_vars,
        allow_fails = allow_fails,
        calculate_conflict = calculate_conflict,
        optimizer_solve_log_print = optimizer_solve_log_print,
        detailed_optimizer_stats = detailed_optimizer_stats,
        direct_mode_optimizer = direct_mode_optimizer,
        check_numerical_bounds = check_numerical_bounds,
        store_variable_names = store_variable_names,
        rebuild_model = rebuild_model,
    )
    return DecisionModel{M}(template, sys, settings, jump_model; name = name)
end

"""
Build the optimization problem of type M with the specific system and template

# Arguments

  - `::Type{M} where M<:DecisionProblem`: The abstract operation model type
  - `template::AbstractProblemTemplate`: The model reference made up of transmission, devices, branches, and services.
  - `sys::PSY.System`: the system created using Power Systems
  - `jump_model::Union{Nothing, JuMP.Model}` = nothing: Enables passing a custom JuMP model. Use with care.

# Example

```julia
template = ProblemTemplate(CopperPlatePowerModel, devices, branches, services)
problem = DecisionModel(MyOpProblemType, template, system, optimizer)
```
"""
function DecisionModel(
    ::Type{M},
    template::AbstractProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    kwargs...,
) where {M <: DecisionProblem}
    return DecisionModel{M}(template, sys, jump_model; kwargs...)
end

function DecisionModel(
    template::AbstractProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    kwargs...,
)
    return DecisionModel{GenericOpProblem}(template, sys, jump_model; kwargs...)
end

"""
Builds an empty decision model. This constructor is used for the implementation of custom
decision models that do not require a template.

# Arguments

  - `::Type{M} where M<:DecisionProblem`: The abstract operation model type
  - `sys::PSY.System`: the system created using Power Systems
  - `jump_model::Union{Nothing, JuMP.Model}` = nothing: Enables passing a custom JuMP model. Use with care.

# Example

```julia
problem = DecisionModel(system, optimizer)
```
"""
function DecisionModel{M}(
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    kwargs...,
) where {M <: DecisionProblem}
    return DecisionModel{M}(ProblemTemplate(), sys, jump_model; kwargs...)
end

function DecisionModel{M}(
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    kwargs...,
) where {M <: DefaultDecisionProblem}
    IS.ArgumentError(
        "DefaultDecisionProblem subtypes require a template. Use DecisionModel subtyping instead.",
    )
end

"""
Construct an DecisionProblem from a serialized file.

# Arguments

  - `directory::AbstractString`: Directory containing a serialized model
  - `jump_model::Union{Nothing, JuMP.Model}` = nothing: The JuMP model does not get
    serialized. Callers should pass whatever they passed to the original problem.
  - `optimizer::Union{Nothing,MOI.OptimizerWithAttributes}` = nothing: The optimizer does
    not get serialized. Callers should pass whatever they passed to the original problem.
  - `system::Union{Nothing, PSY.System}`: Optionally, the system used for the model.
    If nothing and sys_to_file was set to true when the model was created, the system will
    be deserialized from a file.
"""
function DecisionModel(
    directory::AbstractString,
    optimizer::MOI.OptimizerWithAttributes;
    jump_model::Union{Nothing, JuMP.Model} = nothing,
    system::Union{Nothing, PSY.System} = nothing,
)
    return deserialize_problem(
        DecisionModel,
        directory; 
        jump_model = jump_model,
        optimizer = optimizer,
        system = system,
    )
end

get_problem_type(::DecisionModel{M}) where {M <: DecisionProblem} = M
validate_template(::DecisionModel{<:DecisionProblem}) = nothing
validate_time_series(::DecisionModel{<:DecisionProblem}) = nothing

# Probably could be more efficient by storing the info in the internal
function get_current_time(model::DecisionModel)
    execution_count = get_internal(model).execution_count
    initial_time = get_initial_time(model)
    interval = get_interval(model.internal.store_parameters)
    return initial_time + interval * execution_count
end

function init_model_store_params!(model::DecisionModel)
    num_executions = get_executions(model)
    horizon = get_horizon(model)
    system = get_system(model)
    interval = PSY.get_forecast_interval(system)
    resolution = PSY.get_time_series_resolution(system)
    base_power = PSY.get_base_power(system)
    sys_uuid = IS.get_uuid(system)
    model.internal.store_parameters = ModelStoreParams(
        num_executions,
        horizon,
        iszero(interval) ? resolution : interval,
        resolution,
        base_power,
        sys_uuid,
        get_metadata(get_optimization_container(model)),
    )
    return
end

function validate_time_series(model::DecisionModel{<:DefaultDecisionProblem})
    sys = get_system(model)
    counts = PSY.get_time_series_counts(sys)
    if counts.forecast_count < 1
        error(
            "The system does not contain forecast data. A DecisionModel can't be built.",
        )
    end
    return
end

function build_pre_step!(model::DecisionModel{<:DecisionProblem})
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Build pre-step" begin
        validate_template(model)
        validate_time_series(model)
        if !isempty(model)
            @info "OptimizationProblem status not BuildStatus.EMPTY. Resetting"
            reset!(model)
        end
        # Initial time are set here because the information is specified in the
        # Simulation Sequence object and not at the problem creation.
        @info "Initializing Optimization Container For a DecisionModel"
        init_optimization_container!(
            get_optimization_container(model),
            get_network_model(get_template(model)),
            get_system(model),
        )
        @info "Initializing ModelStoreParams"
        init_model_store_params!(model)
        set_status!(model, BuildStatus.IN_PROGRESS)
    end
    return
end

function build_impl!(model::DecisionModel{<:DecisionProblem})
    build_pre_step!(model)
    @info "Instantiating Network Model"
    instantiate_network_model(model)
    handle_initial_conditions!(model)
    build_model!(model)
    serialize_metadata!(get_optimization_container(model), get_output_dir(model))
    log_values(get_settings(model))
    return
end

get_horizon(model::DecisionModel) = get_horizon(get_settings(model))

"""
Build the Decision Model based on the specified DecisionProblem.

# Arguments

  - `model::DecisionModel{<:DecisionProblem}`: DecisionModel object
  - `output_dir::String`: Output directory for results
  - `recorders::Vector{Symbol} = []`: recorder names to register
  - `console_level = Logging.Error`:
  - `file_level = Logging.Info`:
  - `disable_timer_outputs = false` : Enable/Disable timing outputs
"""
function build!(
    model::DecisionModel{<:DecisionProblem};
    output_dir::String,
    recorders = [],
    console_level = Logging.Error,
    file_level = Logging.Info,
    disable_timer_outputs = false,
)
    mkpath(output_dir)
    set_output_dir!(model, output_dir)
    set_console_level!(model, console_level)
    set_file_level!(model, file_level)
    TimerOutputs.reset_timer!(BUILD_PROBLEMS_TIMER)
    disable_timer_outputs && TimerOutputs.disable_timer!(BUILD_PROBLEMS_TIMER)
    file_mode = "w"
    add_recorders!(model, recorders)
    register_recorders!(model, file_mode)
    logger = configure_logging(model.internal, file_mode)
    try
        Logging.with_logger(logger) do
            try
                TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Problem $(get_name(model))" begin
                    build_impl!(model)
                end
                set_status!(model, BuildStatus.BUILT)
                @info "\n$(BUILD_PROBLEMS_TIMER)\n"
            catch e
                set_status!(model, BuildStatus.FAILED)
                bt = catch_backtrace()
                @error "DecisionModel Build Failed" exception = e, bt
            end
        end
    finally
        unregister_recorders!(model)
        close(logger)
    end
    return get_status(model)
end

"""
Default implementation of build method for Operational Problems for models conforming with
DecisionProblem specification. Overload this function to implement a custom build method
"""
function build_model!(model::DecisionModel{<:DefaultDecisionProblem})
    build_impl!(get_optimization_container(model), get_template(model), get_system(model))
    return
end

function reset!(model::DecisionModel{<:DefaultDecisionProblem})
    was_built_for_recurrent_solves = built_for_recurrent_solves(model)
    if was_built_for_recurrent_solves
        set_execution_count!(model, 0)
    end
    model.internal.container = OptimizationContainer(
        get_system(model),
        get_settings(model),
        nothing,
        PSY.Deterministic,
    )
    model.internal.container.built_for_recurrent_solves = was_built_for_recurrent_solves
    model.internal.ic_model_container = nothing
    empty_time_series_cache!(model)
    empty!(get_store(model))
    set_status!(model, BuildStatus.EMPTY)
    return
end

"""
Default solve method for models that conform to the requirements of
DecisionModel{<: DecisionProblem}.

This will call `build!` on the model if it is not already built. It will forward all
keyword arguments to that function.

# Arguments

  - `model::OperationModel = model`: operation model
  - `export_problem_results::Bool = false`: If true, export ProblemResults DataFrames to CSV files. Reduces solution times during simulation.
  - `console_level = Logging.Error`:
  - `file_level = Logging.Info`:
  - `disable_timer_outputs = false` : Enable/Disable timing outputs
  - `serialize::Bool = true`: If true, serialize the model to a file to allow re-execution later.

# Examples

```julia
results = solve!(OpModel)
results = solve!(OpModel, export_problem_results = true)
```
"""
function solve!(
    model::DecisionModel{<:DecisionProblem};
    export_problem_results = false,
    console_level = Logging.Error,
    file_level = Logging.Info,
    disable_timer_outputs = false,
    serialize = true,
    kwargs...,
)
    build_if_not_already_built!(
        model;
        console_level = console_level,
        file_level = file_level,
        disable_timer_outputs = disable_timer_outputs,
        kwargs...,
    )
    set_console_level!(model, console_level)
    set_file_level!(model, file_level)
    TimerOutputs.reset_timer!(RUN_OPERATION_MODEL_TIMER)
    disable_timer_outputs && TimerOutputs.disable_timer!(RUN_OPERATION_MODEL_TIMER)
    file_mode = "a"
    register_recorders!(model, file_mode)
    logger = configure_logging(model.internal, file_mode)
    optimizer = get(kwargs, :optimizer, nothing)
    try
        Logging.with_logger(logger) do
            try
                initialize_storage!(
                    get_store(model),
                    get_optimization_container(model),
                    model.internal.store_parameters,
                )
                TimerOutputs.@timeit RUN_OPERATION_MODEL_TIMER "Solve" begin
                    _pre_solve_model_checks(model, optimizer)
                    solve_impl!(model)
                    current_time = get_initial_time(model)
                    write_results!(get_store(model), model, current_time, current_time)
                    write_optimizer_stats!(
                        get_store(model),
                        get_optimizer_stats(model),
                        current_time,
                    )
                end
                if serialize
                    TimerOutputs.@timeit RUN_OPERATION_MODEL_TIMER "Serialize" begin
                        serialize_problem(model; optimizer = optimizer)
                        serialize_optimization_model(model)
                    end
                end
                TimerOutputs.@timeit RUN_OPERATION_MODEL_TIMER "Results processing" begin
                    # TODO: This could be more complicated than it needs to be
                    results = ProblemResults(model)
                    serialize_results(results, get_output_dir(model))
                    export_problem_results && export_results(results)
                end
                @info "\n$(RUN_OPERATION_MODEL_TIMER)\n"
            catch e
                @error "Decision Problem solve failed" exception = (e, catch_backtrace())
                set_run_status!(model, RunStatus.FAILED)
            end
        end
    finally
        unregister_recorders!(model)
        close(logger)
    end

    return get_run_status(model)
end

"""
Default solve method for a DecisionModel used inside of a Simulation. Solves problems that conform to the requirements of DecisionModel{<: DecisionProblem}

# Arguments

  - `step::Int`: Simulation Step
  - `model::OperationModel`: operation model
  - `start_time::Dates.DateTime`: Initial Time of the simulation step in Simulation time.
  - `store::SimulationStore`: Simulation output store

# Accepted Key Words

  - `exports`: realtime export of output. Use wisely, it can have negative impacts in the simulation times
"""
function solve!(
    step::Int,
    model::DecisionModel{<:DecisionProblem},
    start_time::Dates.DateTime,
    store::SimulationStore;
    exports = nothing,
)
    # Note, we don't call solve!(decision_model) here because the solve call includes a lot of
    # other logic used when solving the models separate from a simulation
    solve_impl!(model)
    IS.@assert_op get_current_time(model) == start_time
    if get_run_status(model) == RunStatus.SUCCESSFUL
        write_results!(store, model, start_time, start_time; exports = exports)
        write_optimizer_stats!(store, model, start_time)
        advance_execution_count!(model)
    end
    return get_run_status(model)
end

function update_parameters!(
    model::DecisionModel,
    decision_states::DatasetContainer{InMemoryDataset},
)
    cost_function_unsynch(get_optimization_container(model))
    for key in keys(get_parameters(model))
        update_parameter_values!(model, key, decision_states)
    end
    if !is_synchronized(model)
        update_objective_function!(get_optimization_container(model))
        obj_func = get_objective_expression(get_optimization_container(model))
        set_synchronized_status(obj_func, true)
    end
    return
end
