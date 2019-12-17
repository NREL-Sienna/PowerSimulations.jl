if !isdir(joinpath(pwd(), "test_simulation_sequence"))
    file_path = mkdir(joinpath(pwd(), "testitest_simulation_sequenceng_build"))
else
    file_path = (joinpath(pwd(), "test_simulation_sequence"))
end

@testset "Simulation Sequence Tests" begin
      stages_definition = Dict("UC" => Stage(GenericOpProblem, template_uc, c_sys5_uc, GLPK_optimizer),
                               "ED" => Stage(GenericOpProblem, template_ed, c_sys5_ed, GLPK_optimizer))

sequence = SimulationSequence(initial_time = DateTime("2024-01-01T00:00:00"),
                   order = Dict(1 => "UC", 2 => "ED"),
                   intra_stage_chronologies = Dict(("UC"=>"ED") => Synchronize(from_periods = 24)),
                   horizons = Dict("UC" => 24, "ED" => 12),
                   intervals = Dict("UC" => Hour(24), "ED" => Hour(1)),
                   feed_forward = Dict(("ED", :devices, :Generators) => SemiContinuousFF(binary_from_stage = :ON, affected_variables = [:P])),
                   cache = Dict("ED" => [TimeStatusChange(PSI.UpdateRef{PJ.ParameterRef}(:ON_ThermalStandard))]),
                   ini_cond_chronology = Dict("UC" => Consecutive(), "ED" => Consecutive())
                   )

    for field in fieldnames(SimulationSequence)
        field == :initial_time && continue
        @test !isempty(getfield(sequence, field))
    end

    sim = Simulation(name = "test",
                 steps = 2,
                 stages = stages_definition,
                 stages_sequence = sequence,
                 simulation_folder= file_path,
                 verbose = true)

    @test isa(sim.sequence, SimulationSequence)

    @info("removing test files")
    rm(file_path, recursive=true)
end
