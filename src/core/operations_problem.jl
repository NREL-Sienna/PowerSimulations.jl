######## Internal Simulation Object Structs ########
mutable struct SimulationInfo
    number::Int
    name::String
    executions::Int
    execution_count::Int
    end_of_interval_step::Int
    chronolgy_dict::Dict{Int, <:FeedForwardChronology}
    requires_rebuild::Bool
end

mutable struct ProblemInternal
    optimization_container::OptimizationContainer
    status::BuildStatus
    base_conversion::Bool
    write_path::String
    simulation_info::Union{Nothing, SimulationInfo}
    ext::Dict{String, Any}
end

function ProblemInternal(optimization_container; ext = Dict{String, Any}())
    return ProblemInternal(
        optimization_container,
        BuildStatus.EMPTY,
        true,
        "",
        nothing,
        ext,
    )
end

function ProblemInternal(
    optimization_container::OptimizationContainer,
    name::String,
    number::Int,
    executions::Int,
    execution_count::Int,
)
    return ProblemInternal(
        optimization_container,
        BuildStatus.EMPTY,
        true,
        "",
        SimulationInfo(
            number,
            name,
            executions,
            execution_count,
            0,
            Dict{Int, FeedForwardChronology}(),
            false
        ),
        ext,
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
) where {M <: AbstractOperationsProblem}
    settings = Settings(
        sys;
        optimizer = optimizer,
        use_parameters = true,
        warm_start = warm_start,
        balance_slack_variables = balance_slack_variables,
        services_slack_variables = services_slack_variables,
        constraint_duals = constraint_duals,
        system_to_file = system_to_file,
        export_pwl_vars = export_pwl_vars,
        allow_fails = allow_fails,
        PTDF = PTDF,
        optimizer_log_print = optimizer_log_print,
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
    return OperationsProblem{GenericOpProblem}(
        template,
        sys,
        jump_model;
        kwargs...,
    )
end

is_built(problem::OperationsProblem) = problem.internal.status == BuildStatus.BUILT
is_empty(problem::OperationsProblem) = problem.internal.status == BuildStatus.EMPTY
warm_start_enabled(problem::OperationsProblem) =
    get_warm_start(get_optimization_container(problem).settings)
built_for_simulation(problem::OperationsProblem) = get_simulation_info(problem) === nothing
get_end_of_interval_step(problem::OperationsProblem) = get_simulation_info(problem).end_of_interval_step
get_execution_count(problem::OperationsProblem) = get_simulation_info(problem).execution_count
get_executions(problem::OperationsProblem) = get_simulation_info(problem).executions
function get_initial_time(
    problem::OperationsProblem{T},
) where {T <: AbstractOperationsProblem}
    return get_initial_time(get_settings(problem))
end
get_name(problem::OperationsProblem) = problem.internal.name
get_number(problem::OperationsProblem) = get_simulation_info(problem).number
get_optimization_container(problem::OperationsProblem) = problem.internal.optimization_container
function get_resolution(problem::OperationsProblem{T}) where {T <: AbstractOperationsProblem}
    resolution = PSY.get_time_series_resolution(get_system(problem))
    return IS.time_period_conversion(resolution)
end
get_settings(problem::OperationsProblem) = get_optimization_container(problem).settings
get_simulation_info(problem::OperationsProblem) = problem.internal.simulation_info
get_system(problem::OperationsProblem) = problem.sys
get_template(problem::OperationsProblem) = problem.template
get_write_path(problem::OperationsProblem) = problem.internal.write_path
get_problem_base_power(problem::OperationsProblem) = PSY.get_base_power(problem.sys)

function get_initial_conditions(
    problem::OperationsProblem,
    ic::InitialConditionType,
    device::PSY.Device,
)
    key = ICKey(ic, device)
    return get_initial_conditions(get_optimization_container(problem), key)
end

set_execution_count!(problem::OperationsProblem, val::Int) = get_simulation_info(problem).execution_count = val
set_status!(problem::OperationsProblem, status::BuildStatus) = problem.internal.status = status
set_write_path!(problem::OperationsProblem, path::AbstractString) = problem.internal.write_path = path

function reset!(problem::OperationsProblem{T}) where {T <: AbstractOperationsProblem}
    if built_for_simulation(problem::OperationsProblem)
        set_execution_count!(problem, 0)
    end
    container = OptimizationContainer(get_system(problem), get_settings(problem), nothing)
    problem.internal.optimization_container = container
    set_problem_status!(problem, BuildStatus.EMPTY)
    return
end

function build_pre_step!(problem::OperationsProblem, initial_time::Dates.DateTime)
    if !is_empty(problem)
        @info "OptimizationProblem status not BuildStatus.EMPTY. Resetting"
        reset!(problem)
    end
    settings = get_settings(problem)
    # Initial time are set here because the information is specified in the
    # Simulation Sequence object and not at the problem creation.
    set_initial_time!(settings, initial_time)
    if built_for_simulation(problem::OperationsProblem)
        resolution = get_resolution(problem)
        interval = 0
        end_of_interval_step = Int(interval / resolution)
        get_simulation_info(problem).end_of_interval_step = Int(interval / resolution)
    end
    set_status!(problem, BuildStatus.IN_PROGRESS)
    return
end

function build!(
    problem::OperationsProblem{M};
    save_path::String,
    use_forecast_data::Bool = false,
    initial_time::Dates.DateTime = UNSET_INI_TIME
) where {M <: PowerSimulationsOperationsProblem}
    set_write_path!(problem, save_path)
    build_pre_step!(problem, initial_time)
    optimization_container = get_optimization_container(problem)
    system = get_system(problem)
    _build!(optimization_container, get_template(problem), system)
    settings = get_settings(problem)
    @assert get_horizon(settings) == length(optimization_container.time_steps)
    serialize_optimization_model(problem, joinpath(write_path, "operation_problem_optimization_model.json"))
    set_status!(problem, BuildStatus.BUILT)
    return
end

function serialize_optimization_model(problem::OperationsProblem, path::String)
    serialize_optimization_model(get_optimization_container(problem), path)
end

function serialize_model(op_problem::OperationsProblem, filename::AbstractString)
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

function deserialize_model(::Type{OperationsProblem}, filename::AbstractString; kwargs...)
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

"""
    solve!(op_problem::OperationsProblem; kwargs...)
This solves the operational model for a single instance and
outputs results of type OperationsProblemResult
# Arguments
- `op_problem::OperationModel = op_problem`: operation model
# Examples
```julia
results = solve!(OpModel)
```
# Accepted Key Words
- `save_path::String`: If a file path is provided the results
automatically get written to feather files
- `optimizer::MOI.OptimizerWithAttributes`: The optimizer that is used to solve the model
"""
function solve!(
    op_problem::OperationsProblem{T};
    kwargs...,
) where {T <: AbstractOperationsProblem}
    check_kwargs(kwargs, OPERATIONS_SOLVE_KWARGS, "Solve")
    timed_log = Dict{Symbol, Any}()
    save_path = get(kwargs, :save_path, nothing)

    if op_problem.psi_container.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER
        if !(:optimizer in keys(kwargs))
            error("No Optimizer has been defined, can't solve the operational problem")
        end
        JuMP.set_optimizer(op_problem.psi_container.JuMPmodel, kwargs[:optimizer])
        _,
        timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] = @timed JuMP.optimize!(op_problem.psi_container.JuMPmodel)
    else
        _,
        timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] = @timed JuMP.optimize!(op_problem.psi_container.JuMPmodel)
    end
    model_status = JuMP.primal_status(op_problem.psi_container.JuMPmodel)
    if model_status != MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        error("The Operational Problem $(T) status is $(model_status)")
    end
    vars_result = read_variables(op_problem)
    param_values = read_parameters(op_problem)
    optimizer_log = get_optimizer_log(op_problem)
    time_stamp = get_timestamps(op_problem)
    time_stamp = shorten_time_stamp(time_stamp)
    base_power = PSY.get_base_power(op_problem.sys)
    dual_result = read_duals(op_problem)
    obj_value = Dict(
        :OBJECTIVE_FUNCTION => JuMP.objective_value(op_problem.psi_container.JuMPmodel),
    )
    base_power = get_model_base_power(op_problem)
    merge!(optimizer_log, timed_log)

    results = OperationsProblemResults(
        base_power,
        vars_result,
        obj_value,
        optimizer_log,
        time_stamp,
        dual_result,
        param_values,
    )

    save_path !== nothing && serialize_model(op_problem, save_path)

    return results
