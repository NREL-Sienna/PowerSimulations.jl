# JDNOTE: This might be merged with the structs in simulation_store
mutable struct SimulationInfo
    number::Int
    name::String
    executions::Int
    execution_count::Int
    caches::Set{CacheKey}
    end_of_interval_step::Int
    chronolgy_dict::Dict{Int, <:FeedForwardChronology}
    requires_rebuild::Bool
    sequence_uuid::Base.UUID
end

mutable struct ProblemInternal
    optimization_container::OptimizationContainer
    status::BuildStatus
    base_conversion::Bool
    output_dir::Union{Nothing, String}
    simulation_info::Union{Nothing, SimulationInfo}
    ext::Dict{String, Any}
    console_level::Base.CoreLogging.LogLevel
    file_level::Base.CoreLogging.LogLevel
end

function ProblemInternal(
    optimization_container::OptimizationContainer;
    ext = Dict{String, Any}(),
)
    return ProblemInternal(
        optimization_container,
        BuildStatus.EMPTY,
        true,
        nothing,
        nothing,
        ext,
        Logging.Warn,
        Logging.Info,
    )
end

function configure_logging(internal::ProblemInternal, file_mode)
    return IS.configure_logging(
        console = true,
        console_stream = stderr,
        console_level = internal.console_level,
        file = true,
        filename = joinpath(internal.output_dir, PROBLEM_BUILD_LOG_FILENAME),
        file_level = internal.file_level,
        file_mode = file_mode,
        tracker = nothing,
        set_global = false,
    )
end

"""Default PowerSimulations Operation Problem Type"""
struct GenericOpProblem <: PowerSimulationsOperationsProblem end

"""
    OperationsProblem(::Type{M},
    template::OperationsProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel}=nothing;
    kwargs...) where {M<:AbstractOperationsProblem,
                      T<:PM.AbstractPowerFormulation}

This builds the optimization problem of type M with the specific system and template.

# Arguments

- `::Type{M} where M<:AbstractOperationsProblem`: The abstract operation model type
- `template::OperationsProblemTemplate`: The model reference made up of transmission, devices,
                                          branches, and services.
- `sys::PSY.System`: the system created using Power Systems
- `jump_model::Union{Nothing, JuMP.AbstractModel}`: Enables passing a custom JuMP model. Use with care

# Output

- `problem::OperationsProblem`: The operation model containing the model type, built JuMP model, Power
Systems system.

# Example

```julia
template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
OpModel = OperationsProblem(MockOperationProblem, template, system)
```

# Accepted Key Words

- `horizon::Int`: Manually specify the length of the forecast Horizon
- `initial_time::Dates.DateTime`: Initial Time for the model solve
- `use_forecast_data::Bool`: If true uses the data in the system forecasts. If false uses the data for current operating point in the system.
- `PTDF::PTDF`: Passes the PTDF matrix into the optimization model for StandardPTDFModel networks.
- `optimizer::JuMP.MOI.OptimizerWithAttributes`: The optimizer that will be used in the optimization model.
- `use_parameters::Bool`: True will substitute will implement formulations using ParameterJuMP parameters. Defatul is false.
- `warm_start::Bool`: True will use the current operation point in the system to initialize variable values. False initializes all variables to zero. Default is true
- `balance_slack_variables::Bool`: True will add slacks to the system balance constraints
- `services_slack_variables::Bool`: True will add slacks to the services requirement constraints
"""
mutable struct OperationsProblem{M <: AbstractOperationsProblem}
    template::OperationsProblemTemplate
    sys::PSY.System
    internal::Union{Nothing, ProblemInternal}

    function OperationsProblem{M}(
        template::OperationsProblemTemplate,
        sys::PSY.System,
        settings::Settings,
        jump_model::Union{Nothing, JuMP.AbstractModel} = nothing,
    ) where {M <: AbstractOperationsProblem}
        internal = ProblemInternal(OptimizationContainer(sys, settings, jump_model))
        new{M}(template, sys, internal)
    end
end

