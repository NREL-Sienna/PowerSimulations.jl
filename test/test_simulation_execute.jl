function test_single_stage_sequential(in_memory, rebuild)
    template_ed = get_template_nomin_ed_simulation()
    c_sys = PSB.build_system(PSITestSystems, "c_sys5_uc")
    models = SimulationModels([
        DecisionModel(
            template_ed,
            c_sys;
            name = "ED",
            optimizer = ipopt_optimizer,
            rebuild_model = rebuild,
        ),
    ])
    test_sequence =
        SimulationSequence(;
            models = models,
            ini_cond_chronology = InterProblemChronology(),
        )
    sim_single = Simulation(;
        name = "consecutive",
        steps = 2,
        models = models,
        sequence = test_sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )
    build_out = build!(sim_single)
    @test build_out == PSI.SimulationBuildStatus.BUILT
    execute_out = execute!(sim_single; in_memory = in_memory)
    @test execute_out == PSI.RunStatus.SUCCESSFULLY_FINALIZED
end

@testset "Single stage sequential tests" begin
    for in_memory in (true, false), rebuild in (true, false)
        test_single_stage_sequential(in_memory, rebuild)
    end
end

function test_2_stage_decision_models_with_feedforwards(in_memory)
    template_uc = get_template_basic_uc_simulation()
    template_ed = get_template_nomin_ed_simulation()
    set_device_model!(template_ed, InterruptiblePowerLoad, StaticPowerLoad)
    set_network_model!(template_uc, NetworkModel(
        CopperPlatePowerModel,
        # MILP "duals" not supported with free solvers
        # duals = [CopperPlateBalanceConstraint],
    ))
    set_network_model!(
        template_ed,
        NetworkModel(
            CopperPlatePowerModel;
            duals = [CopperPlateBalanceConstraint],
            use_slacks = true,
        ),
    )
    c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
    c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_uc,
                c_sys5_hy_uc;
                name = "UC",
                optimizer = HiGHS_optimizer),
            DecisionModel(
                template_ed,
                c_sys5_hy_ed;
                name = "ED",
                optimizer = ipopt_optimizer,
            ),
        ],
    )

    sequence = SimulationSequence(;
        models = models,
        feedforwards = Dict(
            "ED" => [
                SemiContinuousFeedforward(;
                    component_type = ThermalStandard,
                    source = OnVariable,
                    affected_values = [ActivePowerVariable],
                ),
            ],
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    sim = Simulation(;
        name = "no_cache",
        steps = 2,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )

    build_out = build!(sim; console_level = Logging.Info)
    @test build_out == PSI.SimulationBuildStatus.BUILT
    execute_out = execute!(sim; in_memory = in_memory)
    @test execute_out == PSI.RunStatus.SUCCESSFULLY_FINALIZED
end

@testset "2-Stage Decision Models with FeedForwards" begin
    for in_memory in (true, false)
        test_2_stage_decision_models_with_feedforwards(in_memory)
    end
end

@testset "Test Simulation Utils" begin
    template_uc = get_template_basic_uc_simulation()
    set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
    set_network_model!(template_uc, NetworkModel(
        CopperPlatePowerModel,
        # MILP "duals" not supported with free solvers
        # duals = [CopperPlateBalanceConstraint],
    ))

    template_ed = get_template_nomin_ed_simulation(
        NetworkModel(
            CopperPlatePowerModel;
            # Added because of data issues
            use_slacks = true,
            duals = [CopperPlateBalanceConstraint],
        ),
    )
    set_device_model!(template_ed, InterruptiblePowerLoad, StaticPowerLoad)
    c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
    c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_uc,
                c_sys5_hy_uc;
                name = "UC",
                optimizer = HiGHS_optimizer,
            ),
            DecisionModel(
                template_ed,
                c_sys5_hy_ed;
                name = "ED",
                optimizer = ipopt_optimizer,
            ),
        ],
    )

    sequence = SimulationSequence(;
        models = models,
        feedforwards = Dict(
            "ED" => [
                SemiContinuousFeedforward(;
                    component_type = ThermalStandard,
                    source = OnVariable,
                    affected_values = [ActivePowerVariable],
                ),
            ],
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    sim = Simulation(;
        name = "aggregation",
        steps = 2,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = false),
    )

    build_out = build!(sim; console_level = Logging.Error)
    @test build_out == PSI.SimulationBuildStatus.BUILT
    execute_out = execute!(sim)
    @test execute_out == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    @testset "Verify simulation events" begin
        file = joinpath(PSI.get_simulation_dir(sim), "recorder", "simulation_status.log")
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
        # This value needs to be checked
        @test length(events) == 20

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
            model_name = "UC",
        )
        @test length(events) == 0
        events = PSI.list_simulation_events(
            PSI.InitialConditionUpdateEvent,
            PSI.get_simulation_dir(sim),
            ;
            step = 2,
            model_name = "UC",
        )
        @test length(events) == 20
        PSI.show_simulation_events(
            devnull,
            PSI.InitialConditionUpdateEvent,
            PSI.get_simulation_dir(sim),
            ;
            step = 2,
            model_name = "UC",
        )
    end

    # @testset "Check Serialization - Deserialization of Sim" begin
    #     path = mktempdir()
    #     files_path = PSI.serialize_simulation(sim; path = path)
    #     deserialized_sim = Simulation(files_path, stage_info)
    #     build_out = build!(deserialized_sim)
    #     @test build_out == PSI.SimulationBuildStatus.BUILT
    #     for stage in values(PSI.get_stages(deserialized_sim))
    #         @test PSI.is_stage_built(stage)
    #     end
    # end

