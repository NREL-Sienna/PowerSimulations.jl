# NOTE: None of the models and function in this file are functional. All of these are used for testing purposes and do not represent valid examples either to develop custom
# models. Please refer to the documentation.

struct MockOperationProblem <: PSI.DecisionProblem end
struct MockEmulationProblem <: PSI.EmulationProblem end

function PSI.DecisionModel(
    ::Type{MockOperationProblem},
    ::Type{T},
    sys::PSY.System;
    name=nothing,
    kwargs...,
) where {T <: PM.AbstractPowerModel}
    settings = PSI.Settings(sys; kwargs...)
    return DecisionModel{MockOperationProblem}(
        ProblemTemplate(T),
        sys,
        settings,
        nothing,
        name=name,
    )
end

function make_mock_forecast(horizon, resolution, interval, steps)
    init_time = DateTime("2024-01-01")
    timeseries_data = Dict{Dates.DateTime, Vector{Float64}}()
    for i in 1:steps
        forecast_timestamps = init_time + interval * i
        timeseries_data[forecast_timestamps] = rand(horizon)
    end
    return Deterministic(name="mock_forecast", data=timeseries_data, resolution=resolution)
end

function make_mock_singletimeseries(horizon, resolution)
    init_time = DateTime("2024-01-01")
    tstamps = collect(range(init_time, length=horizon, step=resolution))
    timeseries_data = TimeArray(tstamps, rand(horizon))
    return SingleTimeSeries(name="mock_timeseries", data=timeseries_data)
end

function PSI.DecisionModel(::Type{MockOperationProblem}; name=nothing, kwargs...)
    sys = System(100.0)
    add_component!(sys, Bus(nothing); skip_validation=true)
    l = PowerLoad(nothing)
    gen = ThermalStandard(nothing)
    set_bus!(l, get_component(Bus, sys, "init"))
    set_bus!(gen, get_component(Bus, sys, "init"))
    add_component!(sys, l; skip_validation=true)
    add_component!(sys, gen; skip_validation=true)
    forecast = make_mock_forecast(
        get(kwargs, :horizon, 24),
        get(kwargs, :resolution, Hour(1)),
        get(kwargs, :interval, Hour(1)),
        get(kwargs, :steps, 2),
    )
    add_time_series!(sys, l, forecast)

    settings = PSI.Settings(sys; horizon=get(kwargs, :horizon, 24))
    return DecisionModel{MockOperationProblem}(
        ProblemTemplate(CopperPlatePowerModel),
        sys,
        settings,
        nothing,
        name=name,
    )
end

function PSI.EmulationModel(::Type{MockEmulationProblem}; name=nothing, kwargs...)
    sys = System(100.0)
    add_component!(sys, Bus(nothing); skip_validation=true)
    l = PowerLoad(nothing)
    gen = ThermalStandard(nothing)
    set_bus!(l, get_component(Bus, sys, "init"))
    set_bus!(gen, get_component(Bus, sys, "init"))
    add_component!(sys, l; skip_validation=true)
    add_component!(sys, gen; skip_validation=true)
    single_ts = make_mock_singletimeseries(
        get(kwargs, :horizon, 24),
        get(kwargs, :resolution, Hour(1)),
    )
    add_time_series!(sys, l, single_ts)

    settings = PSI.Settings(sys; horizon=get(kwargs, :horizon, 24))
    return EmulationModel{MockEmulationProblem}(
        ProblemTemplate(CopperPlatePowerModel),
        sys,
        settings,
        nothing,
        name=name,
    )
end

# Only used for testing
function mock_construct_device!(
    problem::PSI.DecisionModel{MockOperationProblem},
    model;
    built_for_recurrent_solves=false,
)
    set_device_model!(problem.template, model)
    template = PSI.get_template(problem)
    PSI.init_optimization_container!(
        PSI.get_optimization_container(problem),
        PSI.get_network_formulation(template),
        PSI.get_system(problem),
    )
    PSI.get_optimization_container(problem).built_for_recurrent_solves =
        built_for_recurrent_solves
    PSI.initialize_system_expressions!(
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

    PSI.check_optimization_container(PSI.get_optimization_container(problem))

    JuMP.@objective(
        PSI.get_jump_model(problem),
        MOI.MIN_SENSE,
        PSI.get_objective_fuction(
            PSI.get_optimization_container(problem).objective_function,
        )
    )
    return
end

function mock_construct_network!(problem::PSI.DecisionModel{MockOperationProblem}, model)
    PSI.set_network_model!(problem.template, model)
    PSI.construct_network!(
        PSI.get_optimization_container(problem),
        PSI.get_system(problem),
        model,
        problem.template.branches,
    )
    return
end

function mock_uc_ed_simulation_problems(uc_horizon, ed_horizon)
    return SimulationModels([
        DecisionModel(MockOperationProblem; horizon=uc_horizon, name="UC"),
        DecisionModel(
            MockOperationProblem;
            horizon=ed_horizon,
            resolution=Minute(5),
            name="ED",
        ),
    ])
end

function create_simulation_build_test_problems(
    template_uc=get_template_standard_uc_simulation(),
    template_ed=get_template_nomin_ed_simulation(),
    sys_uc=PSB.build_system(PSITestSystems, "c_sys5_uc"),
    sys_ed=PSB.build_system(PSITestSystems, "c_sys5_ed"),
)
    return SimulationModels(
        decision_models=[
            DecisionModel(template_uc, sys_uc; name="UC", optimizer=GLPK_optimizer),
            DecisionModel(template_ed, sys_ed; name="ED", optimizer=GLPK_optimizer),
        ],
    )
end

struct MockStagesStruct
    stages::Dict{Int, Int}
end

function Base.show(io::IO, struct_stages::MockStagesStruct)
    PSI._print_inter_stages(io, struct_stages.stages)
    println(io, "\n\n")
    return PSI._print_intra_stages(io, struct_stages.stages)
end

function setup_ic_model_container!(model::DecisionModel)
    # This function is only for testing purposes.
    if !PSI.is_empty(model)
        PSI.reset!(model)
    end

    PSI.init_optimization_container!(
        PSI.get_optimization_container(model),
        PSI.get_network_formulation(PSI.get_template(model)),
        PSI.get_system(model),
    )

    PSI.init_model_store_params!(model)

    PSI.populate_aggregated_service_model!(PSI.get_template(model), PSI.get_system(model))
    PSI.populate_contributing_devices!(PSI.get_template(model), PSI.get_system(model))
    PSI.add_services_to_device_model!(PSI.get_template(model))

    @info "Make Initial Conditions Model"
    PSI.set_output_dir!(model, mktempdir(cleanup=true))
    PSI.build_initial_conditions!(model)
    PSI.initialize!(model)
    return
end
