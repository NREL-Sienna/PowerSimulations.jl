@testset "Simulation Build Tests" begin
    models = create_simulation_build_test_problems(get_template_basic_uc_simulation())
    sequence = SimulationSequence(
        models=models,
        feedforwards=Dict(
            "ED" => [
                SemiContinuousFeedforward(
                    component_type=ThermalStandard,
                    source=OnVariable,
                    affected_values=[ActivePowerVariable],
                ),
            ],
        ),
        ini_cond_chronology=InterProblemChronology(),
    )
    sim = Simulation(
        name="test",
        steps=1,
        models=models,
        sequence=sequence,
        simulation_folder=mktempdir(cleanup=true),
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
            count, _ = size(data.values)
            @test count == 24
        elseif PSI.get_entry_type(key) ∈ ed_vars
            count, _ = size(data.values)
            @test count == 288
        end
    end
end

@testset "Simulation with provided initial time" begin
    models = create_simulation_build_test_problems(get_template_basic_uc_simulation())
    sequence = SimulationSequence(
        models=models,
        feedforwards=Dict(
            "ED" => [
                SemiContinuousFeedforward(
                    component_type=ThermalStandard,
                    source=OnVariable,
                    affected_values=[ActivePowerVariable],
                ),
            ],
        ),
        ini_cond_chronology=InterProblemChronology(),
    )
    second_day = DateTime("1/1/2024  23:00:00", "d/m/y  H:M:S") + Hour(1)
    sim = Simulation(
        name="test",
        steps=1,
        models=models,
        sequence=sequence,
        simulation_folder=mktempdir(cleanup=true),
        initial_time=second_day,
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
        models=models,
        feedforwards=Dict(
            "ED" => [
                SemiContinuousFeedforward(
                    component_type=ThermalStandard,
                    source=OnVariable,
                    affected_values=[ActivePowerVariable],
                ),
            ],
        ),
        ini_cond_chronology=InterProblemChronology(),
    )

    @test_throws UndefKeywordError sim = Simulation(name="test", steps=1)

    sim = Simulation(
        name="test",
        steps=1,
        models=models,
        sequence=sequence,
        simulation_folder=mktempdir(cleanup=true),
        initial_time=Dates.now(),
    )

    @test_throws IS.ConflictingInputsError build!(sim, console_level=Logging.AboveMaxLevel)

    sim = Simulation(
        name="fake_path",
        steps=1,
        models=models,
        sequence=sequence,
        simulation_folder="fake_path",
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

    template_uc = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template_uc, ThermalStandard, ThermalBasicUnitCommitment)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_uc, HydroEnergyReservoir, HydroDispatchRunOfRiver)

    template_ed = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template_ed, ThermalStandard, ThermalBasicUnitCommitment)
    set_device_model!(template_ed, PowerLoad, StaticPowerLoad)
    set_device_model!(template_ed, HydroEnergyReservoir, HydroDispatchRunOfRiver)

    models = SimulationModels([
        DecisionModel(
            template,
            name="MD",
            sys_md,
            initialize_model=false,
            system_to_file=false,
            optimizer=HiGHS_optimizer,
        ),
        DecisionModel(
            template_uc,
            name="UC",
            sys_uc,
            initialize_model=false,
            system_to_file=false,
            optimizer=HiGHS_optimizer,
        ),
        DecisionModel(
            template_ed,
            name="ED",
            sys_ed,
            initialize_model=false,
            system_to_file=false,
            optimizer=HiGHS_optimizer,
        ),
    ])

    feedforwards = Dict(
        "UC" => [
            EnergyLimitFeedforward(
                source=ActivePowerVariable,
                affected_values=[ActivePowerVariable],
                component_type=HydroEnergyReservoir,
                number_of_periods=24,
            ),
        ],
        "ED" => [
            EnergyLimitFeedforward(
                source=ActivePowerVariable,
                affected_values=[ActivePowerVariable],
                component_type=HydroEnergyReservoir,
                number_of_periods=12,
            ),
        ],
    )

    test_sequence = SimulationSequence(
        models=models,
        ini_cond_chronology=InterProblemChronology(),
        feedforwards=feedforwards,
    )

    sim = Simulation(
        name="test_md",
        steps=2,
        models=models,
        sequence=test_sequence,
        simulation_folder=mktempdir(cleanup=true),
    )
    @test build!(sim, serialize=false) == PSI.BuildStatus.BUILT
end

@testset "Test SemiContinuous Feedforward with Active and Reactive Power variables" begin
    template_uc = get_template_basic_uc_simulation()
    set_network_model!(template_uc, NetworkModel(DCPPowerModel, use_slacks=true))
    # network slacks added because of data issues
    template_ed =
        get_template_nomin_ed_simulation(NetworkModel(ACPPowerModel, use_slacks=true))
    c_sys5_hy_uc = PSB.build_system(PSITestSystems, "c_sys5_hy_uc")
    c_sys5_hy_ed = PSB.build_system(PSITestSystems, "c_sys5_hy_ed")
    models = SimulationModels(
        decision_models=[
            DecisionModel(
                template_uc,
                c_sys5_hy_uc;
                name="UC",
                optimizer=HiGHS_optimizer,
                initialize_model=false,
            ),
            DecisionModel(
                template_ed,
                c_sys5_hy_ed;
                name="ED",
                optimizer=ipopt_optimizer,
                initialize_model=false,
            ),
        ],
    )

    sequence = SimulationSequence(
        models=models,
        feedforwards=Dict(
            "ED" => [
                SemiContinuousFeedforward(
                    component_type=ThermalStandard,
                    source=OnVariable,
                    affected_values=[ActivePowerVariable, ReactivePowerVariable],
                ),
            ],
        ),
        ini_cond_chronology=InterProblemChronology(),
    )

    sim = Simulation(
        name="reactive_feedforward",
        steps=2,
        models=models,
        sequence=sequence,
        simulation_folder=mktempdir(cleanup=true),
    )
    build_out = build!(sim)
    @test build_out == PSI.BuildStatus.BUILT
    ac_power_model = PSI.get_simulation_model(PSI.get_models(sim), :ED)
    c = PSI.get_constraint(
        PSI.get_optimization_container(ac_power_model),
        FeedforwardSemiContinousConstraint(),
        ThermalStandard,
        "ActivePowerVariableub",
    )
    @test !isempty(c)
    c = PSI.get_constraint(
        PSI.get_optimization_container(ac_power_model),
        FeedforwardSemiContinousConstraint(),
        ThermalStandard,
        "ActivePowerVariablelb",
    )
    @test !isempty(c)
    c = PSI.get_constraint(
        PSI.get_optimization_container(ac_power_model),
        FeedforwardSemiContinousConstraint(),
        ThermalStandard,
        "ReactivePowerVariableub",
    )
    @test !isempty(c)
    c = PSI.get_constraint(
        PSI.get_optimization_container(ac_power_model),
        FeedforwardSemiContinousConstraint(),
        ThermalStandard,
        "ReactivePowerVariablelb",
    )
    @test !isempty(c)
end