end

#= Re-enable when cost functions are updated
function test_3_stage_simulation_with_feedforwards(in_memory)
    sys_rts_da = PSB.build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
    sys_rts_rt = PSB.build_system(PSISystems, "modified_RTS_GMLC_RT_sys")
    sys_rts_ha = deepcopy(sys_rts_rt)

    PSY.transform_single_time_series!(sys_rts_da, 36, Hour(24))
    PSY.transform_single_time_series!(sys_rts_ha, 24, Hour(1))
    PSY.transform_single_time_series!(sys_rts_rt, 12, Hour(1))

    template_uc = get_template_standard_uc_simulation()
    set_network_model!(template_uc, NetworkModel(CopperPlatePowerModel))
    template_ha = deepcopy(template_uc)
    # network slacks added because of data issues
    template_ed = get_thermal_dispatch_template_network(
        NetworkModel(CopperPlatePowerModel; use_slacks = true),
    )

    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_uc,
                sys_rts_da;
                name = "UC",
                optimizer = HiGHS_optimizer,
                initialize_model = false,
            ),
            DecisionModel(
                template_ha,
                sys_rts_ha;
                name = "HA",
                optimizer = HiGHS_optimizer,
                initialize_model = false,
            ),
            DecisionModel(
                template_ed,
                sys_rts_rt;
                name = "ED",
                optimizer = HiGHS_optimizer,
                initialize_model = false,
            ),
        ],
    )

    sequence = SimulationSequence(;
        models = models,
        feedforwards = Dict(
            "ED" => [
                SemiContinuousFeedforward(;
                    component_type = ThermalStandard,
                    source = OnVariable,
                    affected_values = [ActivePowerVariable],
                ),
            ],
        ),
        ini_cond_chronology = InterProblemChronology(),
    )

    sim = Simulation(;
        name = "3stage_feedforward",
        steps = 1,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )
    build_out = build!(sim)
    @test build_out == PSI.SimulationBuildStatus.BUILT
    # execute_out = execute!(sim, in_memory = in_memory)
    # @test execute_out == PSI.RunStatus.SUCCESSFULLY_FINALIZED
end

@testset "Test 3 stage simulation with FeedForwards" begin
    for in_memory in (true, false)
        test_3_stage_simulation_with_feedforwards(in_memory)
    end
end

# TODO: Re-enable once MarketBid Cost is re-implemented
@testset "UC with MarketBid Cost in ThermalGenerators simulations" begin
    template = get_thermal_dispatch_template_network(
        NetworkModel(CopperPlatePowerModel; use_slacks = true),
    )
    set_device_model!(template, DeviceModel(ThermalStandard, ThermalDispatchNoMin))
    set_device_model!(template, DeviceModel(ThermalMultiStart, ThermalBasicUnitCommitment))

    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                UnitCommitmentProblem,
                template,
                PSB.build_system(PSITestSystems, "c_market_bid_cost");
                optimizer = cbc_optimizer,
                initialize_model = false,
            ),
        ],
    )

    sequence =
        SimulationSequence(;
            models = models,
            ini_cond_chronology = InterProblemChronology(),
        )

    sim = Simulation(;
        name = "pwl_cost_test",
        steps = 2,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )

    @test build!(sim) == PSI.SimulationBuildStatus.BUILT
    @test execute!(sim) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
    # TODO: Add more testing of resulting values
end
=#
