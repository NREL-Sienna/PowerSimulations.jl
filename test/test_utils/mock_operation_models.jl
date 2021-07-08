# NOTE: None of the models and function in this file are functional. All of these are used for testing purposes and do not represent valid examples either to develop custom
# models. Please refer to the documentation.

struct MockOperationProblem <: PSI.DecisionProblem end

function PSI.DecisionModel(
    ::Type{MockOperationProblem},
    ::Type{T},
    sys::PSY.System;
    kwargs...,
) where {T <: PM.AbstractPowerModel}
    settings = PSI.Settings(sys; kwargs...)
    return DecisionModel{MockOperationProblem}(ProblemTemplate(T), sys, settings, nothing)
end

function PSI.DecisionModel(::Type{MockOperationProblem}; kwargs...)
    sys = System(100.0)
    settings = PSI.Settings(sys; kwargs...)
    return DecisionModel{MockOperationProblem}(
        ProblemTemplate(CopperPlatePowerModel),
        sys,
        settings,
        nothing,
    )
end

# Only used for testing
function mock_construct_device!(problem::PSI.DecisionModel{MockOperationProblem}, model)
    set_device_model!(problem.template, model)
    template = PSI.get_template(model)
    PSI.optimization_container_init!(
        PSI.get_optimization_container(model),
        PSI.get_network_formulation(template),
        PSI.get_system(model),
    )
    PSI.construct_device!(
        PSI.get_optimization_container(model),
        PSI.get_system(model),
        model,
        PSI.get_network_formulation(template),
    )

    JuMP.@objective(
        PSI.get_jump_model(model),
        MOI.MIN_SENSE,
        PSI.get_optimization_container(model).cost_function
    )
    return
end

function mock_construct_network!(problem::PSI.DecisionModel{MockOperationProblem}, model)
    PSI.set_transmission_model!(problem.template, model)
    PSI.construct_network!(
        PSI.get_optimization_container(model),
        PSI.get_system(model),
        model,
        problem.template.branches,
    )
    return
end

function mock_uc_ed_simulation_problems(uc_horizon, ed_horizon)
    return SimulationProblems(
        UC = DecisionModel(MockOperationProblem; horizon = uc_horizon),
        ED = DecisionModel(MockOperationProblem; horizon = ed_horizon),
    )
end

function create_simulation_build_test_problems(
    template_uc = get_template_standard_uc_simulation(),
    template_ed = get_template_nomin_ed_simulation(),
    sys_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"),
    sys_ed = PSB.build_system(PSITestSystems, "c_sys5_ed"),
)
    c_sys5_uc =
        c_sys5_ed = return SimulationProblems(
            UC = DecisionModel(template_uc, sys_uc; optimizer = GLPK_optimizer),
            ED = DecisionModel(template_ed, sys_ed, optimizer = GLPK_optimizer),
        )
end

struct MockStagesStruct
    stages::Dict{Int, Int}
end

function Base.show(io::IO, struct_stages::MockStagesStruct)
    PSI._print_inter_stages(io, struct_stages.stages)
    println(io, "\n\n")
    PSI._print_intra_stages(io, struct_stages.stages)
end
