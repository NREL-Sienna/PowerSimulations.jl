"""Default PowerSimulations Emulation Problem Type"""
struct GenericEmulationProblem <: EmulationProblem end

"""
    EmulationModel(::Type{M},
    template::ProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model}=nothing;
    kwargs...) where {M<:EmulationProblem,
                      T<:PM.AbstractPowerFormulation}

This builds the optimization problem of type M with the specific system and template.

# Arguments

- `::Type{M} where M<:EmulationProblem`: The abstract Emulation model type
- `template::ProblemTemplate`: The model reference made up of transmission, devices,
                                          branches, and services.
- `sys::PSY.System`: the system created using Power Systems
- `jump_model::Union{Nothing, JuMP.Model}`: Enables passing a custom JuMP model. Use with care

# Output

- `model::EmulationModel`: The Emulation model containing the model type, built JuMP model, Power
Systems system.

# Example

```julia
template = ProblemTemplate(CopperPlatePowerModel, devices, branches, services)
OpModel = EmulationModel(MockEmulationProblem, template, system)
```

# Accepted Key Words

- `optimizer`: The optimizer that will be used in the optimization model.
- `warm_start::Bool`: True will use the current Emulation point in the system to initialize variable values. False initializes all variables to zero. Default is true
- `system_to_file::Bool:`: True to create a copy of the system used in the model. Default true.
- `export_pwl_vars::Bool`: True to export all the pwl intermediate variables. It can slow down significantly the solve time. Default is false.
- `allow_fails::Bool`: True to allow the simulation to continue even if the optimization step fails. Use with care, default to false.
- `optimizer_log_print::Bool`: True to print the optimizer solve log. Default is false.
- `direct_mode_optimizer::Bool` True to use the solver in direct mode. Creates a [JuMP.direct_model](https://jump.dev/JuMP.jl/dev/reference/models/#JuMP.direct_model). Default is false.
- `initial_time::Dates.DateTime`: Initial Time for the model solve
- `time_series_cache_size::Int`: Size in bytes to cache for each time array. Default is 1 MiB. Set to 0 to disable.
"""
mutable struct EmulationModel{M <: EmulationProblem} <: OperationModel
    name::Symbol
    template::ProblemTemplate
    sys::PSY.System
    internal::ModelInternal
    store::InMemoryModelStore # might be extended to other stores for simulation
    ext::Dict{String, Any}

    function EmulationModel{M}(
        template::ProblemTemplate,
        sys::PSY.System,
        settings::Settings,
        jump_model::Union{Nothing, JuMP.Model} = nothing;
        name = nothing,
    ) where {M <: EmulationProblem}
        if name === nothing
            name = Symbol(typeof(template))
        elseif name isa String
            name = Symbol(name)
        end
        _, ts_count, forecast_count = PSY.get_time_series_counts(sys)
        if ts_count < 1
            error(
                "The system does not contain Static TimeSeries data. An Emulation model can't be formulated.",
            )
        end
        internal = ModelInternal(
            OptimizationContainer(sys, settings, jump_model, PSY.SingleTimeSeries),
        )
        new{M}(
            name,
            template,
            sys,
            internal,
            InMemoryModelStore(EmulationModelOptimizerResults),
            Dict{String, Any}(),
        )
    end
end

function EmulationModel{M}(
    template::ProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    name = nothing,
    optimizer = nothing,
    warm_start = true,
    system_to_file = true,
    export_pwl_vars = false,
    allow_fails = false,
    optimizer_log_print = false,
    direct_mode_optimizer = false,
    initial_time = UNSET_INI_TIME,
    time_series_cache_size::Int = IS.TIME_SERIES_CACHE_SIZE_BYTES,
    horizon = 1,  # Unused; included for compatibility with DecisionModel.
) where {M <: EmulationProblem}
    settings = Settings(
        sys;
        initial_time = initial_time,
        optimizer = optimizer,
        time_series_cache_size = time_series_cache_size,
        warm_start = warm_start,
        system_to_file = system_to_file,
        export_pwl_vars = export_pwl_vars,
        allow_fails = allow_fails,
        optimizer_log_print = optimizer_log_print,
        direct_mode_optimizer = direct_mode_optimizer,
        horizon = horizon,
    )
    return EmulationModel{M}(template, sys, settings, jump_model, name = name)
end

