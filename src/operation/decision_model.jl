"""Default PowerSimulations Operation Problem Type"""
struct GenericOpProblem <: DecisionProblem end

"""
    DecisionModel(::Type{M},
    template::ProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model}=nothing;
    kwargs...) where {M<:DecisionProblem,
                      T<:PM.AbstractPowerFormulation}

This builds the optimization problem of type M with the specific system and template.

# Arguments

- `::Type{M} where M<:DecisionProblem`: The abstract operation model type
- `template::ProblemTemplate`: The model reference made up of transmission, devices,
                                          branches, and services.
- `sys::PSY.System`: the system created using Power Systems
- `jump_model::Union{Nothing, JuMP.Model}`: Enables passing a custom JuMP model. Use with care

# Output

- `model::DecisionModel`: The operation model containing the model type, built JuMP model, Power
Systems system.

# Example

```julia
template = ProblemTemplate(CopperPlatePowerModel, devices, branches, services)
OpModel = DecisionModel(MockOperationProblem, template, system)
```

# Accepted Key Words

- `optimizer`: The optimizer that will be used in the optimization model.
- `horizon::Int`: Manually specify the length of the forecast Horizon
- `warm_start::Bool`: True will use the current operation point in the system to initialize variable values. False initializes all variables to zero. Default is true
- `system_to_file::Bool:`: True to create a copy of the system used in the model. Default true.
- `export_pwl_vars::Bool`: True to export all the pwl intermediate variables. It can slow down significantly the solve time. Default to false.
- `allow_fails::Bool`: True to allow the simulation to continue even if the optimization step fails. Use with care, default to false.
- `optimizer_log_print::Bool`: True to print the optimizer solve log. Default to false.
- `direct_mode_optimizer::Bool` True to use the solver in direct mode. Creates a [JuMP.direct_model](https://jump.dev/JuMP.jl/dev/reference/models/#JuMP.direct_model). Default to false.
- `initial_time::Dates.DateTime`: Initial Time for the model solve
- `time_series_cache_size::Int`: Size in bytes to cache for each time array. Default is 1 MiB. Set to 0 to disable.
"""
mutable struct DecisionModel{M <: DecisionProblem} <: OperationModel
    name::Symbol
    template::ProblemTemplate
    sys::PSY.System
    internal::Union{Nothing, ProblemInternal}
    ext::Dict{String, Any}

    function DecisionModel{M}(
        template::ProblemTemplate,
        sys::PSY.System,
        settings::Settings,
        jump_model::Union{Nothing, JuMP.Model} = nothing;
        name = nothing,
    ) where {M <: DecisionProblem}
        if name === nothing
            name = Symbol(typeof(template))
        elseif name isa String
            name = Symbol(name)
        end
        internal = ProblemInternal(OptimizationContainer(sys, settings, jump_model))
        new{M}(name, template, sys, internal, Dict{String, Any}())
    end
end

function DecisionModel{M}(
    template::ProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    name = nothing,
    optimizer = nothing,
    horizon = UNSET_HORIZON,
    warm_start = true,
    system_to_file = true,
    export_pwl_vars = false,
    allow_fails = false,
    optimizer_log_print = false,
    direct_mode_optimizer = false,
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
        export_pwl_vars = export_pwl_vars,
        allow_fails = allow_fails,
        optimizer_log_print = optimizer_log_print,
        direct_mode_optimizer = direct_mode_optimizer,
    )
    return DecisionModel{M}(template, sys, settings, jump_model, name = name)
end