function OperationsProblem{M}(
    template::OperationsProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    optimizer::Union{MOI.OptimizerWithAttributes, Nothing} = nothing,
    PTDF = nothing,
    horizon = nothing,
    warm_start = true,
    balance_slack_variables = false,
    services_slack_variables = false,
    constraint_duals = Vector{Symbol}(),
    system_to_file = true,
    export_pwl_vars = false,
    allow_fails = false,
    optimizer_log_print = false,
    use_parameters = false,
    use_forecast_data = true,
    initial_time = UNSET_INI_TIME,
) where {M <: AbstractOperationsProblem}
    settings = Settings(
        sys;
        initial_time = initial_time,
        optimizer = optimizer,
        use_parameters = use_parameters,
        warm_start = warm_start,
        balance_slack_variables = balance_slack_variables,
        services_slack_variables = services_slack_variables,
        constraint_duals = constraint_duals,
        system_to_file = system_to_file,
        export_pwl_vars = export_pwl_vars,
        allow_fails = allow_fails,
        PTDF = PTDF,
        optimizer_log_print = optimizer_log_print,
        use_forecast_data = use_forecast_data,
    )
    return OperationsProblem{M}(template, sys, settings, jump_model)
end

"""
    OperationsProblem(::Type{M},
    template::OperationsProblemTemplate,
    sys::PSY.System,
    optimizer::JuMP.MOI.OptimizerWithAttributes,
    jump_model::Union{Nothing, JuMP.AbstractModel}=nothing;
    kwargs...) where {M<:AbstractOperationsProblem}
This builds the optimization problem of type M with the specific system and template
# Arguments
- `::Type{M} where M<:AbstractOperationsProblem`: The abstract operation model type
- `template::OperationsProblemTemplate`: The model reference made up of transmission, devices,
                                          branches, and services.
- `sys::PSY.System`: the system created using Power Systems
- `jump_model::Union{Nothing, JuMP.AbstractModel}`: Enables passing a custom JuMP model. Use with care
# Output
- `Stage::OperationsProblem`: The operation model containing the model type, unbuilt JuMP model, Power
Systems system.
# Example
```julia
template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
problem = OperationsProblem(MyOpProblemType template, system, optimizer)
```
# Accepted Key Words
- `initial_time::Dates.DateTime`: Initial Time for the model solve
- `PTDF::PTDF`: Passes the PTDF matrix into the optimization model for StandardPTDFModel networks.
- `warm_start::Bool` True will use the current operation point in the system to initialize variable values. False initializes all variables to zero. Default is true
- `balance_slack_variables::Bool` True will add slacks to the system balance constraints
- `services_slack_variables::Bool` True will add slacks to the services requirement constraints
- `export_pwl_vars::Bool` True will write the results of the piece-wise-linear intermediate variables. Slows down the simulation process significantly
- `allow_fails::Bool` True will allow the simulation to continue if the optimizer can't find a solution. Use with care, can lead to unwanted behaviour or results
- `optimizer_log_print::Bool` Uses JuMP.unset_silent() to print the optimizer's log. By default all solvers are set to `MOI.Silent()`
"""
function OperationsProblem(
    ::Type{M},
    template::OperationsProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
) where {M <: AbstractOperationsProblem}
    return OperationsProblem{M}(template, sys, jump_model; kwargs...)
end

function OperationsProblem(
    template::OperationsProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
)
    return OperationsProblem{GenericOpProblem}(template, sys, jump_model; kwargs...)
end

# Default implemenations of getter/setter functions for OperationsProblem.
is_built(problem::OperationsProblem) = problem.internal.status == BuildStatus.BUILT
is_empty(problem::OperationsProblem) = problem.internal.status == BuildStatus.EMPTY
warm_start_enabled(problem::OperationsProblem) =
    get_warm_start(get_optimization_container(problem).settings)
built_for_simulation(problem::OperationsProblem) = get_simulation_info(problem) !== nothing
get_caches(problem::OperationsProblem) = get_simulation_info(problem).caches
get_constraints(problem::OperationsProblem) =
    get_internal(problem).optimization_container.constraints
get_end_of_interval_step(problem::OperationsProblem) =
    get_simulation_info(problem).end_of_interval_step
get_execution_count(problem::OperationsProblem) =
    get_simulation_info(problem).execution_count
get_executions(problem::OperationsProblem) = get_simulation_info(problem).executions
get_initial_time(problem::OperationsProblem) = get_initial_time(get_settings(problem))
get_horizon(problem::OperationsProblem) = get_horizon(get_settings(problem))
get_internal(problem::OperationsProblem) = problem.internal
get_jump_model(problem::OperationsProblem) =
    get_internal(problem).optimization_container.JuMPmodel