"""
    EmulationModel(::Type{M},
    template::ProblemTemplate,
    sys::PSY.System,
    optimizer::MOI.OptimizerWithAttributes,
    jump_model::Union{Nothing, JuMP.Model}=nothing;
    kwargs...) where {M <: EmulationProblem}
This builds the optimization problem of type M with the specific system and template
# Arguments
- `::Type{M} where M<:EmulationProblem`: The abstract Emulation model type
- `template::ProblemTemplate`: The model reference made up of transmission, devices,
                                          branches, and services.
- `sys::PSY.System`: the system created using Power Systems
- `jump_model::Union{Nothing, JuMP.Model}`: Enables passing a custom JuMP model. Use with care
# Output
- `Stage::EmulationProblem`: The Emulation model containing the model type, unbuilt JuMP model, Power
Systems system.
# Example
```julia
template = ProblemTemplate(CopperPlatePowerModel, devices, branches, services)
problem = EmulationModel(MyOpProblemType template, system, optimizer)
```
# Accepted Key Words
- `initial_time::Dates.DateTime`: Initial Time for the model solve
- `warm_start::Bool` True will use the current Emulation point in the system to initialize variable values. False initializes all variables to zero. Default is true
- `export_pwl_vars::Bool` True will write the results of the piece-wise-linear intermediate variables. Slows down the simulation process significantly
- `allow_fails::Bool` True will allow the simulation to continue if the optimizer can't find a solution. Use with care, can lead to unwanted behaviour or results
- `optimizer_log_print::Bool` Uses JuMP.unset_silent() to print the optimizer's log. By default all solvers are set to `MOI.Silent()`
- `name`: name of model, string or symbol; defaults to the type of template converted to a symbol
"""
function EmulationModel(
    ::Type{M},
    template::ProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    kwargs...,
) where {M <: EmulationProblem}
    return EmulationModel{M}(template, sys, jump_model; kwargs...)
end

function EmulationModel(
    template::ProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    kwargs...,
)
    return EmulationModel{GenericEmulationProblem}(template, sys, jump_model; kwargs...)
end

"""
EmulationModel(directory::AbstractString)

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
    # This field is probably not needed for Emulation
    # end_of_interval_step = get_end_of_interval_step(get_internal(model))
    base_power = PSY.get_base_power(system)
    sys_uuid = IS.get_uuid(system)
    model.internal.store_parameters = ModelStoreParams(
        num_executions,
        1,
        interval,
        resolution,
        -1, #end_of_interval_step
        base_power,
        sys_uuid,
        get_metadata(get_optimization_container(model)),
    )
end

function init_model_store!(model::EmulationModel)
    init_model_store_params!(model)
    initialize_storage!(
        model.store,
        get_optimization_container(model),
        model.internal.store_parameters,
    )
    return
end

function build_pre_step!(model::EmulationModel)
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Build pre-step" begin
        if !is_empty(model)
            @info "EmulationProblem status not BuildStatus.EMPTY. Resetting"
            reset!(model)
        end
        # Temporary while are able to switch from PJ to POI
        container = get_optimization_container(model)
        container.built_for_recurrent_solves = true

        @info "Initializing Optimization Container For an EmulationModel"
        init_optimization_container!(
            get_optimization_container(model),
            get_network_formulation(get_template(model)),
            get_system(model),
        )
        @info "Initializing ModelStoreParams"
        init_model_store!(model)

        @info "Mapping Service Models"
        populate_aggregated_service_model!(get_template(model), get_system(model))
        populate_contributing_devices!(get_template(model), get_system(model))
        add_services_to_device_model!(get_template(model))

        @info "Initial Conditions  Model"
        build_initial_conditions!(model)
        initialize!(model)
        set_status!(model, BuildStatus.IN_PROGRESS)
    end
    return
end

"""Implementation of build for any EmulationProblem"""
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
function build_problem!(model::EmulationModel{<:EmulationProblem})
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
    set_status!(model, BuildStatus.EMPTY)
    return
end

function calculate_aux_variables!(model::EmulationModel)
    container = get_optimization_container(model)
    system = get_system(model)
    calculate_aux_variables!(container, system)
    return
end

function calculate_dual_variables!(model::EmulationModel)
    container = get_optimization_container(model)
    system = get_system(model)
    calculate_dual_variables!(container, system)
    return
end

"""
The one step solution method for the emulation model. Any Custom EmulationModel
needs to reimplement this method. This method is called by run! and execute!.
"""
function one_step_solve!(model::EmulationModel)
    container = get_optimization_container(model)
    solve_impl!(container, get_system(model), get_solve_timed_log(model))
    return
end

function update_model!(model::EmulationModel, store)
    for key in keys(get_parameters(model))
        update_parameter_values!(model, key)
    end
    for key in keys(get_initial_conditions(model))
        update_initial_conditions!(model, key)
    end
    return
end

function update_model!(model::EmulationModel)
    update_model!(model, model.store)
    return
end

function run_impl(
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
    for execution in 1:(internal.executions)
        TimerOutputs.@timeit RUN_OPERATION_MODEL_TIMER "Run execution" begin
            one_step_solve!(model)
            write_results!(model, execution)
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

This will call [`build!`](@ref) on the model if it is not already built. It will forward all
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
                TimerOutputs.@timeit RUN_OPERATION_MODEL_TIMER "Run" begin
                    run_impl(model; kwargs...)
                    set_run_status!(model, RunStatus.SUCCESSFUL)
                end
                if serialize
                    TimerOutputs.@timeit RUN_OPERATION_MODEL_TIMER "Serialize" begin
                        optimizer = get(kwargs, :optimizer, nothing)
                        serialize_problem(model, optimizer = optimizer)
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
                # TODO: Here run IIS if failed
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
Default solve method for an Emulation model used inside of a Simulation. Solves problems that conform to the requirements of EmulationModel{<: EmulationProblem}

# Arguments
- `step::Int`: Simulation Step
- `model::EmulationModel`: Emulation model
- `start_time::Dates.DateTime`: Initial Time of the simulation step in Simulation time.
- `store::SimulationStore`: Simulation output store
"""
function run!(
    step::Int,
    model::EmulationModel{<:EmulationProblem},
    start_time::Dates.DateTime,
    store::SimulationStore,
)
    # Initialize the InMemorySimulationStore
    solve_status = run!(model)
    if solve_status == RunStatus.SUCCESSFUL
        write_results!(step, model, start_time, store)
        advance_execution_count!(model)
    end

    return solve_status
