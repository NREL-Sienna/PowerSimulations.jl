path = joinpath(pwd(), "test_sequence_build")
!isdir(path) && mkdir(path)

function test_sequence_build(file_path::String)

    stages_definition = Dict(
        "UC" => Stage(GenericOpProblem, template_uc, c_sys5_uc, GLPK_optimizer),
        "ED" => Stage(GenericOpProblem, template_ed, c_sys5_ed, GLPK_optimizer),
    )

    sequence = SimulationSequence(
        step_resolution = Hour(24),
        order = Dict(1 => "UC", 2 => "ED"),
        feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
        horizons = Dict("UC" => 24, "ED" => 12),
        intervals = Dict("UC" => (Hour(24), Consecutive()), "ED" => (Hour(1), Consecutive())),
        feedforward = Dict(
            ("ED", :devices, :Generators) => SemiContinuousFF(
                binary_from_stage = PSI.ON,
                affected_variables = [PSI.ACTIVE_POWER],
            ),
        ),
        cache = Dict("ED" => [TimeStatusChange(PSY.ThermalStandard, PSI.ON)]),
        ini_cond_chronology = InterStageChronology(),
    )

    @testset "Test Simulation Simulation Sequence Validation" begin
        @test length(findall(x -> x == 2, sequence.execution_order)) == 24
        @test length(findall(x -> x == 1, sequence.execution_order)) == 1
    end

    @testset "Simulation with provided initial time" begin
        second_day = DayAhead[24] + Hour(1)
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
            @test stage.internal.psi_container.initial_time == second_day
        end
    end

    sim = Simulation(
        name = "test",
        steps = 1,
        stages = stages_definition,
        stages_sequence = sequence,
        simulation_folder = file_path,
    )
    build!(sim)

    @testset "Simulation Sequence Tests" begin
        build!(sim)
        for field in fieldnames(SimulationSequence)
            if fieldtype(SimulationSequence, field) == Union{Dates.DateTime, Nothing}
                @test !isnothing(getfield(sim.sequence, field))
            end
        end
        @test isa(sim.sequence, SimulationSequence)
    end

    ###################### Negative Tests ########################################
    @testset "testing when a simulation has incorrect arguments" begin
        sim = Simulation(name = "test", steps = 1, simulation_folder = file_path)
        @test_throws ArgumentError build!(sim)
    end

    @testset "testing if a wrong initial time is provided" begin

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

    @testset "testing if file path is not writeable" begin
        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict("UC" => (Hour(24), Consecutive()), "ED" => (Hour(1), Consecutive())),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_from_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            cache = Dict("ED" => [TimeStatusChange(PSY.ThermalStandard, PSI.ON)]),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "fake_path",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = "fake_path",
        )
        @test_throws IS.ConflictingInputsError PSI._check_folder(sim.simulation_folder)
    end

    @testset "testing if interval is shorter than resolution" begin
        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict("UC" => (Minute(5), RecedingHorizon()), "ED" => (Minute(1), RecedingHorizon())),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_from_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            cache = Dict("ED" => [TimeStatusChange(PSY.ThermalStandard, PSI.ON)]),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "interval",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )
        @test_throws IS.ConflictingInputsError PSI._get_simulation_initial_times!(sim)
    end

    @testset "chronology look ahead length is too long for horizon" begin
        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 30)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict("UC" => (Hour(24), Consecutive()), "ED" => (Hour(1), Consecutive())),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_from_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            cache = Dict("ED" => [TimeStatusChange(PSY.ThermalStandard, PSI.ON)]),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "look_ahead",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )
        @test_throws IS.ConflictingInputsError PSI._check_feedforward_chronologies(sim)#build!(sim)
    end

    @testset "too long of a horizon for forecast" begin
        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 72, "ED" => 12),
            intervals = Dict("UC" => (Hour(24), Consecutive()), "ED" => (Hour(1), Consecutive())),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_from_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            cache = Dict("ED" => [TimeStatusChange(PSY.ThermalStandard, PSI.ON)]),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "long_horizon",
            steps = 1,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )
        sim.internal = PSI.SimulationInternal(sim.steps, keys(sim.sequence.order))
        @test_throws IS.ConflictingInputsError PSI._get_simulation_initial_times!(sim)
    end

    @testset "too many steps for forecast" begin
        sequence = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict("UC" => (Hour(24), Consecutive()), "ED" => (Hour(1), Consecutive())),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_from_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            cache = Dict("ED" => [TimeStatusChange(PSY.ThermalStandard, PSI.ON)]),
            ini_cond_chronology = InterStageChronology(),
        )
        sim = Simulation(
            name = "steps",
            steps = 5,
            stages = stages_definition,
            stages_sequence = sequence,
            simulation_folder = file_path,
        )
        sim.internal = PSI.SimulationInternal(sim.steps, keys(sim.sequence.order))
        stage_initial_times = PSI._get_simulation_initial_times!(sim)
        @test_throws IS.ConflictingInputsError PSI._check_steps(sim, stage_initial_times)
    end
end

try
    test_sequence_build(path)
finally
    @info("removing test files")
    rm(path, recursive = true)
end