get_name(x::OperationsProblem) = built_for_simulation(x) ? get_simulation_info(x).name : ""

get_optimization_container(problem::OperationsProblem) =
    problem.internal.optimization_container
function get_resolution(problem::OperationsProblem{<:AbstractOperationsProblem})
    resolution = PSY.get_time_series_resolution(get_system(problem))
    return IS.time_period_conversion(resolution)
end
get_problem_base_power(problem::OperationsProblem) = PSY.get_base_power(problem.sys)
get_settings(problem::OperationsProblem) = get_optimization_container(problem).settings
get_solve_timed_log(problem::OperationsProblem) =
    get_optimization_container(problem).solve_timed_log
get_simulation_info(problem::OperationsProblem) = problem.internal.simulation_info
get_simulation_number(problem::OperationsProblem) = problem.internal.simulation_info.number
get_status(problem::OperationsProblem) = problem.internal.status
get_system(problem::OperationsProblem) = problem.sys
get_template(problem::OperationsProblem) = problem.template
get_write_path(problem::OperationsProblem) = problem.internal.write_path
get_variables(problem::OperationsProblem) =
    get_internal(problem).optimization_container.variables

function get_initial_conditions(
    problem::OperationsProblem,
    ic::InitialConditionType,
    device::PSY.Device,
)
    key = ICKey(ic, device)
    return get_initial_conditions(get_optimization_container(problem), key)
end

set_console_level!(problem::OperationsProblem, val) =
    get_internal(problem).console_level = val
set_file_level!(problem::OperationsProblem, val) = get_internal(problem).file_level = val
set_executions!(problem::OperationsProblem, val::Int) =
    problem.internal.simulation_info.executions = val
set_execution_count!(problem::OperationsProblem, val::Int) =
    get_simulation_info(problem).execution_count = val
set_initial_time!(problem::OperationsProblem, val::Dates.DateTime) =
    set_initial_time!(get_settings(problem), val)
set_simulation_info!(problem::OperationsProblem, info::SimulationInfo) =
    problem.internal.simulation_info = info
function set_status!(problem::OperationsProblem, status::BuildStatus)
    problem.internal.status = status
    return
end
set_output_dir!(problem::OperationsProblem, path::AbstractString) =
    get_internal(problem).output_dir = path

function reset!(problem::OperationsProblem{T}) where {T <: AbstractOperationsProblem}
    if built_for_simulation(problem::OperationsProblem)
        set_execution_count!(problem, 0)
    end
    container = OptimizationContainer(get_system(problem), get_settings(problem), nothing)
    problem.internal.optimization_container = container
    set_status!(problem, BuildStatus.EMPTY)
    return
end

function advance_execution_count!(problem::OperationsProblem)
    info = get_simulation_info(problem)
    info.execution_count += 1
    # Reset execution count at the end of step
    if get_execution_count(problem) == get_executions(problem)
        info.execution_count = 0
    end
    return
end

function build_pre_step!(problem::OperationsProblem)
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Build pre-step" begin
        if !is_empty(problem)
            @info "OptimizationProblem status not BuildStatus.EMPTY. Resetting"
            reset!(problem)
        end
        settings = get_settings(problem)
        # Initial time are set here because the information is specified in the
        # Simulation Sequence object and not at the problem creation.
        system = get_system(problem)
        if built_for_simulation(problem)
            resolution = get_resolution(problem)
            interval = PSY.get_forecast_interval(system)
            end_of_interval_step = Int(interval / resolution)
            get_simulation_info(problem).end_of_interval_step = Int(interval / resolution)
        end
        @info "Initializing Optimization Container"
        template = get_template(problem)
        optimization_container_init!(
            get_optimization_container(problem),
            get_transmission_model(template),
            system,
        )
        set_status!(problem, BuildStatus.IN_PROGRESS)
    end
    return
end

