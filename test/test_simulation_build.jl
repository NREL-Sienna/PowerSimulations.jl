@testset "Simulation Sequence Tests" begin
      file_path = joinpath(pwd(), "test_simulation_sequence")
      stages_definition = Dict("UC" => Stage(GenericOpProblem, template_uc, c_sys5_uc, GLPK_optimizer),
                               "ED" => Stage(GenericOpProblem, template_ed, c_sys5_ed, GLPK_optimizer))

sequence = SimulationSequence(order = Dict(1 => "UC", 2 => "ED"),
                   intra_stage_chronologies = Dict(("UC"=>"ED") => Synchronize(from_steps = 24, to_executions = 1)),
                   horizons = Dict("UC" => 24, "ED" => 12),
                   intervals = Dict("UC" => Hour(24), "ED" => Hour(1)),
                   feed_forward = Dict(("ED", :devices, :Generators) => SemiContinuousFF(binary_from_stage = :ON, affected_variables = [:P])),
                   cache = Dict("ED" => [TimeStatusChange(:ON_ThermalStandard)]),
                   ini_cond_chronology = Dict("UC" => Consecutive(), "ED" => Consecutive())
                   )

    for field in fieldnames(SimulationSequence)
        field == :initial_time && continue
        @test !isempty(getfield(sequence, field))
    end

    sim = Simulation(name = "test",
                 steps = 2,
                 step_resolution=Hour(24),
                 stages = stages_definition,
                 stages_sequence = sequence,
                 simulation_folder= file_path,
                 verbose = true)

    @test isa(sim.sequence, SimulationSequence)

end
