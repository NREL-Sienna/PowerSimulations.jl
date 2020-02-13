######## Internal Simulation Object Structs ########
mutable struct StageInternal
    number::Int
    executions::Int
    execution_count::Int
    synchronized_executions::Dict{Int, Int} # Number of executions per upper level stage step
    psi_container::Union{Nothing, PSIContainer}
    cache_dict::Dict{Type{<:AbstractCache}, AbstractCache}
    # Can probably be eliminated and use getter functions from
    # Simulation object. Need to determine if its always available in the stage update steps.
    chronolgy_dict::Dict{Int, <:FeedForwardChronology}
    function StageInternal(number, executions, execution_count, psi_container)
        new(
            number,
            executions,
            execution_count,
            Dict{Int, Int}(),
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
