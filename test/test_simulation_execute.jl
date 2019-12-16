if !isdir(joinpath(pwd(), "testing_reading_results"))
    file_path = mkdir(joinpath(pwd(), "testing_reading_results"))
else
    file_path = (joinpath(pwd(), "testing_reading_results"))
end

function test_simulations()
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

        sim = Simulation(name = "test",
                 steps = 2,
                 step_resolution=Hour(24),
                 stages = stages_definition,
                 stages_sequence = sequence,
                 simulation_folder= file_path,
                 verbose = true)

    build!(sim)
    sim_results = execute!(sim)
    stage = [1, 2]

    @testset "Testing to verify length of time_stamp" begin
        for ix in stage
            results = load_simulation_results(sim_results, ix)
            @test size(unique(results.time_stamp), 1) == size(results.time_stamp, 1)
        end
    end

    @testset "Testing to verify no gaps in the time_stamp" begin
        for (ix, s) in enumerate(sim.stages)
            results = load_simulation_results(sim_results, ix)
            resolution = convert(Dates.Minute, get_sim_resolution(s))
            time_stamp = results.time_stamp
            length = size(time_stamp,1)
            test = results.time_stamp[1,1]:resolution:results.time_stamp[length,1]
            @test time_stamp[!,:Range] == test
        end
    end
end
try
    test_simulations()
finally
    @info("removing test files")
    rm(file_path, recursive=true)
end