"""
    DecisionModel(::Type{M},
    template::ProblemTemplate,
    sys::PSY.System,
    optimizer::MOI.OptimizerWithAttributes,
    jump_model::Union{Nothing, JuMP.Model}=nothing;
    kwargs...) where {M <: DecisionProblem}
This builds the optimization problem of type M with the specific system and template
# Arguments
- `::Type{M} where M<:DecisionProblem`: The abstract operation model type
- `template::ProblemTemplate`: The model reference made up of transmission, devices,
                                          branches, and services.
- `sys::PSY.System`: the system created using Power Systems
- `jump_model::Union{Nothing, JuMP.Model}`: Enables passing a custom JuMP model. Use with care
# Output
- `Stage::DecisionProblem`: The operation model containing the model type, unbuilt JuMP model, Power
Systems system.
# Example
```julia
template = ProblemTemplate(CopperPlatePowerModel, devices, branches, services)
problem = DecisionModel(MyOpProblemType template, system, optimizer)
```
# Accepted Key Words
- `initial_time::Dates.DateTime`: Initial Time for the model solve
- `warm_start::Bool` True will use the current operation point in the system to initialize variable values. False initializes all variables to zero. Default is true
- `export_pwl_vars::Bool` True will write the results of the piece-wise-linear intermediate variables. Slows down the simulation process significantly
- `allow_fails::Bool` True will allow the simulation to continue if the optimizer can't find a solution. Use with care, can lead to unwanted behaviour or results
- `optimizer_log_print::Bool` Uses JuMP.unset_silent() to print the optimizer's log. By default all solvers are set to `MOI.Silent()`
- `name`: name of model, string or symbol; defaults to the type of template converted to a symbol
"""
function DecisionModel(
    ::Type{M},
    template::ProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    kwargs...,
) where {M <: DecisionProblem}
    return DecisionModel{M}(template, sys, jump_model; kwargs...)
end

function DecisionModel(
    template::ProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.Model} = nothing;
    kwargs...,
)
    return DecisionModel{GenericOpProblem}(template, sys, jump_model; kwargs...)
end

"""
    DecisionModel(filename::AbstractString)

Construct an DecisionProblem from a serialized file.

# Arguments
- `filename::AbstractString`: path to serialized file
- `jump_model::Union{Nothing, JuMP.Model}` = nothing: The JuMP model does not get
   serialized. Callers should pass whatever they passed to the original problem.
- `optimizer::Union{Nothing,MOI.OptimizerWithAttributes}` = nothing: The optimizer does
   not get serialized. Callers should pass whatever they passed to the original problem.
- `system::Union{Nothing, PSY.System}`: Optionally, the system used for the model.
   If nothing and sys_to_file was set to true when the model was created, the system will
   be deserialized from a file.
"""
function DecisionModel(
    filename::AbstractString;
    jump_model::Union{Nothing, JuMP.Model} = nothing,
    optimizer::Union{Nothing, MOI.OptimizerWithAttributes} = nothing,
    system::Union{Nothing, PSY.System} = nothing,
)
    return deserialize_problem(
        DecisionModel,
        filename;
        jump_model = jump_model,
        optimizer = optimizer,
        system = system,
    )
end

get_name(model::DecisionModel) = model.name

function get_time_series_values!(
    time_series_type::Type{<:IS.TimeSeriesData},
    model::DecisionModel,
    component,
    name,
    initial_time,
    horizon;
    ignore_scaling_factors = true,
)
    if !use_time_series_cache(get_settings(model))
        return IS.get_time_series_values(
            time_series_type,
            component,
            name,
            start_time = initial_time,
            len = horizon,
            ignore_scaling_factors = true,
        )
    end

    cache = get_time_series_cache(model)
    key = TimeSeriesCacheKey(IS.get_uuid(component), time_series_type, name)
    if haskey(cache, key)
        ts_cache = cache[key]
    else
        ts_cache = make_time_series_cache(
            time_series_type,
            component,
            name,
            initial_time,
            horizon,
            ignore_scaling_factors = true,
        )
        cache[key] = ts_cache
    end

    ts = IS.get_time_series_array!(ts_cache, initial_time)
    return TimeSeries.values(ts)
end

function make_time_series_cache(
    time_series_type::Type{T},
    component,
    name,
    initial_time,
    horizon;
    ignore_scaling_factors = true,
) where {T <: IS.TimeSeriesData}
    key = TimeSeriesCacheKey(IS.get_uuid(component), T, name)
    if T <: IS.SingleTimeSeries
        cache = IS.StaticTimeSeriesCache(
            PSY.SingleTimeSeries,
            component,
            name,
            start_time = initial_time,
            ignore_scaling_factors = ignore_scaling_factors,
        )
    elseif T <: IS.Deterministic
        cache = IS.ForecastCache(
            IS.AbstractDeterministic,
            component,
            name,
            start_time = initial_time,
            horizon = horizon,
            ignore_scaling_factors = ignore_scaling_factors,
        )
    elseif T <: IS.Probabilistic
        cache = IS.ForecastCache(
            IS.Probabilistic,
            component,
            name,
            start_time = initial_time,
            horizon = horizon,
            ignore_scaling_factors = ignore_scaling_factors,
        )
    else
        error("not supported yet: $T")
    end

    @debug "Made time series cache for $(summary(component))" name initial_time
    return cache
end

