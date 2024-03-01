"""
Abstract type for models than employ PowerSimulations methods. For custom emulation problems
    use EmulationProblem as the super type.
"""
abstract type DefaultEmulationProblem <: EmulationProblem end

"""
Default PowerSimulations Emulation Problem Type for unspecified problems
"""
struct GenericEmulationProblem <: DefaultEmulationProblem end

"""
    EmulationModel{M}(
        template::AbstractProblemTemplate,
        sys::PSY.System,
        jump_model::Union{Nothing, JuMP.Model}=nothing;
        kwargs...) where {M<:EmulationProblem}

Build the optimization problem of type M with the specific system and template.

# Arguments

  - `::Type{M} where M<:EmulationProblem`: The abstract Emulation model type
  - `template::AbstractProblemTemplate`: The model reference made up of transmission, devices, branches, and services.
  - `sys::PSY.System`: the system created using Power Systems
  - `jump_model::Union{Nothing, JuMP.Model}`: Enables passing a custom JuMP model. Use with care
  - `name = nothing`: name of model, string or symbol; defaults to the type of template converted to a symbol.
  - `optimizer::Union{Nothing,MOI.OptimizerWithAttributes} = nothing` : The optimizer does
    not get serialized. Callers should pass whatever they passed to the original problem.
  - `warm_start::Bool = true`: True will use the current operation point in the system to initialize variable values. False initializes all variables to zero. Default is true
  - `system_to_file::Bool = true:`: True to create a copy of the system used in the model.
  - `initialize_model::Bool = true`: Option to decide to initialize the model or not.
  - `initialization_file::String = ""`: This allows to pass pre-existing initialization values to avoid the solution of an optimization problem to find feasible initial conditions.
  - `deserialize_initial_conditions::Bool = false`: Option to deserialize conditions
  - `export_pwl_vars::Bool = false`: True to export all the pwl intermediate variables. It can slow down significantly the build and solve time.
  - `allow_fails::Bool = false`: True to allow the simulation to continue even if the optimization step fails. Use with care.
  - `calculate_conflict::Bool = false`: True to use solver to calculate conflicts for infeasible problems. Only specific solvers are able to calculate conflicts.
  - `optimizer_solve_log_print::Bool = false`: Uses JuMP.unset_silent() to print the optimizer's log. By default all solvers are set to MOI.Silent()
  - `detailed_optimizer_stats::Bool = false`: True to save detailed optimizer stats log.
  - `direct_mode_optimizer::Bool = false`: True to use the solver in direct mode. Creates a [JuMP.direct_model](https://jump.dev/JuMP.jl/dev/reference/models/#JuMP.direct_model).
  - `store_variable_names::Bool = false`: True to store variable names in optimization model.
  - `rebuild_model::Bool = false`: It will force the rebuild of the underlying JuMP model with each call to update the model. It increases solution times, use only if the model can't be updated in memory.
  - `initial_time::Dates.DateTime = UNSET_INI_TIME`: Initial Time for the model solve.
  - `time_series_cache_size::Int = IS.TIME_SERIES_CACHE_SIZE_BYTES`: Size in bytes to cache for each time array. Default is 1 MiB. Set to 0 to disable.

# Example

```julia
template = ProblemTemplate(CopperPlatePowerModel, devices, branches, services)
OpModel = EmulationModel(MockEmulationProblem, template, system)
```
"""
mutable struct EmulationModel{M <: EmulationProblem} <: OperationModel
    name::Symbol
    template::AbstractProblemTemplate
    sys::PSY.System
    internal::IS.ModelInternal
    store::EmulationModelStore # might be extended to other stores for simulation
    ext::Dict{String, Any}

    function EmulationModel{M}(
        template::AbstractProblemTemplate,
        sys::PSY.System,
        settings::Settings,
        jump_model::Union{Nothing, JuMP.Model} = nothing;
        name = nothing,
    ) where {M <: EmulationProblem}
        if name === nothing
            name = nameof(M)
        elseif name isa String
            name = Symbol(name)
        end
        finalize_template!(template, sys)
        internal = IS.ModelInternal(
            OptimizationContainer(sys, settings, jump_model, PSY.SingleTimeSeries),
        )
        new{M}(name, template, sys, internal, EmulationModelStore(), Dict{String, Any}())
    end
