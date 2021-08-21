# NOTE: None of the models and function in this file are functional. All of these are used for testing purposes and do not represent valid examples either to develop custom
# models. Please refer to the documentation.

struct MockOperationProblem <: PSI.DecisionProblem end

function PSI.DecisionModel(
    ::Type{MockOperationProblem},
    ::Type{T},
    sys::PSY.System;
    name = nothing,
    kwargs...,
) where {T <: PM.AbstractPowerModel}
    settings = PSI.Settings(sys; kwargs...)
    return DecisionModel{MockOperationProblem}(
        ProblemTemplate(T),
        sys,
        settings,
        nothing,
        name = name,
    )
end

function PSI.DecisionModel(::Type{MockOperationProblem}; name = nothing, kwargs...)
    sys = System(100.0)
    settings = PSI.Settings(sys; kwargs...)
    return DecisionModel{MockOperationProblem}(
        ProblemTemplate(CopperPlatePowerModel),
        sys,
        settings,
        nothing,
        name = name,
    )
end

# Only used for testing
function mock_construct_device!(problem::PSI.DecisionModel{MockOperationProblem}, model)
    set_device_model!(problem.template, model)
    template = PSI.get_template(problem)
    PSI.optimization_container_init!(
        PSI.get_optimization_container(problem),
        PSI.get_network_formulation(template),
        PSI.get_system(problem),
    )
    if PSI.validate_available_devices(model, PSI.get_system(problem))
        PSI.construct_device!(
            PSI.get_optimization_container(problem),
            PSI.get_system(problem),
            PSI.ArgumentConstructStage(),
            model,
            PSI.get_network_formulation(template),
        )
        PSI.construct_device!(
            PSI.get_optimization_container(problem),
            PSI.get_system(problem),
            PSI.ModelConstructStage(),
            model,
            PSI.get_network_formulation(template),
        )
    end

    JuMP.@objective(
        PSI.get_jump_model(problem),
        MOI.MIN_SENSE,
        PSI.get_optimization_container(problem).cost_function
    )
    return
end

function mock_construct_network!(problem::PSI.DecisionModel{MockOperationProblem}, model)
    PSI.set_transmission_model!(problem.template, model)
    PSI.construct_network!(
        PSI.get_optimization_container(problem),
        PSI.get_system(problem),
        model,
        problem.template.branches,
    )
    return
end

function mock_uc_ed_simulation_problems(uc_horizon, ed_horizon)
    return SimulationModels(
        DecisionModel(MockOperationProblem; horizon = uc_horizon, name = "UC"),
        DecisionModel(MockOperationProblem; horizon = ed_horizon, name = "ED"),
    )
end

function create_simulation_build_test_problems(
    template_uc = get_template_standard_uc_simulation(),
    template_ed = get_template_nomin_ed_simulation(),
    sys_uc = PSB.build_system(PSITestSystems, "c_sys5_uc"),
    sys_ed = PSB.build_system(PSITestSystems, "c_sys5_ed"),
)
    return SimulationModels(
        DecisionModel(template_uc, sys_uc; name = "UC", optimizer = GLPK_optimizer),
        DecisionModel(template_ed, sys_ed; name = "ED", optimizer = GLPK_optimizer),
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
