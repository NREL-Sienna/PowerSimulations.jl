function create_test_problems(
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
    build!(sim)
end

#=
        @test isempty(values(sim.internal.simulation_cache))
        for field in fieldnames(SimulationSequence)
            if fieldtype(SimulationSequence, field) == Union{Dates.DateTime, Nothing}
                @test !isnothing(getfield(sim.sequence, field))
            end
        end
        @test isa(sim.sequence, SimulationSequence)

        @test length(findall(x -> x == 2, sequence.execution_order)) == 24
        @test length(findall(x -> x == 1, sequence.execution_order)) == 1
    end
=#