"""Implementation of build for any OperationsProblem"""
function build!(
    problem::OperationsProblem{<:AbstractOperationsProblem};
    output_dir::String,
    console_level = Logging.Error,
    file_level = Logging.Info,
    enable_timer_outputs = true,
)
    if !ispath(output_dir)
        throw(ArgumentError("$output_dir does not exist"))
    end
    set_output_dir!(problem, output_dir)
    problem.internal.console_level = console_level
    problem.internal.file_level = file_level
    logger = configure_logging(problem.internal, "w")
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Build Problem $(get_name(problem))" begin
        try
            Logging.with_logger(logger) do
                build_pre_step!(problem)
                problem_build!(problem)
                #serialize_problem(problem, "operations_problem")
                #serialize_optimization_model(problem)
                set_status!(problem, BuildStatus.BUILT)
                if !built_for_simulation(problem)
                    @info "\n$(BUILD_PROBLEMS_TIMER)\n"
                end
            end
        catch e
            set_status!(problem, BuildStatus.FAILED)
            bt = catch_backtrace()
            @error "Operation Problem Build Failed" exception = e, bt
        end
    end
    return get_status(problem)
end

"""
Default implementation of build method for Operational Problems for models conforming with PowerSimulationsOperationsProblem specification. Overload this function to implement a custom build method
"""
function problem_build!(problem::OperationsProblem{<:PowerSimulationsOperationsProblem})
    build_impl!(
        get_optimization_container(problem),
        get_template(problem),
        get_system(problem),
    )
end

serialize_optimization_model(::OperationsProblem) = nothing
serialize_problem(::OperationsProblem) = nothing

function serialize_optimization_model(
    problem::OperationsProblem{<:PowerSimulationsOperationsProblem},
)
    serialize_optimization_model(get_optimization_container(problem), path)
end

function serialize_problem(
    op_problem::OperationsProblem{<:PowerSimulationsOperationsProblem},
    filename::AbstractString,
)
    # A PowerSystem cannot be serialized in this format because of how it stores
    # time series data. Use its specialized serialization method instead.
    sys_filename = "$(basename(filename))-system-$(IS.get_uuid(op_problem.sys)).json"
    sys_filename = joinpath(dirname(filename), sys_filename)
    PSY.to_json(op_problem.sys, sys_filename)
    obj = OperationsProblemSerializationWrapper(
        op_problem.template,
        sys_filename,
        op_problem.psi_container.settings_copy,
        typeof(op_problem),
    )
    Serialization.serialize(filename, obj)
    @info "Serialized OperationsProblem to" filename
end

function deserialize_problem(::Type{OperationsProblem}, filename::AbstractString; kwargs...)
    obj = Serialization.deserialize(filename)
    if !(obj isa OperationsProblemSerializationWrapper)
        throw(IS.DataFormatError("deserialized object has incorrect type $(typeof(obj))"))
    end

    if !ispath(obj.sys)
        throw(IS.DataFormatError("PowerSystems.System file $(obj.sys) does not exist"))
    end
    sys = PSY.System(obj.sys)

    return obj.op_problem_type(
        obj.template,
        sys,
        kwargs[:jump_model],
        restore_from_copy(obj.settings; optimizer = kwargs[:optimizer]),
    )
end

struct OperationsProblemSerializationWrapper
    template::OperationsProblemTemplate
    sys::String
    settings::Settings
    op_problem_type::DataType
end

function _psi_solve_optimization_problem(problem::OperationsProblem; optimizer = nothing)
    model = get_jump_model(problem)
    if optimizer !== nothing
        JuMP.set_optimizer(model, optimizer)
    end
    if model.moi_backend.state == MOIU.NO_OPTIMIZER
        @error("No Optimizer has been defined, can't solve the operational problem")
        return RunStatus.FAILED
    end
    @assert model.moi_backend.state != MOIU.NO_OPTIMIZER
    status = RunStatus.RUNNING
    timed_log = get_solve_timed_log(problem)
    _, timed_log[:timed_solve_time], timed_log[:solve_bytes_alloc], timed_log[:sec_in_gc] =
        @timed JuMP.optimize!(model)
    model_status = JuMP.primal_status(model)
    if model_status != MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        return RunStatus.FAILED
    else
        status = RunStatus.SUCCESSFUL
    end
    return status
end

"""
Default solve method the operational model for a single instance. Solves problems
    that conform to the requirements of OperationsProblem{<: PowerSimulationsOperationsProblem}
# Arguments
- `op_problem::OperationModel = op_problem`: operation model
# Examples
```julia
results = solve!(OpModel)
```
# Accepted Key Words
- `output_dir::String`: If a file path is provided the results
automatically get written to feather files
- `optimizer::MOI.OptimizerWithAttributes`: The optimizer that is used to solve the model
"""
function solve!(problem::OperationsProblem{<:PowerSimulationsOperationsProblem}; kwargs...)
    return _psi_solve_optimization_problem(problem; kwargs...)
