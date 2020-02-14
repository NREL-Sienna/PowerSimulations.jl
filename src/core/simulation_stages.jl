######## Internal Simulation Object Structs ########
mutable struct StageInternal
    number::Int
    executions::Int
    execution_count::Int
    # This line keeps track of the executions of a stage relative to other stages.
    # This might be needed in the future to run multiple stages. For now it is disabled
    #synchronized_executions::Dict{Int, Int} # Number of executions per upper level stage step
    psi_container::Union{Nothing, PSIContainer}
    cache_dict::Dict{Type{<:AbstractCache}, AbstractCache}
    chronolgy_dict::Dict{Int, <:FeedForwardChronology}
    function StageInternal(number, executions, execution_count, psi_container)
        new(
            number,
            executions,
            execution_count,
            #Dict{Int, Int}(),
            psi_container,
            Dict{Type{<:AbstractCache}, AbstractCache}(),
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
get_cache(s::Stage, ::Type{T}) where {T <: AbstractCache} =
    get(s.internal.cache_dict, T, nothing)

################################Cache Update################################################
function update_cache!(c::TimeStatusChange, stage::Stage)
    parameter = get_parameter_array(stage.internal.psi_container, c.ref)
    for name in parameter.axes[1]
        param_status = PJ.value(parameter[name])
        if c.value[name][:status] == param_status
            c.value[name][:count] += 1.0
        elseif c.value[name][:status] != param_status
            c.value[name][:count] = 1.0
            c.value[name][:status] = param_status
        end
    end

    return
end

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
    #Reset execution count
    if stage.internal.execution_count == stage.internal.executions
        stage.internal.execution_count = 0
    end
    return
end
