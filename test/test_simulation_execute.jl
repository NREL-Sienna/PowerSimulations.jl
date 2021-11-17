@testset "Single stage sequential tests" begin
    template_ed = get_template_nomin_ed_simulation()
    c_sys = PSB.build_system(PSITestSystems, "c_sys5_uc")
    models = SimulationModels([
        DecisionModel(template_ed, c_sys, name = "ED", optimizer = ipopt_optimizer),
    ])
    test_sequence = SimulationSequence(
        models = models,
        intervals = Dict("ED" => (Hour(24), 0)),
        ini_cond_chronology = InterProblemChronology(),
    )
    sim_single = Simulation(
        name = "consecutive",
        steps = 2,
        models = models,
        sequence = test_sequence,
        simulation_folder = mktempdir(cleanup = true),
    )
    build_out = build!(sim_single)
    @test build_out == PSI.BuildStatus.BUILT
    execute_out = execute!(sim_single)
    @test execute_out == PSI.RunStatus.SUCCESSFUL
end

@testset "All stages executed - No Cache" begin
    template_uc = get_template_basic_uc_simulation()
    template_ed = get_template_nomin_ed_simulation()
    set_device_model!(template_ed, HydroEnergyReservoir, HydroDispatchReservoirBudget)
    set_network_model!(
        template_ed,
        CopperPlatePowerBalance,
        duals = [CopperPlateBalanceConstraint],
    )
    c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
    c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
    problems = SimulationModels(
        UC = DecisionModel(
            template_uc,
            c_sys5_hy_uc;
            optimizer = GLPK_optimizer,
            balance_slack_variables = true,
        ),
        ED = DecisionModel(
            template_ed,
            c_sys5_hy_ed;
            optimizer = ipopt_optimizer,
            # Needed do to inconsistency in the test data
            balance_slack_variables = true,
        ),
    )

    sequence = SimulationSequence(
        problems = problems,
        feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
        intervals = Dict("UC" => (Hour(24), 0), "ED" => (Hour(1), 0)),
        feedforward = Dict(
            ("ED", :devices, :ThermalStandard) => SemiContinuousFeedforward(
                binary_source_problem = OnVariable,
                affected_variables = [ActivePowerVariable],
            ),
            ("ED", :devices, :HydroEnergyReservoir) => IntegralLimitFeedforward(
                variable_source_problem = ActivePowerVariable,
                affected_variables = [ActivePowerVariable],
            ),
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    sim = Simulation(
        name = "no_cache",
        steps = 2,
        problems = problems,
        sequence = sequence,
        simulation_folder = mktempdir(cleanup = true),
    )

    build_out = build!(sim; console_level = Logging.Info)
    @test build_out == PSI.BuildStatus.BUILT
    execute_out = execute!(sim)
    @test execute_out == PSI.RunStatus.SUCCESSFUL
end

@testset "Simulation Single Stage with Cache" begin
    c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
    template = get_template_hydro_st_ed()
    problems = SimulationModels(
        ED = DecisionModel(template, c_sys5_hy_ed; optimizer = ipopt_optimizer),
    )

    single_sequence = SimulationSequence(
        problems = problems,
        intervals = Dict("ED" => (Hour(1), 0)),
        ini_cond_chronology = IntraProblemChronology(),
    )

    sim_single_wcache = Simulation(
        name = "cache_st",
        steps = 2,
        problems = problems,
        sequence = single_sequence,
        simulation_folder = mktempdir(cleanup = true),
    )
    build_out = build!(sim_single_wcache)
    @test build_out == PSI.BuildStatus.BUILT
    execute_out = execute!(sim_single_wcache)
    @test execute_out == PSI.RunStatus.SUCCESSFUL
end

@testset "Simulation with 2-Stages and Cache" begin
    template_uc = get_template_hydro_st_uc()
    template_ed = get_template_hydro_st_ed()
    c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_ems_uc")
    c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ems_ed")
    problems = SimulationModels(
        UC = DecisionModel(template_uc, c_sys5_hy_uc; optimizer = GLPK_optimizer),
        ED = DecisionModel(template_ed, c_sys5_hy_ed; optimizer = GLPK_optimizer),
    )

    sequence_cache = SimulationSequence(
        problems = problems,
        feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
        intervals = Dict("UC" => (Hour(24), 0), "ED" => (Hour(1), 0)),
        feedforward = Dict(
            ("ED", :devices, :ThermalStandard) => SemiContinuousFeedforward(
                binary_source_problem = OnVariable,
                affected_variables = [ActivePowerVariable],
            ),
            ("ED", :devices, :HydroEnergyReservoir) => IntegralLimitFeedforward(
                variable_source_problem = ActivePowerVariable,
                affected_variables = [ActivePowerVariable],
            ),
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    sim_cache = Simulation(
        name = "cache",
        steps = 2,
        problems = problems,
        sequence = sequence_cache,
        simulation_folder = mktempdir(cleanup = true),
    )
    build_out = build!(sim_cache)
    @test build_out == PSI.BuildStatus.BUILT
    execute_out = execute!(sim_cache)
    @test execute_out == PSI.RunStatus.SUCCESSFUL
end

@testset "Test Recedin Horizon Chronology" begin
    template_uc = get_template_basic_uc_simulation()
    template_ed = get_template_nomin_ed_simulation()
    c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
    c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
    problems = SimulationModels(
        UC = DecisionModel(template_uc, c_sys5_hy_uc; optimizer = GLPK_optimizer),
        ED = DecisionModel(
            template_ed,
            c_sys5_hy_ed;
            optimizer = ipopt_optimizer,
            # Added because of data issues
            balance_slack_variables = true,
        ),
    )

    sequence = SimulationSequence(
        problems = problems,
        feedforward_chronologies = Dict(("UC" => "ED") => 0),
        intervals = Dict("UC" => (Hour(24), 0), "ED" => (Minute(60), 0)),
        feedforward = Dict(
            ("ED", :devices, :ThermalStandard) => SemiContinuousFeedforward(
                binary_source_problem = OnVariable,
                affected_variables = [ActivePowerVariable],
            ),
        ),
        ini_cond_chronology = InterProblemChronology(),
    )

    sim = Simulation(
        name = "receding_horizon",
        steps = 2,
        problems = problems,
        sequence = sequence,
        simulation_folder = mktempdir(cleanup = true),
    )
    build_out = build!(sim)
    @test build_out == PSI.BuildStatus.BUILT
    execute_out = execute!(sim)
    @test execute_out == PSI.RunStatus.SUCCESSFUL
end

@testset "Test Simulation Utils" begin
    template_uc = get_template_basic_uc_simulation()
    template_ed = get_template_nomin_ed_simulation()
    set_device_model!(template_ed, HydroEnergyReservoir, HydroDispatchReservoirBudget)
    c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
    c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
    problems = SimulationModels(
        UC = DecisionModel(
            template_uc,
            c_sys5_hy_uc;
            optimizer = GLPK_optimizer,
            constraint_duals = [ConstraintKey(CopperPlateBalanceConstraint, PSY.System)],
        ),
        ED = DecisionModel(
            template_ed,
            c_sys5_hy_ed;
            optimizer = ipopt_optimizer,
            # Added because of data issues
            balance_slack_variables = true,
            constraint_duals = [ConstraintKey(CopperPlateBalanceConstraint, PSY.System)],
        ),
    )

    sequence = SimulationSequence(
        problems = problems,
        feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
        intervals = Dict("UC" => (Hour(24), 0), "ED" => (Hour(1), 0)),
        feedforward = Dict(
            ("ED", :devices, :ThermalStandard) => SemiContinuousFeedforward(
                binary_source_problem = OnVariable,
                affected_variables = [ActivePowerVariable],
            ),
            ("ED", :devices, :HydroEnergyReservoir) => IntegralLimitFeedforward(
                variable_source_problem = ActivePowerVariable,
                affected_variables = [ActivePowerVariable],
            ),
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    sim = Simulation(
        name = "aggregation",
        steps = 2,
        problems = problems,
        sequence = sequence,
        simulation_folder = mktempdir(cleanup = true),
    )

    build_out = build!(sim; console_level = Logging.Info)
    @test build_out == PSI.BuildStatus.BUILT
    execute_out = execute!(sim)
    @test execute_out == PSI.RunStatus.SUCCESSFUL

    @testset "Verify simulation events" begin
        file = joinpath(PSI.get_simulation_dir(sim), "recorder", "simulation.log")
        @test isfile(file)
        events = PSI.list_simulation_events(
            PSI.InitialConditionUpdateEvent,
            PSI.get_simulation_dir(sim);
            step = 1,
        )
        @test length(events) == 0
        events = PSI.list_simulation_events(
            PSI.InitialConditionUpdateEvent,
            PSI.get_simulation_dir(sim);
            step = 2,
        )
        @test length(events) == 10
        PSI.show_simulation_events(
            devnull,
            PSI.InitialConditionUpdateEvent,
            PSI.get_simulation_dir(sim),
            ;
            step = 2,
        )
        events = PSI.list_simulation_events(
            PSI.InitialConditionUpdateEvent,
            PSI.get_simulation_dir(sim);
            step = 1,
            problem = 1,
        )
        @test length(events) == 0
        events = PSI.list_simulation_events(
            PSI.InitialConditionUpdateEvent,
            PSI.get_simulation_dir(sim),
            ;
            step = 2,
            problem = 1,
        )
        @test length(events) == 10
        PSI.show_simulation_events(
            devnull,
            PSI.InitialConditionUpdateEvent,
            PSI.get_simulation_dir(sim),
            ;
            step = 2,
            problem = 1,
        )
    end

    # @testset "Check Serialization - Deserialization of Sim" begin
    #     path = mktempdir()
    #     files_path = PSI.serialize_simulation(sim; path = path)
    #     deserialized_sim = Simulation(files_path, stage_info)
    #     build_out = build!(deserialized_sim)
    #     @test build_out == PSI.BuildStatus.BUILT
    #     for stage in values(PSI.get_stages(deserialized_sim))
    #         @test PSI.is_stage_built(stage)
    #     end
    # end

    # TODO: Enable for test coverage later
    # @testset "Test print methods" begin
    #     list = [sim, sim.sequence, sim.stages["UC"]]
    #     _test_plain_print_methods(list)
    # end
end
