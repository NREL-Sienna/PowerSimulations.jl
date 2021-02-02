
mutable struct OperationsProblem{M <: AbstractOperationsProblem}
    template::OperationsProblemTemplate
    sys::PSY.System
    psi_container::PSIContainer
end


function OperationsProblem(
    ::Type{M},
    template::OperationsProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
) where {M <: AbstractOperationsProblem}
    return OperationsProblem{M}(template, sys, jump_model; kwargs...)
end

# TODO: Is this function really necessary?
function OperationsProblem{M}(
    template::OperationsProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
) where {M <: AbstractOperationsProblem}
    check_kwargs(kwargs, OPERATIONS_ACCEPTED_KWARGS, "OperationsProblem")
    settings = PSISettings(sys; kwargs...)
    return OperationsProblem{M}(template, sys, jump_model, settings)
end

function OperationsProblem{M}(
    template::OperationsProblemTemplate,
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel},
    settings::PSISettings,
) where {M <: AbstractOperationsProblem}
    op_problem =
        OperationsProblem{M}(template, sys, PSIContainer(sys, settings, jump_model))
    build!(op_problem)
    return op_problem
end

"""
    OperationsProblem(op_problem::Type{M},
                    ::Type{T},
                    sys::PSY.System,
                    jump_model::Union{Nothing, JuMP.AbstractModel}=nothing;
                    kwargs...) where {M<:AbstractOperationsProblem,
                                      T<:PM.AbstractPowerFormulation}

Return an unbuilt operation problem of type M with the specific system and network model T.
    This constructor doesn't build any device model; it is meant to built device models individually using [`construct_device!`](@ref)

# Arguments

- `::Type{M} where M<:AbstractOperationsProblem`: The abstract operation model type
- `::Type{T} where T<:AbstractPowerModel`: The abstract network formulation
- `sys::PSY.System`: the system created using Power Systems
- `jump_model::Union{Nothing, JuMP.AbstractModel}`: Enables passing a custom JuMP model. Use with care

# Output

- `op_problem::OperationsProblem`: The operation model containing the model type, unbuilt JuMP model, Power
Systems system.

# Example

```julia
OpModel = OperationsProblem(MyCustomOpProblem, DCPPowerModel, system)
model = DeviceModel(ThermalStandard, ThermalStandardUnitCommitment)
construct_device!(op_problem, :Thermal, model)
```

# Accepted Key Words

- `horizon::Int`: Manually specify the length of the forecast Horizon
- `initial_time::Dates.DateTime`: Initial Time for the model solve
- `use_forecast_data::Bool` : If true uses the data in the system forecasts. If false uses the data for current operating point in the system.
- `PTDF::PTDF`: Passes the PTDF matrix into the optimization model for StandardPTDFModel networks.
- `optimizer::JuMP.MOI.OptimizerWithAttributes`: The optimizer that will be used in the optimization model.
- `use_parameters::Bool`: True will substitute will implement formulations using ParameterJuMP parameters. Defatul is false.
- `warm_start::Bool`: True will use the current operation point in the system to initialize variable values. False initializes all variables to zero. Default is true
- `balance_slack_variables::Bool`: True will add slacks to the system balance constraints
- `services_slack_variables::Bool`: True will add slacks to the services requirement constraints
"""
function OperationsProblem(
    ::Type{M},
    ::Type{T},
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
) where {M <: AbstractOperationsProblem, T <: PM.AbstractPowerModel}
    return OperationsProblem{M}(T, sys, jump_model; kwargs...)
end

"""
    OperationsProblem(::Type{T},
                    sys::PSY.System,
                    jump_model::Union{Nothing, JuMP.AbstractModel}=nothing;
                    kwargs...) where {M<:AbstractOperationsProblem,
                                      T<:PM.AbstractPowerFormulation}

Return an unbuilt operation problem of type GenericOpProblem with the specific system and network model T.
    This constructor doesn't build any device model; it is meant to built device models individually using [`construct_device!`](@ref)

# Arguments
- `::Type{T} where T<:AbstractPowerModel`: The abstract network formulation
- `sys::PSY.System`: the system created using Power Systems
- `jump_model::Union{Nothing, JuMP.AbstractModel}`: Enables passing a custom JuMP model. Use with care

# Output
- `op_problem::OperationsProblem`: The operation model containing the model type, unbuilt JuMP model, Power Systems system.

# Example

```julia
OpModel = OperationsProblem(DCPPowerModel, system)
model = DeviceModel(ThermalStandard, ThermalStandardUnitCommitment)
construct_device!(op_problem, :Thermal, model)
```

# Accepted Key Words
- `horizon::Int`: Manually specify the length of the forecast Horizon
- `initial_time::Dates.DateTime`: Initial Time for the model solve
- `use_forecast_data::Bool` : If true uses the data in the system forecasts. If false uses the data for current operating point in the system.
- `PTDF::PTDF`: Passes the PTDF matrix into the optimization model for StandardPTDFModel networks.
- `optimizer::JuMP.MOI.OptimizerWithAttributes`: The optimizer that will be used in the optimization model.
- `use_parameters::Bool`: True will substitute will implement formulations using ParameterJuMP parameters. Defatul is false.
- `warm_start::Bool` True will use the current operation point in the system to initialize variable values. False initializes all variables to zero. Default is true
- `balance_slack_variables::Bool` True will add slacks to the system balance constraints
- `services_slack_variables::Bool` True will add slacks to the services requirement constraints
"""
function OperationsProblem(
    ::Type{T},
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
) where {T <: PM.AbstractPowerModel}
    return OperationsProblem{GenericOpProblem}(T, sys, jump_model; kwargs...)