end

"""
Default solve method foran operational model used inside of a Simulation. Solves problems that conform to the requirements of OperationsProblem{<: PowerSimulationsOperationsProblem}

# Arguments
- `step::Int`: Simulation Step
- `op_problem::OperationModel`: operation model
- `start_time::Dates.DateTime`: Initial Time of the simulation step in Simulation time.
- `store::SimulationStore`: Simulation output store

# Accepted Key Words
- `exports`: realtime export of output. Use wisely, it can have negative impacts in the simulation times
"""
function solve!(
    step::Int,
    problem::OperationsProblem{<:PowerSimulationsOperationsProblem},
    start_time::Dates.DateTime,
    store::SimulationStore;
    exports = nothing,
)
    solve_status = solve!(problem)
    if solve_status == RunStatus.SUCCESSFUL
        stats = OptimizerStats(problem, step, start_time)
        append_optimizer_stats!(store, stats)
        write_model_results!(store, problem, start_time; exports = exports)
        advance_execution_count!(problem)
    end

    return solve_status
end

function write_model_results!(store, problem, timestamp; exports = nothing)
    optimization_container = get_optimization_container(problem)
    if exports !== nothing
        export_params = Dict{Symbol, Any}(
            :exports => exports,
            :exports_path => joinpath(exports.path, get_name(problem)),
            :file_type => get_export_file_type(exports),
            :resolution => get_resolution(problem),
            :horizon => get_horizon(get_settings(problem)),
        )
    else
        export_params = nothing
    end

    # This line should only be called if the problem is exporting duals. Otherwise ignore.
    if is_milp(get_optimization_container(problem))
        @warn "Problem $(get_simulation_info(problem).name) is a MILP, duals can't be exported"
    else
        _write_model_dual_results!(
            store,
            optimization_container,
            problem,
            timestamp,
            export_params,
        )
    end

    _write_model_parameter_results!(
        store,
        optimization_container,
        problem,
        timestamp,
        export_params,
    )
    _write_model_variable_results!(
        store,
        optimization_container,
        problem,
        timestamp,
        export_params,
    )
    return
end