function get_initial_conditions(
    model::DecisionModel,
    ic::InitialConditionType,
    device::PSY.Device,
)
    key = ICKey(ic, device)
    return get_initial_conditions(get_optimization_container(model), key)
end

set_console_level!(model::DecisionModel, val) = get_internal(model).console_level = val
set_file_level!(model::DecisionModel, val) = get_internal(model).file_level = val
set_executions!(model::DecisionModel, val::Int) =
    model.internal.simulation_info.executions = val
set_execution_count!(model::DecisionModel, val::Int) =
    get_simulation_info(model).execution_count = val
set_initial_time!(model::DecisionModel, val::Dates.DateTime) =
    set_initial_time!(get_settings(model), val)
set_simulation_info!(model::DecisionModel, info::SimulationInfo) =
    model.internal.simulation_info = info
function set_status!(model::DecisionModel, status::BuildStatus)
    model.internal.status = status
    return
end
set_output_dir!(model::DecisionModel, path::AbstractString) =
    get_internal(model).output_dir = path

function reset!(model::DecisionModel{T}) where {T <: DecisionProblem}
    if built_for_simulation(model::DecisionModel)
        set_execution_count!(model, 0)
    end
    container = OptimizationContainer(get_system(model), get_settings(model), nothing)
    model.internal.container = container
    empty_time_series_cache!(model)
    set_status!(model, BuildStatus.EMPTY)
    return
end

function advance_execution_count!(model::DecisionModel)
    info = get_simulation_info(model)
    info.execution_count += 1
    # Reset execution count at the end of step
    if get_execution_count(model) == get_executions(model)
        info.execution_count = 0
    end
    return
end

function build_pre_step!(model::DecisionModel)
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Build pre-step" begin
        if !is_empty(model)
            @info "OptimizationProblem status not BuildStatus.EMPTY. Resetting"
            reset!(model)
        end
        # Initial time are set here because the information is specified in the
        # Simulation Sequence object and not at the problem creation.
        @info "Initializing Optimization Container"
        optimization_container_init!(
            get_optimization_container(model),
            get_network_formulation(get_template(model)),
            get_system(model),
        )
        set_status!(model, BuildStatus.IN_PROGRESS)
    end
    return
end

function _build!(model::DecisionModel{<:DecisionProblem}, serialize::Bool)
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Problem $(get_name(model))" begin
        try
            build_pre_step!(model)
            problem_build!(model)
            serialize && serialize_problem(model)
            serialize && serialize_optimization_model(model)
            serialize_metadata!(
                get_optimization_container(model),
                get_output_dir(model),
                get_name(model),
            )
            set_status!(model, BuildStatus.BUILT)
            log_values(get_settings(model))
            !built_for_simulation(model) && @info "\n$(BUILD_PROBLEMS_TIMER)\n"
        catch e
            set_status!(model, BuildStatus.FAILED)
            bt = catch_backtrace()
            @error "Operation Problem Build Failed" exception = e, bt
        end
    end
    return get_status(model)
end

