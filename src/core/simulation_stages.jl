######## Internal Simulation Object Structs ########
mutable struct StageInternal
    number::Int64
    execution_count::Int64
    psi_container::Union{Nothing, PSIContainer}
    cache_dict::Dict{Type{<:AbstractCache}, AbstractCache}

    function StageInternal(number, execution_count, psi_container)
        new(number, execution_count, psi_container, Dict{Type{<:AbstractCache}, AbstractCache}())
    end
end

mutable struct Stage{M<:AbstractOperationsProblem}
    template::OperationsProblemTemplate
    sys::PSY.System
    optimizer::JuMP.OptimizerFactory
    internal::Union{Nothing, StageInternal}

    function Stage(::Type{M},
                   template::OperationsProblemTemplate,
                   sys::PSY.System,
                   optimizer::JuMP.OptimizerFactory) where M<:AbstractOperationsProblem

    new{M}(template,
           sys,
           optimizer,
           nothing)

    end

end

function Stage(template::OperationsProblemTemplate,
               sys::PSY.System,
               optimizer::JuMP.OptimizerFactory) where M<:AbstractOperationsProblem
    return Stage(number, GenericOpProblem, sys, optimizer)
end

get_execution_count(s::Stage) = s.internal.execution_count
get_sys(s::Stage) = s.sys
get_template(s::Stage) = s.template
