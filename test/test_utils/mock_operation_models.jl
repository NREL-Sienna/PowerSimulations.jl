# NOTE: None of the models and function in this file are functional. All of these are used for testing purposes and do not represent valid examples either to develop custom
# models. Please refer to the documentation.

struct MockOperationProblem <: PSI.AbstractOperationsProblem end

function PSI.OperationsProblem(
    ::Type{MockOperationProblem},
    ::Type{T},
    sys::PSY.System;
    kwargs...,
) where {T <: PM.AbstractPowerModel}
    settings = PSI.Settings(sys; kwargs...)
    return OperationsProblem{MockOperationProblem}(
        OperationsProblemTemplate(T),
        sys,
        settings,
        nothing,
    )
end

function PSI.OperationsProblem(::Type{MockOperationProblem}; kwargs...)
    sys = System(100.0)
    settings = PSI.Settings(sys; kwargs...)
    return OperationsProblem{MockOperationProblem}(
        OperationsProblemTemplate(CopperPlatePowerModel),
        sys,
        settings,
        nothing,
    )
end

# Only used for testing
function mock_construct_device!(problem::PSI.OperationsProblem{MockOperationProblem}, model)
    set_device_model!(problem.template, model)
    template = PSI.get_template(problem)
    PSI.optimization_container_init!(
        PSI.get_optimization_container(problem),
        PSI.get_transmission_model(template),
        PSI.get_system(problem),
    )
    PSI.set_network_model!(PSI.get_optimization_container(problem), PSI.get_transmission_model(template))
    PSI.construct_device!(
        PSI.get_optimization_container(problem),
        PSI.get_system(problem),
        model,
        problem.template.transmission,
    )

    JuMP.@objective(
        PSI.get_jump_model(problem),
        MOI.MIN_SENSE,
        PSI.get_optimization_container(problem).cost_function
    )
end

function mock_construct_network!(
    problem::PSI.OperationsProblem{MockOperationProblem},
    model,
)
    PSI.set_transmission_model!(problem.template, model)
    PSI.construct_network!(
        PSI.get_optimization_container(problem),
        PSI.get_system(problem),
        model,
    )
end

function mock_uc_ed_simulation_problems(uc_horizon, ed_horizon)
    return SimulationProblems(
        UC = OperationsProblem(MockOperationProblem; horizon = uc_horizon),
        ED = OperationsProblem(MockOperationProblem; horizon = ed_horizon),
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
            UC = OperationsProblem(template_uc, sys_uc; optimizer = GLPK_optimizer),
            ED = OperationsProblem(template_ed, sys_ed, optimizer = GLPK_optimizer),
        )
end

struct FakeStagesStruct
    stages::Dict{Int, Int}
end

function Base.show(io::IO, struct_stages::FakeStagesStruct)
    PSI._print_inter_stages(io, struct_stages.stages)
    println(io, "\n\n")
    PSI._print_intra_stages(io, struct_stages.stages)
end
