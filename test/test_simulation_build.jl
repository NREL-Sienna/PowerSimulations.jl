function create_stages(template_uc, c_sys5_uc, c_sys5_ed)
    return Dict(
        "UC" => OperationsProblem(GenericOpProblem, template_uc, c_sys5_uc, GLPK_optimizer),
        "ED" => OperationsProblem(GenericOpProblem, template_ed, c_sys5_ed, GLPK_optimizer),
    )
end

function create_sequence()
    return SimulationSequence(
        step_resolution = Hour(24),
        order = Dict(1 => "UC", 2 => "ED"),
        feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
        horizons = Dict("UC" => 24, "ED" => 12),
        intervals = Dict(
            "UC" => (Hour(24), Consecutive()),
            "ED" => (Hour(1), Consecutive()),
        ),
        feedforward = Dict(
            ("ED", :devices, :Generators) => SemiContinuousFF(
                binary_source_stage = PSI.ON,
                affected_variables = [PSI.ACTIVE_POWER],
            ),
        ),
        ini_cond_chronology = InterStageChronology(),
    )
end

function test_simulation_build(file_path::String)
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    c_sys5_ed = PSB.build_system(PSITestSystems, "c_sys5_ed")

    @testset "Test Simulation Simulation Sequence Validation" begin
        sequence = create_sequence()
        @test length(findall(x -> x == 2, sequence.execution_order)) == 24
        @test length(findall(x -> x == 1, sequence.execution_order)) == 1
    end

    @testset "Simulation with provided initial time" begin
        stages_definition = create_stages(template_basic_uc, c_sys5_uc, c_sys5_ed)
        sequence = create_sequence()
        second_day = DateTime("1/1/2024  23:00:00", "d/m/y  H:M:S") + Hour(1)
        sim = Simulation(
            name = "test",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
            initial_time = second_day,
        )
        build!(sim)

        for stage in values(sim.stages)
            @test PSI.get_initial_time(stage) == second_day
        end
    end

    @testset "Simulation Build Tests" begin
        stages_definition = create_stages(template_basic_uc, c_sys5_uc, c_sys5_ed)
        sequence = create_sequence()
        sim = Simulation(
            name = "test",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )
        build!(sim)

        @test isempty(values(sim.internal.simulation_cache))
        for field in fieldnames(SimulationSequence)
            if fieldtype(SimulationSequence, field) == Union{Dates.DateTime, Nothing}
                @test !isnothing(getfield(sim.sequence, field))
            end
        end
        @test isa(sim.sequence, SimulationSequence)
    end

    ####################### Negative Tests ########################################
    @testset "Test when a simulation has incorrect arguments" begin
        @test_throws UndefKeywordError sim =
            Simulation(name = "test", steps = 1, simulation_folder = file_path)
    end

    @testset "Test if a wrong initial time is provided" begin
        stages_definition = create_stages(template_basic_uc, c_sys5_uc, c_sys5_ed)
        sequence = create_sequence()
        sim = Simulation(
            name = "test",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
            initial_time = Dates.now(),
        )
        @test_throws IS.ConflictingInputsError build!(sim)
    end

    @testset "Test if file path is not writeable" begin
        stages_definition = create_stages(template_basic_uc, c_sys5_uc, c_sys5_ed)
        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "fake_path",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = "fake_path",
        )
        @test_throws IS.ConflictingInputsError PSI._check_folder(sim)
    end

    @testset "chronology look ahead length is too long for horizon" begin
        stages_definition = create_stages(template_basic_uc, c_sys5_uc, c_sys5_ed)
        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 30)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "look_ahead",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )
        @test_throws IS.ConflictingInputsError PSI._check_feedforward_chronologies(sim)
    end

    @testset "too long of a horizon for forecast" begin
        stages_definition = create_stages(template_basic_uc, c_sys5_uc, c_sys5_ed)
        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 72, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "long_horizon",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )
        sim.internal = PSI.SimulationInternal(
            sim.steps,
            keys(PSI.get_sequence(sim).order),
            mktempdir(),
            PSI.get_name(sim),
        )
        @test_throws IS.ConflictingInputsError build!(sim)
    end

    @testset "Test too many steps for forecast" begin
        stages_definition = create_stages(template_basic_uc, c_sys5_uc, c_sys5_ed)
        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "steps",
            steps = 5,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )
        @test_throws IS.ConflictingInputsError build!(sim)
    end

    @testset "Test Creation of Simulations with Cache" begin
        stages_definition = create_stages(template_standard_uc, c_sys5_uc, c_sys5_ed)

        # Cache is not defined all together
        sequence_no_cache = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "cache",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence_no_cache,
            simulation_folder = file_path,
        )
        build!(sim)

        @test !isempty(sim.internal.simulation_cache)

        stages_definition = create_stages(template_standard_uc, c_sys5_uc, c_sys5_ed)
        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            cache = Dict(("UC",) => TimeStatusChange(PSY.ThermalStandard, PSI.ON)),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "caches",
            steps = 2,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )

        build!(sim)

        @test !isempty(sim.internal.simulation_cache)

        stages_definition = create_stages(template_standard_uc, c_sys5_uc, c_sys5_ed)
        # Uses IntraStage but the cache is defined in the wrong stage
        sequence_bad_cache = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            cache = Dict(("ED",) => TimeStatusChange(PSY.ThermalStandard, PSI.ON)),
            ini_cond_chronology = IntraStageChronology(),
        )

        sim = Simulation(
            name = "test",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence_bad_cache,
            simulation_folder = file_path,
        )
        @test_throws IS.InvalidValue build!(sim)
    end

    @testset "Create Stages with kwargs and custom models" begin
        my_model = JuMP.Model()
        my_model.ext[:PSI_Testing] = 1
        stages_definition_kwargs = Dict(
            "UC" => OperationsProblem(
                GenericOpProblem,
                template_basic_uc,
                c_sys5_uc,
                GLPK_optimizer,
                my_model,
            ),
            "ED" => OperationsProblem(
                GenericOpProblem,
                template_ed_ptdf,
                c_sys5_ed,
                GLPK_optimizer;
                PTDF = PTDF(c_sys5_ed),
            ),
        )

        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "test",
            steps = 1,
            stages = stages_definition_kwargs,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )
        @test haskey(
            sim.stages["UC"].internal.optimization_container.JuMPmodel.ext,
            :PSI_Testing,
        )
        @test !isnothing(sim.stages["ED"].internal.optimization_container.settings.PTDF)
    end
    @testset "Create Simulation using SOS-PWL cost function" begin
        c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pwl_uc")
        c_sys5_ed = PSB.build_system(PSITestSystems, "c_sys5_pwl_ed")
        stages_definition_kwargs = Dict(
            "UC" => OperationsProblem(
                GenericOpProblem,
                template_pwl_standard_uc,
                c_sys5_uc,
                Cbc_optimizer,
            ),
            "ED" => OperationsProblem(
                GenericOpProblem,
                template_pwl_ed,
                c_sys5_ed,
                Cbc_optimizer,
            ),
        )
        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "test",
            steps = 2,
            stages = stages_definition_kwargs,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )
        build!(sim)
    end
    @testset "Test Multistart Thermal UC Simulation" begin
        c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib_sim")
        stages_definition = Dict(
            "UC" => OperationsProblem(
                GenericOpProblem,
                template_multi_start_uc,
                c_sys5_pglib,
                Cbc_optimizer,
                balance_slack_variables = true,
            ),
        )
        sequence = SimulationSequence(
            step_resolution = Hour(14),
            order = Dict(1 => "UC"),
            horizons = Dict("UC" => 24),
            intervals = Dict("UC" => (Hour(14), Consecutive())),
            ini_cond_chronology = IntraStageChronology(),
        )
        sim = Simulation(
            name = "multi_start-test",
            steps = 2,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )
        build!(sim)
    end
end

@testset "Test simulation build" begin
    path = joinpath(pwd(), "test_simulation_build")
    !isdir(path) && mkdir(path)
    try
        test_simulation_build(path)
    finally
        @info("removing test files")
        rm(path, force = true, recursive = true)
    end
end

@testset "Test simulation run directory output" begin
    base_path = mktempdir()
    @test PSI._get_output_dir_name(base_path, nothing) == "1"
    mkdir(joinpath(base_path, "1"))
    @test PSI._get_output_dir_name(base_path, nothing) == "2"
    mkdir(joinpath(base_path, "5"))
    @test PSI._get_output_dir_name(base_path, nothing) == "6"
    mkdir(joinpath(base_path, "10"))
    @test PSI._get_output_dir_name(base_path, nothing) == "11"
    @test PSI._get_output_dir_name(base_path, "test") == "test"
end