function _write_model_dual_results!(
    store,
    optimization_container,
    problem,
    timestamp,
    exports,
)
    problem_name_str = get_name(problem)
    problem_name = Symbol(problem_name_str)
    if exports !== nothing
        exports_path = joinpath(exports[:exports_path], "duals")
        mkpath(exports_path)
    end

    for name in get_constraint_duals(optimization_container.settings)
        constraint = get_constraint(optimization_container, name)
        write_result!(
            store,
            problem_name,
            STORE_CONTAINER_DUALS,
            name,
            timestamp,
            to_array(constraint),
        )

        if exports !== nothing &&
           should_export_dual(exports[:exports], timestamp, problem_name_str, name)
            horizon = exports[:horizon]
            resolution = exports[:resolution]
            file_type = exports[:file_type]
            df = axis_array_to_dataframe(constraint)
            if names(df) == ["var"]
                # Workaround for limitation in axis_array_to_dataframe.
                DataFrames.rename!(df, [name])
            end
            time_col = range(timestamp, length = horizon, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            export_result(file_type, exports_path, name, timestamp, df)
        end
    end
end

function _write_model_parameter_results!(
    store,
    optimization_container,
    problem,
    timestamp,
    exports,
)
    problem_name_str = get_name(problem)
    problem_name = Symbol(problem_name_str)
    if exports !== nothing
        exports_path = joinpath(exports[:exports_path], "parameters")
        mkpath(exports_path)
    end

    parameters = get_parameters(optimization_container)
    (isnothing(parameters) || isempty(parameters)) && return
    horizon = get_horizon(get_settings(problem))

    for (name, container) in parameters
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
            name,
            timestamp,
            data,
        )

        if exports !== nothing &&
           should_export_parameter(exports[:exports], timestamp, problem_name_str, name)
            resolution = exports[:resolution]
            file_type = exports[:file_type]
            df = DataFrames.DataFrame(data, param_array.axes[1])
            time_col = range(timestamp, length = horizon, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            export_result(file_type, exports_path, name, timestamp, df)
        end
    end
end

function _write_model_variable_results!(
    store,
    optimization_container,
    problem,
    timestamp,
    exports,
)
    problem_name_str = get_name(problem)
    problem_name = Symbol(problem_name_str)
    if exports !== nothing
        exports_path = joinpath(exports[:exports_path], "variables")
        mkpath(exports_path)
    end

    for (name, variable) in get_variables(optimization_container)
        write_result!(
            store,
            problem_name,
            STORE_CONTAINER_VARIABLES,
            name,
            timestamp,
            to_array(variable),
        )

        if exports !== nothing &&
           should_export_variable(exports[:exports], timestamp, problem_name_str, name)
            horizon = exports[:horizon]
            resolution = exports[:resolution]
            file_type = exports[:file_type]
            df = axis_array_to_dataframe(variable)
            time_col = range(timestamp, length = horizon, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            export_result(file_type, exports_path, name, timestamp, df)
        end
    end
end

# Here because requires the problem to be defined
# This is a method a user defining a custom cache will have to define. This is the definition
# in PSI for the building the TimeStatusChange
function get_initial_cache(cache::AbstractCache, problem::OperationsProblem)
    throw(ArgumentError("Initialization method for cache $(typeof(cache)) not defined"))
end

function get_initial_cache(cache::TimeStatusChange, problem::OperationsProblem)
    ini_cond_on = get_initial_conditions(
        get_optimization_container(problem),
        TimeDurationON,
        cache.device_type,
    )

    ini_cond_off = get_initial_conditions(
        get_optimization_container(problem),
        TimeDurationOFF,
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

function get_initial_cache(cache::StoredEnergy, problem::OperationsProblem)
    ini_cond_level = get_initial_conditions(
        get_optimization_container(problem),
        EnergyLevel,
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

function get_timestamps(problem::OperationsProblem, start_time::Dates.DateTime)
    resolution = get_resolution(problem)
    horizon = get_optimization_container(problem).time_steps[end]
    range_time = collect(start_time:resolution:(start_time + resolution * horizon))
    time_stamp = DataFrames.DataFrame(Range = range_time[:, 1])

    return time_stamp
end

function write_data(problem::OperationsProblem, output_dir::AbstractString; kwargs...)
    write_data(get_optimization_container(problem), output_dir; kwargs...)
    return
end

struct ProblemSerializationWrapper
    template::OperationsProblemTemplate
    sys::String
    settings::Settings
    problem_type::DataType
end

################ Functions to debug optimization models#####################################
""" "Each Tuple corresponds to (con_name, internal_index, moi_index)"""
function get_all_constraint_index(problem::OperationsProblem)
    con_index = Vector{Tuple{Symbol, Int, Int}}()
    optimization_container = get_optimization_container(problem)
    for (key, value) in get_constraints(optimization_container)
        for (idx, constraint) in enumerate(value)
            moi_index = JuMP.optimizer_index(constraint)
            push!(con_index, (key, idx, moi_index.value))
        end
    end
    return con_index
end

""" "Each Tuple corresponds to (con_name, internal_index, moi_index)"""
function get_all_var_index(problem::OperationsProblem)
    var_index = Vector{Tuple{Symbol, Int, Int}}()
    optimization_container = get_optimization_container(problem)
    for (key, value) in get_variables(optimization_container)
        for (idx, variable) in enumerate(value)
            moi_index = JuMP.optimizer_index(variable)
            push!(var_index, (key, idx, moi_index.value))
        end
    end
    return var_index
end

function get_con_index(problem::OperationsProblem, index::Int)
    optimization_container = get_optimization_container(problem)
    constraints = get_constraints(optimization_container)
    for i in get_all_constraint_index(problem::OperationsProblem)
        if i[3] == index
            return constraints[i[1]].data[i[2]]
        end
    end
    @info "Index not found"
    return
end

function get_var_index(problem::OperationsProblem, index::Int)
    optimization_container = get_optimization_container(problem)
    variables = get_variables(optimization_container)
    for i in get_all_var_index(problem::OperationsProblem)
        if i[3] == index
            return variables[i[1]].data[i[2]]
        end
    end
    @info "Index not found"
    return
end