end

# This constructor calls PSI container including the the PowerModels type in order to initialize
# the container and it is meant to construct operations problems using construct_device! function
# calls
function OperationsProblem{M}(
    ::Type{T},
    sys::PSY.System,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
) where {M <: AbstractOperationsProblem, T <: PM.AbstractPowerModel}
    check_kwargs(kwargs, OPERATIONS_ACCEPTED_KWARGS, "OperationsProblem")
    settings = PSISettings(sys; kwargs...)
    return OperationsProblem{M}(
        OperationsProblemTemplate(T),
        sys,
        PSIContainer(T, sys, settings, jump_model),
    )
end

"""
    OperationsProblem(filename::AbstractString)

Construct an OperationsProblem from a serialized file.

# Arguments
- `filename::AbstractString`: path to serialized file
- `jump_model::Union{Nothing, JuMP.AbstractModel}` = nothing: The JuMP model does not get
   serialized. Callers should pass whatever they passed to the original problem.
- `optimizer::Union{Nothing,JuMP.MOI.OptimizerWithAttributes}` = nothing: The optimizer does
   not get serialized. Callers should pass whatever they passed to the original problem.
"""
function OperationsProblem(
    filename::AbstractString;
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing,
    optimizer::Union{Nothing, JuMP.MOI.OptimizerWithAttributes} = nothing,
)
    return deserialize_model(
        OperationsProblem,
        filename;
        jump_model = jump_model,
        optimizer = optimizer,
    )
end

get_transmission_ref(op_problem::OperationsProblem) = op_problem.template.transmission
get_devices_ref(op_problem::OperationsProblem) = op_problem.template.devices
get_branches_ref(op_problem::OperationsProblem) = op_problem.template.branches
get_services_ref(op_problem::OperationsProblem) = op_problem.template.services
get_system(op_problem::OperationsProblem) = op_problem.sys
get_psi_container(op_problem::OperationsProblem) = op_problem.psi_container
get_model_base_power(op_problem::OperationsProblem) = PSY.get_base_power(op_problem.sys)
get_jump_model(op_problem::OperationsProblem) = get_jump_model(op_problem.psi_container)

function reset!(op_problem::OperationsProblem)
    op_problem.psi_container =
        PSIContainer(op_problem.sys, op_problem.psi_container.settings, nothing)
    return
end

function get_initial_conditions(
    op_problem::OperationsProblem,
    ic::InitialConditionType,
    device::PSY.Device,
)
    psi_container = op_problem.psi_container
    key = ICKey(ic, device)

    return get_initial_conditions(psi_container, key)
end

function build!(op_problem::OperationsProblem{M}) where {M <: AbstractOperationsProblem}
    sys = get_system(op_problem)
    _build!(op_problem.psi_container, op_problem.template, sys)
    return
end

function check_problem_size(psi_container::PSIContainer)
    vars = JuMP.num_variables(psi_container.JuMPmodel)
    cons = 0
    for (exp, c_type) in JuMP.list_of_constraint_types(psi_container.JuMPmodel)
        cons += JuMP.num_constraints(psi_container.JuMPmodel, exp, c_type)
    end
    return "The current total number of variables is $(vars) and total number of constraints is $(cons)"
end

function read_variables(op_m::OperationsProblem)
    return read_variables(op_m.psi_container)
end

function read_duals(op_m::OperationsProblem)
    return read_duals(op_m.psi_container)
end

function read_parameters(op_m::OperationsProblem)
    return read_parameters(op_m.psi_container)
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

# Function to create a dictionary for the optimizer log of the simulation
function get_optimizer_log(op_m::OperationsProblem)
    psi_container = op_m.psi_container
    optimizer_log = Dict{Symbol, Any}()
    optimizer_log[:obj_value] = JuMP.objective_value(psi_container.JuMPmodel)
    optimizer_log[:termination_status] = JuMP.termination_status(psi_container.JuMPmodel)
    optimizer_log[:primal_status] = JuMP.primal_status(psi_container.JuMPmodel)
    optimizer_log[:dual_status] = JuMP.dual_status(psi_container.JuMPmodel)
    optimizer_log[:solver] = JuMP.solver_name(psi_container.JuMPmodel)

    try
        optimizer_log[:solve_time] = MOI.get(psi_container.JuMPmodel, MOI.SolveTime())
    catch
        @warn("SolveTime() property not supported by $(optimizer_log[:solver])")
        optimizer_log[:solve_time] = "Not Supported by $(optimizer_log[:solver])"
    end
    return optimizer_log
end

# Function to create a dictionary for the time series of the simulation
function get_timestamps(op_problem::OperationsProblem)
    initial_time = model_initial_time(get_psi_container(op_problem))
    interval = PSY.get_time_series_resolution(op_problem.sys)
    horizon = get_horizon(get_settings(get_psi_container(op_problem)))
    range_time = collect(initial_time:interval:(initial_time + interval .* horizon))
    time_stamp = DataFrames.DataFrame(Range = range_time[:, 1])

    return time_stamp
end