"""Implementation of build for any DecisionProblem"""
function build!(
    model::DecisionModel{<:DecisionProblem};
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
            return _build!(model, serialize)
        end
    finally
        close(logger)
    end
end

"""
Default implementation of build method for Operational Problems for models conforming with  DecisionProblem specification. Overload this function to implement a custom build method
"""
function problem_build!(model::DecisionModel{<:DecisionProblem})
    build_impl!(get_optimization_container(model), get_template(model), get_system(model))
end

serialize_optimization_model(::DecisionProblem) = nothing
serialize_problem(::DecisionProblem) = nothing

function serialize_optimization_model(model::DecisionModel{<:DecisionProblem})
    problem_name = "$(get_name(model))_OptimizationModel"
    json_file_name = "$(problem_name).json"
    json_file_name = joinpath(get_output_dir(model), json_file_name)
    serialize_optimization_model(get_optimization_container(model), json_file_name)
end

struct DecisionModelSerializationWrapper
    template::ProblemTemplate
    sys::Union{Nothing, String}
    settings::Settings
    model_type::DataType
    name::String
end

function serialize_problem(model::DecisionModel{<:DecisionProblem})
    # A PowerSystem cannot be serialized in this format because of how it stores
    # time series data. Use its specialized serialization method instead.
    problem_name = get_name(model)
    sys_to_file = get_system_to_file(get_settings(model))
    if sys_to_file
        sys = get_system(model)
        sys_filename = joinpath(get_output_dir(model), make_system_filename(sys))
        # Skip serialization if the system is already in the folder
        !ispath(sys_filename) && PSY.to_json(sys, sys_filename)
    else
        sys_filename = nothing
    end
    container = get_optimization_container(model)
    obj = DecisionModelSerializationWrapper(
        model.template,
        sys_filename,
        container.settings_copy,
        typeof(model),
        string(get_name(model)),
    )
    bin_file_name = "$problem_name.bin"
    bin_file_name = joinpath(get_output_dir(model), bin_file_name)
    Serialization.serialize(bin_file_name, obj)
    @info "Serialized DecisionModel to" bin_file_name
end

function deserialize_problem(::Type{DecisionModel}, filename::AbstractString; kwargs...)
    obj = Serialization.deserialize(filename)
    if !(obj isa DecisionModelSerializationWrapper)
        throw(IS.DataFormatError("deserialized object has incorrect type $(typeof(obj))"))
    end
    sys = get(kwargs, :system, nothing)
    settings = restore_from_copy(obj.settings; optimizer = kwargs[:optimizer])
    if sys === nothing
        if obj.sys === nothing && !settings[:sys_to_file]
            throw(
                IS.DataFormatError(
                    "Operations Problem System was not serialized and a System has not been specified.",
                ),
            )
        elseif !ispath(obj.sys)
            throw(IS.DataFormatError("PowerSystems.System file $(obj.sys) does not exist"))
        end
        sys = PSY.System(obj.sys)
    end

    return obj.model_type(
        obj.template,
        sys,
        kwargs[:jump_model];
        name = obj.name,
        settings...,
    )
end

function calculate_aux_variables!(model::DecisionModel)
    container = get_optimization_container(model)
    system = get_system(model)
    aux_vars = get_aux_variables(container)
    for key in keys(aux_vars)
        calculate_aux_variable_value!(container, key, system)
    end
    return
end

function calculate_dual_variables!(model::DecisionModel)
    container = get_optimization_container(model)
    system = get_system(model)
    duals_vars = get_duals(container)
    for key in keys(duals_vars)
        _calculate_dual_variable_value!(container, key, system)
    end
    return
end

function solve_impl(model::DecisionModel; optimizer = nothing)
    if !is_built(model)
        error(
            "Operations Problem Build status is $(get_status(model)). Solve can't continue",
        )
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
    status = RunStatus.RUNNING
    timed_log = get_solve_timed_log(model)
    _, timed_log[:timed_solve_time], timed_log[:solve_bytes_alloc], timed_log[:sec_in_gc] =
        @timed JuMP.optimize!(jump_model)
    model_status = JuMP.primal_status(jump_model)
    if model_status != MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        return RunStatus.FAILED
    else
        calculate_aux_variables!(model)
        calculate_dual_variables!(model)
        status = RunStatus.SUCCESSFUL
    end
    return status
end

"""
Default solve method the operational model for a single instance. Solves problems
    that conform to the requirements of DecisionModel{<: DecisionProblem}
# Arguments
- `model::OperationModel = model`: operation model
# Examples
```julia
results = solve!(OpModel)
```
# Accepted Key Words
- `output_dir::String`: If a file path is provided the results
automatically get written to feather files
- `optimizer::MOI.OptimizerWithAttributes`: The optimizer that is used to solve the model
"""
function solve!(model::DecisionModel{<:DecisionProblem}; kwargs...)
    status = solve_impl(model; kwargs...)
    set_run_status!(model, status)
    return status
end

function write_problem_results!(
    step::Int,
    model::DecisionModel{<:DecisionProblem},
    start_time::Dates.DateTime,
    store::SimulationStore,
    exports,
)
    stats = OptimizerStats(model, step)
    write_optimizer_stats!(store, get_name(model), stats, start_time)
    write_model_results!(store, model, start_time; exports = exports)
    return
end

"""
Default solve method for an operational model used inside of a Simulation. Solves problems that conform to the requirements of DecisionModel{<: DecisionProblem}

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
    solve_status = solve!(model)
    if solve_status == RunStatus.SUCCESSFUL
        write_problem_results!(step, model, start_time, store, exports)
        advance_execution_count!(model)
    end

    return solve_status
end

function write_model_results!(store, model, timestamp; exports = nothing)
    if exports !== nothing
        export_params = Dict{Symbol, Any}(
            :exports => exports,
            :exports_path => joinpath(exports.path, string(get_name(model))),
            :file_type => get_export_file_type(exports),
            :resolution => get_resolution(model),
            :horizon => get_horizon(get_settings(model)),
        )
    else
        export_params = nothing
    end

    container = get_optimization_container(model)
    # This line should only be called if the problem is exporting duals. Otherwise ignore.
    if is_milp(container)
        @warn "Problem $(get_simulation_info(model).name) is a MILP, duals can't be exported"
    else
        _write_model_dual_results!(store, container, model, timestamp, export_params)
    end

    _write_model_parameter_results!(store, container, model, timestamp, export_params)
    _write_model_variable_results!(store, container, model, timestamp, export_params)
    _write_model_aux_variable_results!(store, container, model, timestamp, export_params)
    return
end

function _write_model_dual_results!(store, container, model, timestamp, exports)
    problem_name = get_name(model)
    if exports !== nothing
        exports_path = joinpath(exports[:exports_path], "duals")
        mkpath(exports_path)
    end

    for (key, constraint) in get_duals(container)
        write_result!(
            store,
            problem_name,
            STORE_CONTAINER_DUALS,
            key,
            timestamp,
            constraint,
            [encode_key(key)],  # TODO DT: this doesn't seem right
        )

        if exports !== nothing &&
           should_export_dual(exports[:exports], timestamp, problem_name, key)
            horizon = exports[:horizon]
            resolution = exports[:resolution]
            file_type = exports[:file_type]
            df = axis_array_to_dataframe(constraint, [name])
            time_col = range(timestamp, length = horizon, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            export_result(file_type, exports_path, key, timestamp, df)
        end
    end
end

function _write_model_parameter_results!(store, container, model, timestamp, exports)
    problem_name = get_name(model)
    if exports !== nothing
        exports_path = joinpath(exports[:exports_path], "parameters")
        mkpath(exports_path)
    end

    parameters = get_parameters(container)
    (isnothing(parameters) || isempty(parameters)) && return
    horizon = get_horizon(get_settings(model))

    for (key, container) in parameters
        name = encode_key(key)  # TODO DT
        !isa(container.update_ref, UpdateRef{<:PSY.Component}) && continue
        param_array = get_parameter_array(container)
        multiplier_array = get_multiplier_array(container)
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
            problem_name,
            STORE_CONTAINER_PARAMETERS,
            key,
            timestamp,
            data,
            param_array.axes[1],
        )

        if exports !== nothing &&
           should_export_parameter(exports[:exports], timestamp, problem_name, key)
            resolution = exports[:resolution]
            file_type = exports[:file_type]
            df = DataFrames.DataFrame(data, param_array.axes[1])
            time_col = range(timestamp, length = horizon, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            export_result(file_type, exports_path, key, timestamp, df)
        end
    end
end

function _write_model_variable_results!(store, container, model, timestamp, exports)
    problem_name = get_name(model)
    if exports !== nothing
        exports_path = joinpath(exports[:exports_path], "variables")
        mkpath(exports_path)
    end

    for (key, variable) in get_variables(container)
        write_result!(
            store,
            problem_name,
            STORE_CONTAINER_VARIABLES,
            key,
            timestamp,
            variable,
        )

        if exports !== nothing &&
           should_export_variable(exports[:exports], timestamp, problem_name, key)
            horizon = exports[:horizon]
            resolution = exports[:resolution]
            file_type = exports[:file_type]
            df = axis_array_to_dataframe(variable)
            time_col = range(timestamp, length = horizon, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            export_result(file_type, exports_path, key, timestamp, df)
        end
    end
end

function _write_model_aux_variable_results!(store, container, model, timestamp, exports)
    problem_name = get_name(model)
    if exports !== nothing
        # TODO: Should the export go to a folder aux_variables
        exports_path = joinpath(exports[:exports_path], "variables")
        mkpath(exports_path)
    end

    for (key, variable) in get_aux_variables(container)
        write_result!(
            store,
            problem_name,
            STORE_CONTAINER_VARIABLES,
            key,
            timestamp,
            variable,
        )

        if exports !== nothing &&
           should_export_variable(exports[:exports], timestamp, problem_name, key)
            horizon = exports[:horizon]
            resolution = exports[:resolution]
            file_type = exports[:file_type]
            df = axis_array_to_dataframe(variable)
            time_col = range(timestamp, length = horizon, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            export_result(file_type, exports_path, key, timestamp, df)
        end
    end
end

# Here because requires the problem to be defined
# This is a method a user defining a custom cache will have to define. This is the definition
# in PSI for the building the TimeStatusChange
function get_initial_cache(cache::AbstractCache, ::DecisionModel)
    throw(ArgumentError("Initialization method for cache $(typeof(cache)) not defined"))
end

function get_initial_cache(cache::TimeStatusChange, model::DecisionModel)
    ini_cond_on = get_initial_conditions(
        get_optimization_container(model),
        InitialTimeDurationOn,
        cache.device_type,
    )

    ini_cond_off = get_initial_conditions(
        get_optimization_container(model),
        InitialTimeDurationOff,
        cache.device_type,
    )

    device_axes = Set((
        PSY.get_name(ic.device) for ic in Iterators.Flatten([ini_cond_on, ini_cond_off])
    ),)
    value_array = JuMP.Containers.DenseAxisArray{Dict{Symbol, Any}}(undef, device_axes)

    for ic in ini_cond_on
        device_name = PSY.get_name(ic.device)
        condition = get_condition(ic)
        status = (condition > 0.0) ? 1.0 : 0.0
        value_array[device_name] = Dict(:count => condition, :status => status)
    end

    for ic in ini_cond_off
        device_name = PSY.get_name(ic.device)
        condition = get_condition(ic)
        status = (condition > 0.0) ? 0.0 : 1.0
        if value_array[device_name][:status] != status
            throw(
                IS.ConflictingInputsError(
                    "Initial Conditions for $(device_name) are not compatible. The values provided are invalid",
                ),
            )
        end
    end

    return value_array
end

function get_initial_cache(cache::StoredEnergy, model::DecisionModel)
    ini_cond_level = get_initial_conditions(
        get_optimization_container(model),
        InitialEnergyLevel,
        cache.device_type,
    )

    device_axes = Set([PSY.get_name(ic.device) for ic in ini_cond_level],)
    value_array = JuMP.Containers.DenseAxisArray{Float64}(undef, device_axes)
    for ic in ini_cond_level
        device_name = PSY.get_name(ic.device)
        condition = get_condition(ic)
        value_array[device_name] = condition
    end
    return value_array
end

function get_timestamps(model::DecisionModel)
    start_time = get_initial_time(get_optimization_container(model))
    resolution = get_resolution(model)
    horizon = get_horizon(model)
    return range(start_time, length = horizon, step = resolution)
end

function write_data(model::DecisionModel, output_dir::AbstractString; kwargs...)
    write_data(get_optimization_container(model), output_dir; kwargs...)
    return
end

struct ProblemSerializationWrapper
    template::ProblemTemplate
    sys::String
    settings::Settings
    problem_type::DataType
end

################ Functions to debug optimization models#####################################
"""
Each Tuple corresponds to (con_name, internal_index, moi_index)
"""
function get_all_constraint_index(model::DecisionModel)
    con_index = Vector{Tuple{ConstraintKey, Int, Int}}()
    container = get_optimization_container(model)
    for (key, value) in get_constraints(container)
        for (idx, constraint) in enumerate(value)
            moi_index = JuMP.optimizer_index(constraint)
            push!(con_index, (key, idx, moi_index.value))
        end
    end
    return con_index
end

"""
Each Tuple corresponds to (con_name, internal_index, moi_index)
"""
function get_all_var_index(model::DecisionModel)
    var_keys = get_all_var_keys(model)
    return [(encode_key(v[1]), v[2], v[3]) for v in var_keys]
end

function get_all_var_keys(model::DecisionModel)
    var_index = Vector{Tuple{VariableKey, Int, Int}}()
    container = get_optimization_container(model)
    for (key, value) in get_variables(container)
        for (idx, variable) in enumerate(value)
            moi_index = JuMP.optimizer_index(variable)
            push!(var_index, (key, idx, moi_index.value))
        end
    end
    return var_index
end

function get_con_index(model::DecisionModel, index::Int)
    container = get_optimization_container(model)
    constraints = get_constraints(container)
    for i in get_all_constraint_index(model::DecisionModel)
        if i[3] == index
            return constraints[i[1]].data[i[2]]
        end
    end
    @info "Index not found"
    return
end

function get_var_index(model::DecisionModel, index::Int)
    container = get_optimization_container(model)
    variables = get_variables(container)
    for i in get_all_var_keys(model)
        if i[3] == index
            return variables[i[1]].data[i[2]]
        end
    end
    @info "Index not found"
    return
end