end

function simulate!(
    step::Int,
    problem::OperationsProblem{M},
    start_time::Dates.DateTime,
    store::SimulationStore;
    exports = nothing,
) where {M <: PowerSimulationsOperationsProblem}
    @assert get_optimization_container(problem).JuMPmodel.moi_backend.state !=
            MOIU.NO_OPTIMIZER
    status = RunStatus.RUNNING
    timed_log = Dict{Symbol, Any}()
    model = get_optimization_container(problem).JuMPmodel

    _, timed_log[:timed_solve_time], timed_log[:solve_bytes_alloc], timed_log[:sec_in_gc] =
        @timed JuMP.optimize!(model)

    model_status = JuMP.primal_status(model)
    stats = OptimizerStats(step, get_number(problem), start_time, model, timed_log)
    append_optimizer_stats!(store, stats)

    if model_status != MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        return RunStatus.FAILED
    else
        status = RunStatus.SUCCESSFUL
    end
    write_model_results!(store, problem, start_time; exports = exports)
    problem.internal.execution_count += 1
    # Reset execution count at the end of step
    if problem.internal.execution_count == problem.internal.executions
        problem.internal.execution_count = 0
    end
    return status
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

    if is_milp(get_optimization_container(problem))
        @warn "Stage $(problem.internal.number) is a MILP, duals can't be exported"
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

        write_result!(store, problem_name, STORE_CONTAINER_PARAMETERS, name, timestamp, data)

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

function write_data(problem::OperationsProblem, save_path::AbstractString; kwargs...)
    write_data(get_optimization_container(problem), save_path; kwargs...)
    return
end

struct StageSerializationWrapper
    template::OperationsProblemTemplate
    sys::String
    settings::Settings
    problem_type::DataType
end

################ Functions to debug optimization models#####################################
""" "Each Tuple corresponds to (con_name, internal_index, moi_index)"""
function get_all_constraint_index(problem::OperationsProblem)
    con_index = Vector{Tuple{Symbol, Int, Int}}()
    for (key, value) in problem.optimization_container.constraints
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
    for (key, value) in problem.optimization_container.variables
        for (idx, variable) in enumerate(value)
            moi_index = JuMP.optimizer_index(variable)
            push!(var_index, (key, idx, moi_index.value))
        end
    end
    return var_index
end

function get_con_index(problem::OperationsProblem, index::Int)
    for i in get_all_constraint_index(problem::OperationsProblem)
        if i[3] == index
            return problem.optimization_container.constraints[i[1]].data[i[2]]
        end
    end

    @info "Index not found"
    return
end

function get_var_index(problem::OperationsProblem, index::Int)
    for i in get_all_var_index(problem::OperationsProblem)
        if i[3] == index
            return problem.optimization_container.variables[i[1]].data[i[2]]
        end
    end
    @info "Index not found"
    return
end