end

function write_results!(model::EmulationModel, execution)
    store = get_store(model)
    container = get_optimization_container(model)

    _write_model_dual_results!(store, container, execution)
    _write_model_parameter_results!(store, container, execution)
    _write_model_variable_results!(store, container, execution)
    _write_model_aux_variable_results!(store, container, execution)
    write_optimizer_stats!(store, OptimizerStats(model, 1), execution)
    store.data.last_recorded_row = execution
end

function _write_model_dual_results!(store, container, execution)
    for (key, dual) in get_duals(container)
        write_result!(store, STORE_CONTAINER_DUALS, key, execution, dual)
    end
end

function _write_model_parameter_results!(store, container, execution)
    parameters = get_parameters(container)
    (parameters === nothing || isempty(parameters)) && return
    horizon = 1

    for (key, parameter) in parameters
        name = encode_key(key)
        param_array = get_parameter_array(parameter)
        multiplier_array = get_multiplier_array(parameter)
        @assert_op length(axes(param_array)) == 2
        num_columns = size(param_array)[1]
        data = Array{Float64}(undef, horizon, num_columns)
        for r_ix in param_array.axes[2], (c_ix, name) in enumerate(param_array.axes[1])
            val1 = _jump_value(param_array[name, r_ix])
            val2 = multiplier_array[name, r_ix]
            data[r_ix, c_ix] = val1 * val2
        end

        write_result!(
            store,
            STORE_CONTAINER_PARAMETERS,
            key,
            execution,
            data,
            param_array.axes[1],
        )
    end
end

function _write_model_variable_results!(store, container, execution)
    for (key, variable) in get_variables(container)
        write_result!(store, STORE_CONTAINER_VARIABLES, key, execution, variable)
    end
end

function _write_model_aux_variable_results!(store, container, execution)
    for (key, variable) in get_aux_variables(container)
        write_result!(store, STORE_CONTAINER_AUX_VARIABLES, key, execution, variable)
    end
end

function _write_model_expression_results!(store, container, execution)
    for (key, expression) in get_expressions(container)
        write_result!(store, STORE_CONTAINER_EXPRESSIONS, key, execution, expression)
    end
end

# Move to emulation model
list_aux_variable_keys(x::EmulationModel) =
    list_keys(get_store(x), STORE_CONTAINER_AUX_VARIABLES)
list_aux_variable_names(x::EmulationModel) = _list_names(x, STORE_CONTAINER_AUX_VARIABLES)
list_variable_keys(x::EmulationModel) = list_keys(get_store(x), STORE_CONTAINER_VARIABLES)
list_variable_names(x::EmulationModel) = _list_names(x, STORE_CONTAINER_VARIABLES)
list_parameter_keys(x::EmulationModel) = list_keys(get_store(x), STORE_CONTAINER_PARAMETERS)
list_parameter_names(x::EmulationModel) = _list_names(x, STORE_CONTAINER_PARAMETERS)
list_dual_keys(x::EmulationModel) = list_keys(get_store(x), STORE_CONTAINER_DUALS)
list_dual_names(x::EmulationModel) = _list_names(x, STORE_CONTAINER_DUALS)
list_expression_keys(x::EmulationModel) =
    list_keys(get_store(x), STORE_CONTAINER_EXPRESSIONS)
list_expression_names(x::EmulationModel) = _list_names(x, STORE_CONTAINER_EXPRESSIONS)
