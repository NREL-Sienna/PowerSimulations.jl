stages_definition = Dict("UC" => Stage(GenericOpProblem, template_uc, c_sys5_uc, GLPK_optimizer),
                         "ED" => Stage(GenericOpProblem, template_ed, c_sys5_ed, GLPK_optimizer))

sequence = SimulationSequence(stage_order = Dict(1 => "UC", 2 => "ED")
                   feed_forward_chronologies = Dict(("UC"=>"ED") => Synchronize(from_steps = 24, to_executions = 1)),
                   horizons = Dict("UC" => 48, "ED" => 12),
                   intervals = Dict("UC" => Hour(24), "ED" => Hour(1)),
                   feedforward = Dict((:Devices, "ED") => SemiContinuousFF(:Generators, binary_from_stage = :ON, affected_variables = [:P])),
                   cache = Dict("ED" => [TimeStatusChange(:ON_ThermalStandard)]),
                   ini_cond_chronology = Dict("UC" => Consecutive(), "ED" => Consecutive())
                   )

    for field in fieldnames(SimulationSequence)
          @test !isempty(getfield(sequence, field))
    end

    sim = Simulation(name = "test",
                 steps = 2,
                 stages = stages_definition,
                 stages_sequence = sequence,
                 simulation_folder= "/Users/jdlara/Desktop/",
                 verbose = true)

    @test isa(sim.sequence, SimulationSequence)

end