end

function EmulationModel{M}(
    template::AbstractProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    name = nothing,
    optimizer = nothing,
    warm_start = true,
    system_to_file = true,
    initialize_model = true,
    initialization_file = "",
    deserialize_initial_conditions = false,
    export_pwl_vars = false,
    allow_fails = false,
    calculate_conflict = false,
    optimizer_solve_log_print = false,
    detailed_optimizer_stats = false,
    direct_mode_optimizer = false,
    check_numerical_bounds = true,
    store_variable_names = false,
    rebuild_model = false,
    initial_time = UNSET_INI_TIME,
    time_series_cache_size::Int = IS.TIME_SERIES_CACHE_SIZE_BYTES,
) where {M <: EmulationProblem}
    settings = Settings(
        sys;
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
        horizon = 1,
    )
    return EmulationModel{M}(template, sys, settings, jump_model; name = name)
end

"""
Build the optimization problem of type M with the specific system and template

# Arguments

  - `::Type{M} where M<:EmulationProblem`: The abstract Emulation model type
  - `template::AbstractProblemTemplate`: The model reference made up of transmission, devices,
    branches, and services.
  - `sys::PSY.System`: the system created using Power Systems
  - `jump_model::Union{Nothing, JuMP.Model}`: Enables passing a custom JuMP model. Use with care

# Example

```julia
template = ProblemTemplate(CopperPlatePowerModel, devices, branches, services)
problem = EmulationModel(MyEmProblemType, template, system, optimizer)
```
"""
function EmulationModel(
    ::Type{M},
    template::AbstractProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    kwargs...,
) where {M <: EmulationProblem}
    return EmulationModel{M}(template, sys, jump_model; kwargs...)
end

function EmulationModel(
    template::AbstractProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    kwargs...,
)
    return EmulationModel{GenericEmulationProblem}(template, sys, jump_model; kwargs...)
end

"""
Builds an empty emulation model. This constructor is used for the implementation of custom
emulation models that do not require a template.

# Arguments

  - `::Type{M} where M<:EmulationProblem`: The abstract operation model type
  - `sys::PSY.System`: the system created using Power Systems
  - `jump_model::Union{Nothing, JuMP.Model}` = nothing: Enables passing a custom JuMP model. Use with care.

# Example

```julia
problem = EmulationModel(system, optimizer)
```
"""
function EmulationModel{M}(
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    kwargs...,
) where {M <: EmulationProblem}
    return EmulationModel{M}(template, sys, jump_model; kwargs...)
end

"""
Construct an EmulationProblem from a serialized file.

# Arguments

  - `directory::AbstractString`: Directory containing a serialized model.
  - `optimizer::MOI.OptimizerWithAttributes`: The optimizer does not get serialized.
    Callers should pass whatever they passed to the original problem.
  - `jump_model::Union{Nothing, JuMP.Model}` = nothing: The JuMP model does not get
    serialized. Callers should pass whatever they passed to the original problem.
  - `system::Union{Nothing, PSY.System}`: Optionally, the system used for the model.
    If nothing and sys_to_file was set to true when the model was created, the system will
    be deserialized from a file.
"""
function EmulationModel(
    directory::AbstractString,
    optimizer::MOI.OptimizerWithAttributes;
    jump_model::Union{Nothing, JuMP.Model} = nothing,
    system::Union{Nothing, PSY.System} = nothing,
    kwargs...,
)
    return deserialize_problem(
        EmulationModel,
        directory;
        jump_model = jump_model,
        optimizer = optimizer,
        system = system,
    )
end

get_problem_type(::EmulationModel{M}) where {M <: EmulationProblem} = M
validate_template(::EmulationModel{<:EmulationProblem}) = nothing
validate_time_series(::EmulationModel{<:EmulationProblem}) = nothing

function get_current_time(model::EmulationModel)
    execution_count = get_internal(model).execution_count
    initial_time = get_initial_time(model)
    resolution = get_resolution(model.internal.store_parameters)
    return initial_time + resolution * execution_count
end

