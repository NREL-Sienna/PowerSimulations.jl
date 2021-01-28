######## Internal Simulation Object Structs ########
mutable struct SimulationInfo
    number::Int
    name::String
    executions::Int
    execution_count::Int
    end_of_interval_step::Int
    chronolgy_dict::Dict{Int, <:FeedForwardChronology}
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

- `op_problem::OperationsProblem`: The operation model containing the model type, built JuMP model, Power
Systems system.

# Example

```julia
template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
OpModel = OperationsProblem(TestOpProblem, template, system)
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
        settings::PSISettings,
        jump_model::Union{Nothing, JuMP.AbstractModel} = nothing,
    ) where {M <: AbstractOperationsProblem}
        internal =
            ProblemInternal(0, "", 0, 0, OptimizationContainer(sys, settings, jump_model))
        new{M}(template, sys, internal)
    end
end

function OperationsProblem{M}(
    template::OperationsProblemTemplate,
    sys::PSY.System,
    optimizer::JuMP.MOI.OptimizerWithAttributes,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    PTDF = nothing,
    warm_start = true,
    balance_slack_variables = false,
    services_slack_variables = false,
    constraint_duals = Vector{Symbol}(),
    system_to_file = true,
    export_pwl_vars = false,
    allow_fails = false,
    optimizer_log_print = false,
) where {M <: AbstractOperationsProblem}
    settings = PSISettings(
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
This builds the optimization problem of type M with the specific system and template for the simulation stage
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
stage = OperationsProblem(MyOpProblemType template, system, optimizer)
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
    optimizer::JuMP.MOI.OptimizerWithAttributes,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
) where {M <: AbstractOperationsProblem}
    return OperationsProblem{M}(template, sys, optimizer, jump_model; kwargs...)
end

function OperationsProblem(
    template::OperationsProblemTemplate,
    sys::PSY.System,
    optimizer::JuMP.MOI.OptimizerWithAttributes,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
)
    return OperationsProblem{GenericOpProblem}(
        template,
        sys,
        optimizer,
        jump_model;
        kwargs...,
    )
end

is_stage_built(stage::OperationsProblem) = stage.internal.status == BuildStatus.BUILT
is_stage_empty(stage::OperationsProblem) = stage.internal.status == BuildStatus.EMPTY
get_end_of_interval_step(stage::OperationsProblem) = stage.internal.end_of_interval_step
get_execution_count(stage::OperationsProblem) = stage.internal.execution_count
get_executions(stage::OperationsProblem) = stage.internal.executions
function get_initial_time(
    stage::OperationsProblem{T},
) where {T <: AbstractOperationsProblem}
    return get_initial_time(get_settings(stage))
end
get_name(stage::OperationsProblem) = stage.internal.name
get_number(stage::OperationsProblem) = stage.internal.number
get_optimization_container(stage::OperationsProblem) = stage.internal.optimization_container
function get_resolution(stage::OperationsProblem{T}) where {T <: AbstractOperationsProblem}
    resolution = PSY.get_time_series_resolution(get_system(stage))
    return IS.time_period_conversion(resolution)
end
get_settings(stage::OperationsProblem) = get_optimization_container(stage).settings
get_system(stage::OperationsProblem) = stage.sys
get_template(stage::OperationsProblem) = stage.template
get_write_path(stage::OperationsProblem) = stage.internal.write_path
warm_start_enabled(stage::OperationsProblem) =
    get_warm_start(get_optimization_container(stage).settings)

set_write_path!(stage::OperationsProblem, path::AbstractString) = stage.internal.write_path = path
set_stage_status!(stage::OperationsProblem, status::BuildStatus) = stage.internal.status = status

function reset!(stage::OperationsProblem{T}) where {T <: AbstractOperationsProblem}
    stage.internal.execution_count = 0
    container = OptimizationContainer(get_system(stage), get_settings(stage), nothing)
    stage.internal.optimization_container = container
    set_stage_status!(stage, BuildStatus.EMPTY)
    return
end

function build_pre_step!(
    stage::OperationsProblem,
    initial_time::Dates.DateTime,
    horizon::Int,
    stage_interval::Dates.Period,
)
    if !is_stage_empty(stage)
        @info "Stage $(get_name(stage)) status not BuildStatus.EMPTY. Resetting"
        reset!(stage)
    end
    settings = get_settings(stage)
    # Horizon and initial time are set here because the information is specified in the
    # Simulation Sequence object and not at the stage creation.
    set_horizon!(settings, horizon)
    set_initial_time!(settings, initial_time)
    stage_resolution = get_resolution(stage)
    stage.internal.end_of_interval_step = Int(stage_interval / stage_resolution)
    set_stage_status!(stage, BuildStatus.IN_PROGRESS)
    return
end

function build!(
    stage::OperationsProblem{M},
    initial_time::Dates.DateTime,
    horizon::Int,
    stage_interval::Dates.Period,
) where {M <: PowerSimulationsOperationsProblem}
    build_pre_step!(stage, initial_time, horizon, stage_interval)
    optimization_container = get_optimization_container(stage)
    system = get_system(stage)
    _build!(optimization_container, get_template(stage), system)
    settings = get_settings(stage)
    @assert get_horizon(settings) == length(optimization_container.time_steps)
    write_path = get_write_path(stage)
    write_optimization_container(
        get_optimization_container(stage),
        joinpath(
            write_path,
            "models_json",
            "Stage$(stage.internal.number)_optimization_model.json",
        ),
    )
    set_stage_status!(stage, BuildStatus.BUILT)
    return
end

function run_stage!(
    step::Int,
    stage::OperationsProblem{M},
    start_time::Dates.DateTime,
    store::SimulationStore;
    exports = nothing,
) where {M <: PowerSimulationsOperationsProblem}
    @assert get_optimization_container(stage).JuMPmodel.moi_backend.state !=
            MOIU.NO_OPTIMIZER
    status = RunStatus.RUNNING
    timed_log = Dict{Symbol, Any}()
    model = get_optimization_container(stage).JuMPmodel

    _, timed_log[:timed_solve_time], timed_log[:solve_bytes_alloc], timed_log[:sec_in_gc] =
        @timed JuMP.optimize!(model)

    model_status = JuMP.primal_status(model)
    stats = OptimizerStats(step, get_number(stage), start_time, model, timed_log)
    append_optimizer_stats!(store, stats)

    if model_status != MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        return RunStatus.FAILED
    else
        status = RunStatus.SUCCESSFUL
    end
    write_model_results!(store, stage, start_time; exports = exports)
    stage.internal.execution_count += 1
    # Reset execution count at the end of step
    if stage.internal.execution_count == stage.internal.executions
        stage.internal.execution_count = 0
    end
    return status
end

function write_model_results!(store, stage, timestamp; exports = nothing)
    optimization_container = get_optimization_container(stage)
    if exports !== nothing
        export_params = Dict{Symbol, Any}(
            :exports => exports,
            :exports_path => joinpath(exports.path, get_name(stage)),
            :file_type => get_export_file_type(exports),
            :resolution => get_resolution(stage),
            :horizon => get_horizon(get_settings(stage)),
        )
    else
        export_params = nothing
    end

    if is_milp(get_optimization_container(stage))
        @warn "Stage $(stage.internal.number) is a MILP, duals can't be exported"
    else
        _write_model_dual_results!(
            store,
            optimization_container,
            stage,
            timestamp,
            export_params,
        )
    end

    _write_model_parameter_results!(
        store,
        optimization_container,
        stage,
        timestamp,
        export_params,
    )
    _write_model_variable_results!(
        store,
        optimization_container,
        stage,
        timestamp,
        export_params,
    )
    return
end

function _write_model_dual_results!(
    store,
    optimization_container,
    stage,
    timestamp,
    exports,
)
    stage_name_str = get_name(stage)
    stage_name = Symbol(stage_name_str)
    if exports !== nothing
        exports_path = joinpath(exports[:exports_path], "duals")
        mkpath(exports_path)
    end

    for name in get_constraint_duals(optimization_container.settings)
        constraint = get_constraint(optimization_container, name)
        write_result!(
            store,
            stage_name,
            STORE_CONTAINER_DUALS,
            name,
            timestamp,
            to_array(constraint),
        )

        if exports !== nothing &&
           should_export_dual(exports[:exports], timestamp, stage_name_str, name)
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
    stage,
    timestamp,
    exports,
)
    stage_name_str = get_name(stage)
    stage_name = Symbol(stage_name_str)
    if exports !== nothing
        exports_path = joinpath(exports[:exports_path], "parameters")
        mkpath(exports_path)
    end

    parameters = get_parameters(optimization_container)
    (isnothing(parameters) || isempty(parameters)) && return
    horizon = get_horizon(get_settings(stage))

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

        write_result!(store, stage_name, STORE_CONTAINER_PARAMETERS, name, timestamp, data)

        if exports !== nothing &&
           should_export_parameter(exports[:exports], timestamp, stage_name_str, name)
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
    stage,
    timestamp,
    exports,
)
    stage_name_str = get_name(stage)
    stage_name = Symbol(stage_name_str)
    if exports !== nothing
        exports_path = joinpath(exports[:exports_path], "variables")
        mkpath(exports_path)
    end

    for (name, variable) in get_variables(optimization_container)
        write_result!(
            store,
            stage_name,
            STORE_CONTAINER_VARIABLES,
            name,
            timestamp,
            to_array(variable),
        )

        if exports !== nothing &&
           should_export_variable(exports[:exports], timestamp, stage_name_str, name)
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

# Here because requires the stage to be defined
# This is a method a user defining a custom cache will have to define. This is the definition
# in PSI for the building the TimeStatusChange
function get_initial_cache(cache::AbstractCache, stage::OperationsProblem)
    throw(ArgumentError("Initialization method for cache $(typeof(cache)) not defined"))
end

function get_initial_cache(cache::TimeStatusChange, stage::OperationsProblem)
    ini_cond_on = get_initial_conditions(
        get_optimization_container(stage),
        TimeDurationON,
        cache.device_type,
    )

    ini_cond_off = get_initial_conditions(
        get_optimization_container(stage),
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

function get_initial_cache(cache::StoredEnergy, stage::OperationsProblem)
    ini_cond_level = get_initial_conditions(
        get_optimization_container(stage),
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

function get_timestamps(stage::OperationsProblem, start_time::Dates.DateTime)
    resolution = get_resolution(stage)
    horizon = get_optimization_container(stage).time_steps[end]
    range_time = collect(start_time:resolution:(start_time + resolution * horizon))
    time_stamp = DataFrames.DataFrame(Range = range_time[:, 1])

    return time_stamp
end

function write_data(stage::OperationsProblem, save_path::AbstractString; kwargs...)
    write_data(get_optimization_container(stage), save_path; kwargs...)
    return
end

struct StageSerializationWrapper
    template::OperationsProblemTemplate
    sys::String
    settings::PSISettings
    stage_type::DataType
end
