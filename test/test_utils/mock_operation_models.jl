# NOTE: None of the models and function in this file are functional. All of these are used for testing purposes and do not represent valid examples either to develop custom
# models. Please refer to the documentation.

struct MockOperationProblem <: PSI.AbstractOperationsProblem end

function PSI.OperationsProblem(
    ::Type{MockOperationProblem},
    ::Type{T},
    sys::PSY.System;
    kwargs...
) where T <: PM.AbstractPowerModel
    settings = PSI.Settings(sys; kwargs...)
    return OperationsProblem{MockOperationProblem}(OperationsProblemTemplate(T), sys,
    settings, nothing)
end

function mock_construct_device!(problem::PSI.OperationsProblem{MockOperationProblem}, label, model)
    set_model!(problem.template, label, model)
    PSI.mock_construct_device!(PSI.get_optimization_container(problem), PSI.get_system(problem), model, problem.template.transmission)
end
