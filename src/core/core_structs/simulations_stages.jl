######## Internal Simulation Object Structs ########
mutable struct StageInternal
    execution_count::Int64
    psi_container::PSIContainer
end

mutable struct Stage{M<:AbstractOperationsProblem}
    number::Int64
    template::OperationsProblemTemplate
    sys::PSY.System
    optimizer::JuMP.OptimizerFactory
    internal::Union{Nothing, StageInternal}

    function Stage(number::Int64,
                   ::Type{M},
                   template::OperationsProblemTemplate,
                   sys::PSY.System,
                   optimizer::JuMP.OptimizerFactory) where M<:AbstractOperationsProblem

    new{M}(number,
           template,
           sys,
           optimizer,
           nothing)

    end

end

function Stage(number::Int64,
                template::OperationsProblemTemplate,
                sys::PSY.System,
                optimizer::JuMP.OptimizerFactory) where M<:AbstractOperationsProblem
    return Stage(number, GenericOpProblem, sys, optimizer)
end

get_execution_count(s::Stage) = s.internal.execution_count
get_sys(s::Stage) = s.sys
get_template(s::Stage) = s.template
