@testset "Simulation Build Tests" begin
    models = create_simulation_build_test_problems(get_template_basic_uc_simulation())
    sequence = SimulationSequence(
        models = models,
        feedforwards = Dict(
            "ED" => [
                SemiContinuousFeedforward(
                    component_type = ThermalStandard,
                    source = OnVariable,
                    affected_values = [ActivePowerVariable],
                ),
            ],
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    sim = Simulation(
        name = "test",
        steps = 1,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(cleanup = true),
    )

    build_out = build!(sim)
    @test build_out == PSI.BuildStatus.BUILT

    for field in fieldnames(SimulationSequence)
        if fieldtype(SimulationSequence, field) == Union{Dates.DateTime, Nothing}
            @test getfield(sim.sequence, field) !== nothing
        end
    end

    @test length(findall(x -> x == 2, sequence.execution_order)) == 24
    @test length(findall(x -> x == 1, sequence.execution_order)) == 1

    state = PSI.get_simulation_state(sim)

    uc_vars = [OnVariable, StartVariable, StopVariable]
    ed_vars = [ActivePowerVariable]
    for (key, data) in state.decision_states.variables
        if PSI.get_entry_type(key) ∈ uc_vars
            _, count = size(data.values)
            @test count == 24
        elseif PSI.get_entry_type(key) ∈ ed_vars
            _, count = size(data.values)
            @test count == 288
        end
    end
end

@testset "Simulation with provided initial time" begin
    models = create_simulation_build_test_problems(get_template_basic_uc_simulation())
    sequence = SimulationSequence(
        models = models,
        feedforwards = Dict(
            "ED" => [
                SemiContinuousFeedforward(
                    component_type = ThermalStandard,
                    source = OnVariable,
                    affected_values = [ActivePowerVariable],
                ),
            ],
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    second_day = DateTime("1/1/2024  23:00:00", "d/m/y  H:M:S") + Hour(1)
    sim = Simulation(
        name = "test",
        steps = 1,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(cleanup = true),
        initial_time = second_day,
    )
    build_out = build!(sim)
    @test build_out == PSI.BuildStatus.BUILT

    for model in PSI.get_decision_models(PSI.get_models(sim))
        @test PSI.get_initial_time(model) == second_day
    end

    for field in fieldnames(SimulationSequence)
        if fieldtype(SimulationSequence, field) == Union{Dates.DateTime, Nothing}
            @test getfield(sim.sequence, field) !== nothing
        end
    end

    @test length(findall(x -> x == 2, sequence.execution_order)) == 24
    @test length(findall(x -> x == 1, sequence.execution_order)) == 1
end

@testset "Negative Tests (Bad Parametrization)" begin
    models = create_simulation_build_test_problems(get_template_basic_uc_simulation())
    sequence = SimulationSequence(
        models = models,
        feedforwards = Dict(
            "ED" => [
                SemiContinuousFeedforward(
                    component_type = ThermalStandard,
                    source = OnVariable,
                    affected_values = [ActivePowerVariable],
                ),
            ],
        ),
        ini_cond_chronology = InterProblemChronology(),
    )

    @test_throws UndefKeywordError sim = Simulation(name = "test", steps = 1)

    sim = Simulation(
        name = "test",
        steps = 1,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(cleanup = true),
        initial_time = Dates.now(),
    )

    @test_throws IS.ConflictingInputsError build!(sim)

    sim = Simulation(
        name = "fake_path",
        steps = 1,
        models = models,
        sequence = sequence,
        simulation_folder = "fake_path",
    )

    @test_throws IS.ConflictingInputsError PSI._check_folder(sim)
end

@testset "Multi-Stage Hydro Simulation Build" begin
    sys_md = PSB.build_system(SIIPExampleSystems, "5_bus_hydro_wk_sys")

    sys_uc = PSB.build_system(SIIPExampleSystems, "5_bus_hydro_uc_sys")
    transform_single_time_series!(sys_uc, 48, Hour(24))

    sys_ed = PSB.build_system(SIIPExampleSystems, "5_bus_hydro_ed_sys")

    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, ThermalStandard, ThermalBasicUnitCommitment)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, HydroEnergyReservoir, HydroDispatchReservoirBudget)

    models = SimulationModels([
        DecisionModel(template, name = "MD", sys_md, system_to_file = false),
        DecisionModel(template, name = "UC", sys_uc, system_to_file = false),
        DecisionModel(template, name = "ED", sys_ed, system_to_file = false),
    ])

    feedforwards = Dict(
        "UC" => [
            IntegralLimitFeedforward(
                source = ActivePowerVariable,
                affected_values = [ActivePowerVariable],
                component_type = HydroEnergyReservoir,
                number_of_periods = 24,
            ),
        ],
        "ED" => [
            IntegralLimitFeedforward(
                source = ActivePowerVariable,
                affected_values = [ActivePowerVariable],
                component_type = HydroEnergyReservoir,
                number_of_periods = 12,
            ),
        ],
    )

    test_sequence = SimulationSequence(
        models = models,
        ini_cond_chronology = InterProblemChronology(),
        feedforwards = feedforwards,
    )

    sim = Simulation(
        name = "test_md",
        steps = 2,
        models = models,
        sequence = test_sequence,
        simulation_folder = mktempdir(cleanup = true),
    )
    # @test build!(sim, serialize = false) == PSI.BuildStatus.BUILT
end
