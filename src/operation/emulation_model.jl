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
- `export_pwl_vars::Bool`: True to export all the pwl intermediate variables. It can slow down significantly the solve time. Default to false.
- `allow_fails::Bool`: True to allow the simulation to continue even if the optimization step fails. Use with care, default to false.
- `optimizer_log_print::Bool`: True to print the optimizer solve log. Default to false.
- `direct_mode_optimizer::Bool` True to use the solver in direct mode. Creates a [JuMP.direct_model](https://jump.dev/JuMP.jl/dev/reference/models/#JuMP.direct_model). Default to false.
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
        set_status!(model, BuildStatus.IN_PROGRESS)
    end
    return
end

function build_initialization!(model::EmulationModel)
    container = get_optimization_container(model)
    if isempty(keys(get_initial_conditions(container)))
        @debug "No initial conditions in the model"
    else
        build_initialization_problem(model)
    end
    return
end

function build_impl!(model::EmulationModel{<:EmulationProblem}, serialize::Bool)
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Problem $(get_name(model))" begin
        try
            build_pre_step!(model)
            build_problem!(model)
            init_model_store!(model)
            # serialize && serialize_problem(model)
            # serialize && serialize_optimization_model(model)
            serialize_metadata!(
                get_optimization_container(model),
                get_output_dir(model),
                get_name(model),
            )
            set_status!(model, BuildStatus.BUILT)
            log_values(get_settings(model))
            !built_for_recurrent_solves(model) && @info "\n$(BUILD_PROBLEMS_TIMER)\n"
        catch e
            set_status!(model, BuildStatus.FAILED)
            bt = catch_backtrace()
            @error "Emulation Problem Build Failed" exception = e, bt
        end
    end
    return get_status(model)
end

"""Implementation of build for any EmulationProblem"""
function build!(
    model::EmulationModel{<:EmulationProblem};
    executions = 1,
    output_dir::String,
    console_level = Logging.Error,
    file_level = Logging.Info,
    disable_timer_outputs = false,
    serialize = true,
)
    mkpath(output_dir)
    set_output_dir!(model, output_dir)
    set_console_level!(model, console_level)
    set_file_level!(model, file_level)
    TimerOutputs.reset_timer!(BUILD_PROBLEMS_TIMER)
    disable_timer_outputs && TimerOutputs.disable_timer!(BUILD_PROBLEMS_TIMER)
    logger = configure_logging(model.internal, "w")
    try
        Logging.with_logger(logger) do
            set_executions!(model, executions)
            return build_impl!(model, serialize)
        end
    finally
        close(logger)
    end
end

"""
Default implementation of build method for Emulation Problems for models conforming with  DecisionProblem specification. Overload this function to implement a custom build method
"""
function build_problem!(model::EmulationModel{<:EmulationProblem})
    @info "Initializing Optimization Container for EmulationModel"

    container = get_optimization_container(model)
    system = get_system(model)
    init_optimization_container!(
        container,
        get_network_formulation(get_template(model)),
        system,
    )
    # Temporary while are able to switch from PJ to POI
    container.built_for_recurrent_solves = true
    populate_aggregated_service_model!(get_template(model), get_system(model))
    populate_contributing_devices!(get_template(model), get_system(model))
    add_services_to_device_model!(get_template(model))
    build_impl!(container, get_template(model), system)
    build_initialization_problem(model)
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
    model.internal.ic_model_container = OptimizationContainer(
        get_system(model),
        get_settings(model),
        nothing,
        PSY.SingleTimeSeries,
    )
    empty_time_series_cache!(model)
    set_status!(model, BuildStatus.EMPTY)
    return
end

function serialize_optimization_model(model::EmulationModel{<:EmulationProblem})
    problem_name = "$(get_name(model))_EmulationModel"
    json_file_name = "$(problem_name).json"
    json_file_name = joinpath(get_output_dir(model), json_file_name)
    serialize_optimization_model(get_optimization_container(model), json_file_name)
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
function _one_step_solve!(
    container::OptimizationContainer,
    system::PSY.System,
    log::Dict{Symbol, Any},
)
    jump_model = get_jump_model(container)
    _, log[:timed_solve_time], log[:solve_bytes_alloc], log[:sec_in_gc] =
        @timed JuMP.optimize!(jump_model)
    model_status = JuMP.primal_status(jump_model)
    if model_status != MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        error("Optimizer returned $model_status")
    end

    _, log[:timed_calculate_aux_variables] =
        @timed calculate_aux_variables!(container, system)
    _, log[:timed_calculate_dual_variables] =
        @timed calculate_dual_variables!(container, system)
    return
end

"""
The one step solution method for the emulation model. Any Custom EmulationModel
needs to reimplement this method. This method is called by run! and execute!.
"""
function one_step_solve!(model::EmulationModel)
    container = get_optimization_container(model)
    _one_step_solve!(container, get_system(model), get_solve_timed_log(model))
    return
end

function initialize!(model::EmulationModel)
    container = get_optimization_container(model)
    if isempty(keys(get_initial_conditions(container)))
        return
    end
    @info "Initializing Model"
    _one_step_solve!(
        model.internal.ic_model_container,
        get_system(model),
        Dict{Symbol, Any}(),
    )
    for key in keys(get_initial_conditions(container))
        # set_first_initial_conditions!(model, key)
    end
    return
end

function update_model!(model::EmulationModel, store)
    for key in keys(get_parameters(model))
        update_parameter_values!(model, key)
    end
    return
end

function update_model!(model::EmulationModel)
    update_model!(model, model.store)
end

function run_impl(
    model::EmulationModel;
    optimizer = nothing,
    enable_progress_bar = _PROGRESS_METER_ENABLED,
    kwargs...,
)
    set_run_status!(model, _pre_solve_model_checks(model, optimizer; kwargs...))
    internal = get_internal(model)
    # Temporary check. Needs better way to manage re-runs of the same model
    if internal.execution_count > 0
        error("Call build! again")
    end
    try
        prog_bar =
            ProgressMeter.Progress(internal.executions; enabled = enable_progress_bar)
        initialize!(model)
        for execution in 1:(internal.executions)
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
    catch e
        @error "Emulation Problem Run failed" exception = (e, catch_backtrace())
        set_run_status!(model, RunStatus.FAILED)
        return get_run_status(model)
    finally
        set_run_status!(model, RunStatus.SUCCESSFUL)
    end
    return get_run_status(model)
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

# Examples
```julia
status = run!(model; optimizer = GLPK.Optimizer, executions = 10)
status = run!(model; output_dir = ./model_output, optimizer = GLPK.Optimizer, executions = 10)
```
"""
function run!(
    model::EmulationModel{<:EmulationProblem};
    export_problem_results = false,
    kwargs...,
)
    status = run_impl(model; kwargs...)
    set_run_status!(model, status)
    if status == RunStatus.SUCCESSFUL
        results = ProblemResults(model)
        serialize_results(results, get_output_dir(model))
        export_problem_results && export_results(results)
    end

    return status
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
end

function _write_model_dual_results!(store, container, execution)
    for (key, dual) in get_duals(container)
        write_result!(store, STORE_CONTAINER_DUALS, key, execution, dual)
    end
end

function _write_model_parameter_results!(store, container, execution)
    parameters = get_parameters(container)
    (isnothing(parameters) || isempty(parameters)) && return
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