function init_model_store_params!(model::EmulationModel)
    num_executions = get_executions(model)
    system = get_system(model)
    interval = resolution = PSY.get_time_series_resolution(system)
    base_power = PSY.get_base_power(system)
    sys_uuid = IS.get_uuid(system)
    model.internal.store_parameters = ModelStoreParams(
        num_executions,
        1,
        interval,
        resolution,
        base_power,
        sys_uuid,
        get_metadata(get_optimization_container(model)),
    )
    return
end

function validate_time_series(model::EmulationModel{<:DefaultEmulationProblem})
    sys = get_system(model)
    counts = PSY.get_time_series_counts(sys)
    if counts.static_time_series_count < 1
        error(
            "The system does not contain Static TimeSeries data. An Emulation model can't be formulated.",
        )
    end
    return
end

function build_pre_step!(model::EmulationModel)
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Build pre-step" begin
        validate_template(model)
        validate_time_series(model)
        if !isempty(model)
            @info "EmulationProblem status not BuildStatus.EMPTY. Resetting"
            reset!(model)
        end
        container = get_optimization_container(model)
        container.built_for_recurrent_solves = true

        @info "Initializing Optimization Container For an EmulationModel"
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

function build_impl!(model::EmulationModel{<:EmulationProblem})
    build_pre_step!(model)
    @info "Instantiating Network Model"
    instantiate_network_model(model)
    handle_initial_conditions!(model)
    build_model!(model)
    serialize_metadata!(get_optimization_container(model), get_output_dir(model))
    log_values(get_settings(model))
    return
end

