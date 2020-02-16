######## Internal Simulation Object Structs ########
mutable struct StageInternal
    number::Int
    executions::Int
    execution_count::Int
    # This line keeps track of the executions of a stage relative to other stages.
    # This might be needed in the future to run multiple stages. For now it is disabled
    #synchronized_executions::Dict{Int, Int} # Number of executions per upper level stage step
    psi_container::Union{Nothing, PSIContainer}
    caches::Set{<:CacheKey{<:AbstractCache, <:PSY.Device}}
    chronolgy_dict::Dict{Int, <:FeedForwardChronology}
    function StageInternal(number, executions, execution_count, psi_container)
        new(
            number,
            executions,
            execution_count,
            #Dict{Int, Int}(),
            psi_container,
            Set{CacheKey{<:AbstractCache, <:PSY.Device}}(),
            Dict{Int, FeedForwardChronology}(),
        )
    end
end

@doc raw"""
    Stage({M<:AbstractOperationsProblem}
        template::OperationsProblemTemplate
        sys::PSY.System
        optimizer::JuMP.OptimizerFactory
        internal::Union{Nothing, StageInternal}
        )

""" # TODO: Add DocString
mutable struct Stage{M <: AbstractOperationsProblem}
    template::OperationsProblemTemplate
    sys::PSY.System
    optimizer::JuMP.OptimizerFactory
    internal::Union{Nothing, StageInternal}

    function Stage(
        ::Type{M},
        template::OperationsProblemTemplate,
        sys::PSY.System,
        optimizer::JuMP.OptimizerFactory,
    ) where {M <: AbstractOperationsProblem}

        new{M}(template, sys, optimizer, nothing)

    end
end

function Stage(
    template::OperationsProblemTemplate,
    sys::PSY.System,
    optimizer::JuMP.OptimizerFactory,
) where {M <: AbstractOperationsProblem}
    return Stage(GenericOpProblem, template, sys, optimizer)
end

get_execution_count(s::Stage) = s.internal.execution_count
get_executions(s::Stage) = s.internal.executions
get_sys(s::Stage) = s.sys
get_template(s::Stage) = s.template
get_number(s::Stage) = s.internal.number
get_psi_container(s::Stage) = s.internal.psi_container

function run_stage(
    stage::Stage,
    start_time::Dates.DateTime,
    results_path::String;
    kwargs...,
)
    @assert stage.internal.psi_container.JuMPmodel.moi_backend.state != MOIU.NO_OPTIMIZER
    timed_log = Dict{Symbol, Any}()

    model = stage.internal.psi_container.JuMPmodel
    _, timed_log[:timed_solve_time], timed_log[:solve_bytes_alloc], timed_log[:sec_in_gc] =
        @timed JuMP.optimize!(model)

    @info "JuMP.optimize! completed" timed_log

    model_status = JuMP.primal_status(stage.internal.psi_container.JuMPmodel)
    if model_status != MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        error("Stage $(stage.internal.number) status is $(model_status)")
    end
    # TODO: Add Fallback when optimization fails
    retrieve_duals = get(kwargs, :constraints_duals, nothing)
    if !isnothing(retrieve_duals) &&
       !isnothing(get_constraints(stage.internal.psi_container))
        _export_model_result(stage, start_time, results_path, retrieve_duals)
    else
        _export_model_result(stage, start_time, results_path)
    end
    _export_optimizer_log(timed_log, stage.internal.psi_container, results_path)
    stage.internal.execution_count += 1
    # Reset execution count
    if stage.internal.execution_count == stage.internal.executions
        stage.internal.execution_count = 0
    end
    return
end

# Here because requires the stage to be defined
# This is a method a user defining a custom cache will have to define. This is the definition
# in PSI for the building the TimeStatusChange
function get_initial_cache(cache::AbstractCache, stage::Stage)
    throw(ArgumentError("Initialization method for cache $(typeof(cache)) not defined"))
end

function get_initial_cache(cache::TimeStatusChange, stage::Stage)
    ini_cond_on = get_initial_conditions(
        stage.internal.psi_container,
        TimeDurationON,
        cache.device_type,
    )

    ini_cond_off = get_initial_conditions(
        stage.internal.psi_container,
        TimeDurationOFF,
        cache.device_type,
    )

    device_axes = Set((
        PSY.get_name(ic.device) for ic in Iterators.Flatten([ini_cond_on, ini_cond_off])
    ))
    value_array = JuMP.Containers.DenseAxisArray{Dict{Symbol, Float64}}(undef, device_axes)

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
            throw(IS.ConflictingInputsError("Initial Conditions for $(device_name) are not compatible. The values provided are invalid"))
        end
    end

    return value_array
end
