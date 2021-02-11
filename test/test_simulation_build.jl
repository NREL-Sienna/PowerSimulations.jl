@testset "Simulation Build Tests" begin
    problems = create_test_problems(get_template_basic_uc_simulation())
    sequence = SimulationSequence(
        problems = problems,
        feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
        intervals = Dict(
            "UC" => (Hour(24), Consecutive()),
            "ED" => (Hour(1), Consecutive()),
        ),
        feedforward = Dict(
            ("ED", :devices, :Generators) => SemiContinuousFF(
                binary_source_problem = PSI.ON,
                affected_variables = [PSI.ACTIVE_POWER],
            ),
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    sim = Simulation(
        name = "test",
        steps = 1,
        problems = problems,
        sequence = sequence,
        simulation_folder = mktempdir(cleanup = true),
    )

    build_out = build!(sim)
    @test build_out == PSI.BuildStatus.BUILT

    @test isempty(values(sim.internal.simulation_cache))
    for field in fieldnames(SimulationSequence)
        if fieldtype(SimulationSequence, field) == Union{Dates.DateTime, Nothing}
            @test !isnothing(getfield(sim.sequence, field))
        end
    end
    @test isa(sim.sequence, SimulationSequence)

    @test length(findall(x -> x == 2, sequence.execution_order)) == 24
    @test length(findall(x -> x == 1, sequence.execution_order)) == 1

    @testset "Simulation with provided initial time" begin
        problems = create_test_problems(get_template_basic_uc_simulation())
        sequence = SimulationSequence(
            problems = problems,
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_problem = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterProblemChronology(),
        )
        second_day = DateTime("1/1/2024  23:00:00", "d/m/y  H:M:S") + Hour(1)
        sim = Simulation(
            name = "test",
            steps = 1,
            problems = problems,
            sequence = sequence,
            simulation_folder = mktempdir(cleanup = true),
            initial_time = second_day,
        )
        build_out = build!(sim)
        @test build_out == PSI.BuildStatus.BUILT

        for (_, problem) in PSI.get_problems(sim)
            @test PSI.get_initial_time(problem) == second_day
        end
    end
end