"""
Implementation of build for any EmulationProblem
"""
function build!(
    model::EmulationModel{<:EmulationProblem};
    executions = 1,
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
                set_executions!(model, executions)
                TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Problem $(get_name(model))" begin
                    build_impl!(model)
                end
                set_status!(model, BuildStatus.BUILT)
                @info "\n$(BUILD_PROBLEMS_TIMER)\n"
            catch e
                set_status!(model, BuildStatus.FAILED)
                bt = catch_backtrace()
                @error "EmulationModel Build Failed" exception = e, bt
            end
        end
    finally
        unregister_recorders!(model)
        close(logger)
    end
    return get_status(model)
end

"""
Default implementation of build method for Emulation Problems for models conforming with  DecisionProblem specification. Overload this function to implement a custom build method
"""
function build_model!(model::EmulationModel{<:EmulationProblem})
    container = get_optimization_container(model)
    system = get_system(model)
    build_impl!(container, get_template(model), system)
    return
end

function reset!(model::EmulationModel{<:EmulationProblem})
    if built_for_recurrent_solves(model)
        set_execution_count!(model, 0)
    end
    model.internal.container = OptimizationContainer(
        get_system(model),
        get_settings(model),
        nothing,
        PSY.SingleTimeSeries,
    )
    model.internal.ic_model_container = nothing
    empty_time_series_cache!(model)
    empty!(get_store(model))
    set_status!(model, BuildStatus.EMPTY)
    return
end

function update_parameters!(model::EmulationModel, store::EmulationModelStore)
    update_parameters!(model, store.data_container)
    return
end

function update_parameters!(model::EmulationModel, data::DatasetContainer{InMemoryDataset})
    cost_function_unsynch(get_optimization_container(model))
    for key in keys(get_parameters(model))
        update_parameter_values!(model, key, data)
    end
    if !is_synchronized(model)
        update_objective_function!(get_optimization_container(model))
        obj_func = get_objective_expression(get_optimization_container(model))
        set_synchronized_status(obj_func, true)
    end
    return
end

function update_initial_conditions!(
    model::EmulationModel,
    source::EmulationModelStore,
    ::InterProblemChronology,
)
    for key in keys(get_initial_conditions(model))
        update_initial_conditions!(model, key, source)
    end
    return
end

function update_model!(
    model::EmulationModel,
    source::EmulationModelStore,
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

function update_model!(model::EmulationModel)
    update_model!(model, get_store(model), InterProblemChronology())
    return
end

function run_impl!(
    model::EmulationModel;
    optimizer = nothing,
    enable_progress_bar = progress_meter_enabled(),
    kwargs...,
)
    _pre_solve_model_checks(model, optimizer)
    internal = get_internal(model)
    # Temporary check. Needs better way to manage re-runs of the same model
    if internal.execution_count > 0
        error("Call build! again")
    end
    prog_bar = ProgressMeter.Progress(internal.executions; enabled = enable_progress_bar)
    initial_time = get_initial_time(model)
    for execution in 1:(internal.executions)
        TimerOutputs.@timeit RUN_OPERATION_MODEL_TIMER "Run execution" begin
            solve_impl!(model)
            current_time = initial_time + (execution - 1) * PSI.get_resolution(model)
            write_results!(get_store(model), model, execution, current_time)
            write_optimizer_stats!(get_store(model), get_optimizer_stats(model), execution)
            advance_execution_count!(model)
            update_model!(model)
            ProgressMeter.update!(
                prog_bar,
                get_execution_count(model);
                showvalues = [(:Execution, execution)],
            )
        end
    end
    return
end

"""
Default run method for problems that conform to the requirements of
EmulationModel{<: EmulationProblem}

This will call `build!` on the model if it is not already built. It will forward all
keyword arguments to that function.

# Arguments

  - `model::EmulationModel = model`: Emulation model
  - `optimizer::MOI.OptimizerWithAttributes`: The optimizer that is used to solve the model
  - `executions::Int`: Number of executions for the emulator run
  - `export_problem_results::Bool`: If true, export ProblemResults DataFrames to CSV files.
  - `output_dir::String`: Required if the model is not already built, otherwise ignored
  - `enable_progress_bar::Bool`: Enables/Disable progress bar printing
  - `serialize::Bool`: If true, serialize the model to a file to allow re-execution later.

# Examples

```julia
status = run!(model; optimizer = GLPK.Optimizer, executions = 10)
status = run!(model; output_dir = ./model_output, optimizer = GLPK.Optimizer, executions = 10)
```
"""
function run!(
    model::EmulationModel{<:EmulationProblem};
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
    try
        Logging.with_logger(logger) do
            try
                initialize_storage!(
                    get_store(model),
                    get_optimization_container(model),
                    model.internal.store_parameters,
                )
                TimerOutputs.@timeit RUN_OPERATION_MODEL_TIMER "Run" begin
                    run_impl!(model; kwargs...)
                    set_run_status!(model, RunStatus.SUCCESSFUL)
                end
                if serialize
                    TimerOutputs.@timeit RUN_OPERATION_MODEL_TIMER "Serialize" begin
                        optimizer = get(kwargs, :optimizer, nothing)
                        serialize_problem(model; optimizer = optimizer)
                        serialize_optimization_model(model)
                    end
                end
                TimerOutputs.@timeit RUN_OPERATION_MODEL_TIMER "Results processing" begin
                    results = ProblemResults(model)
                    serialize_results(results, get_output_dir(model))
                    export_problem_results && export_results(results)
                end
                @info "\n$(RUN_OPERATION_MODEL_TIMER)\n"
            catch e
                @error "Emulation Problem Run failed" exception = (e, catch_backtrace())
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
Default solve method for an EmulationModel used inside of a Simulation. Solves problems that conform to the requirements of DecisionModel{<: DecisionProblem}

# Arguments

  - `step::Int`: Simulation Step
  - `model::OperationModel`: operation model
  - `start_time::Dates.DateTime`: Initial Time of the simulation step in Simulation time.
  - `store::SimulationStore`: Simulation output store
  - `exports = nothing`: realtime export of output. Use wisely, it can have negative impacts in the simulation times
"""
function solve!(
    step::Int,
    model::EmulationModel{<:EmulationProblem},
    start_time::Dates.DateTime,
    store::SimulationStore;
    exports = nothing,
)
    # Note, we don't call solve!(decision_model) here because the solve call includes a lot of
    # other logic used when solving the models separate from a simulation
    solve_impl!(model)
    @assert get_current_time(model) == start_time
    if get_run_status(model) == RunStatus.SUCCESSFUL
        advance_execution_count!(model)
        write_results!(
            store,
            model,
            get_execution_count(model),
            start_time;
            exports = exports,
        )
        write_optimizer_stats!(store, model, get_execution_count(model))
    end
    return get_run_status(model)
end
