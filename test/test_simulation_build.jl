file_path = joinpath(pwd(), "testing_sequence_build")
!isdir(file_path) && mkdir(file_path)

function test_sequence_build(file_path::String)

    stages_definition = Dict("UC" => Stage(GenericOpProblem, template_uc, c_sys5_uc, GLPK_optimizer),
                                "ED" => Stage(GenericOpProblem, template_ed, c_sys5_ed, GLPK_optimizer))
    @testset "Simulation Sequence Tests" begin

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

        for field in fieldnames(SimulationSequence)
            if fieldtype(SimulationSequence, field) == Union{Dates.DateTime, Nothing}
                 @test !isnothing(getfield(sim.sequence, field))
            end
        end

        @test isa(sim.sequence, SimulationSequence)
    end
        ### Negative Tests
    @testset "testing if horizon is shorter than interval" begin
        sequence = SimulationSequence(order = Dict(1 => "UC", 2 => "ED"),
                    intra_stage_chronologies = Dict(("UC"=>"ED") => Synchronize(from_steps = 24, to_executions = 1)),
                    horizons = Dict("UC" => 4, "ED" => 2),
                    intervals = Dict("UC" => Hour(24), "ED" => Hour(1)),
                    feed_forward = Dict(("ED", :devices, :Generators) => SemiContinuousFF(binary_from_stage = :ON, affected_variables = [:P])),
                    cache = Dict("ED" => [TimeStatusChange(:ON_ThermalStandard)]),
                    ini_cond_chronology = Dict("UC" => Consecutive(), "ED" => Consecutive())
                    )

        sim = Simulation(name = "short_horizon",
                    steps = 2,
                    step_resolution=Hour(24),
                    stages = stages_definition,
                    stages_sequence = sequence,
                    simulation_folder= file_path,
                    verbose = true)
                    
        @test_throws IS.ConflictingInputsError build!(sim)
    end

    @testset "testing if interval is wrong" begin
        sequence = SimulationSequence(order = Dict(1 => "UC", 2 => "ED"),
                    intra_stage_chronologies = Dict(("UC"=>"ED") => Synchronize(from_steps = 24, to_executions = 1)),
                    horizons = Dict("UC" => 24, "ED" => 12),
                    intervals = Dict("UC" => Hour(2), "ED" => Hour(3)),
                    feed_forward = Dict(("ED", :devices, :Generators) => SemiContinuousFF(binary_from_stage = :ON, affected_variables = [:P])),
                    cache = Dict("ED" => [TimeStatusChange(:ON_ThermalStandard)]),
                    ini_cond_chronology = Dict("UC" => Consecutive(), "ED" => Consecutive())
                    )

        sim = Simulation(name = "short_interval",
                    steps = 2,
                    step_resolution=Hour(24),
                    stages = stages_definition,
                    stages_sequence = sequence,
                    simulation_folder= file_path,
                    verbose = true)

        @test_throws IS.ConflictingInputsError build!(sim)
    end
    @testset "testing if file path is not writeable" begin
        sequence = SimulationSequence(order = Dict(1 => "UC", 2 => "ED"),
                    intra_stage_chronologies = Dict(("UC"=>"ED") => Synchronize(from_steps = 24, to_executions = 1)),
                    horizons = Dict("UC" => 24, "ED" => 12),
                    intervals = Dict("UC" => Hour(2), "ED" => Hour(3)),
                    feed_forward = Dict(("ED", :devices, :Generators) => SemiContinuousFF(binary_from_stage = :ON, affected_variables = [:P])),
                    cache = Dict("ED" => [TimeStatusChange(:ON_ThermalStandard)]),
                    ini_cond_chronology = Dict("UC" => Consecutive(), "ED" => Consecutive())
                    )

        sim = Simulation(name = "fake_path",
                    steps = 2,
                    step_resolution=Hour(24),
                    stages = stages_definition,
                    stages_sequence = sequence,
                    simulation_folder= "fake_path",
                    verbose = true)
                    
        @test_throws IS.ConflictingInputsError build!(sim)
    end
    # TODO make check and error
    @testset "testing if interval is shorter than resolution" begin
        sequence = SimulationSequence(order = Dict(1 => "UC", 2 => "ED"),
                    intra_stage_chronologies = Dict(("UC"=>"ED") => Synchronize(from_steps = 24, to_executions = 1)),
                    horizons = Dict("UC" => 24, "ED" => 12),
                    intervals = Dict("UC" => Minute(5), "ED" => Minute(1)),
                    feed_forward = Dict(("ED", :devices, :Generators) => SemiContinuousFF(binary_from_stage = :ON, affected_variables = [:P])),
                    cache = Dict("ED" => [TimeStatusChange(:ON_ThermalStandard)]),
                    ini_cond_chronology = Dict("UC" => Consecutive(), "ED" => Consecutive())
                    )

        sim = Simulation(name = "interval",
                    steps = 2,
                    step_resolution=Hour(24),
                    stages = stages_definition,
                    stages_sequence = sequence,
                    simulation_folder= file_path,
                    verbose = true)
                    
        @test_throws IS.ConflictingInputsError build!(sim) #
    end
    @testset "chronology look ahead length is too long for horizon" begin
        sequence = SimulationSequence(order = Dict(1 => "UC", 2 => "ED"),
                    intra_stage_chronologies = Dict(("UC"=>"ED") => Synchronize(from_steps = 30, to_executions = 1)),
                    horizons = Dict("UC" => 24, "ED" => 12),
                    intervals = Dict("UC" => Minute(5), "ED" => Minute(1)),
                    feed_forward = Dict(("ED", :devices, :Generators) => SemiContinuousFF(binary_from_stage = :ON, affected_variables = [:P])),
                    cache = Dict("ED" => [TimeStatusChange(:ON_ThermalStandard)]),
                    ini_cond_chronology = Dict("UC" => Consecutive(), "ED" => Consecutive())
                    )

        sim = Simulation(name = "look_ahead",
                    steps = 2,
                    step_resolution=Hour(24),
                    stages = stages_definition,
                    stages_sequence = sequence,
                    simulation_folder= file_path,
                    verbose = true)
                    
        @test_throws IS.ConflictingInputsError build!(sim)
    end
     @testset "too many steps for forecast" begin
        sequence = SimulationSequence(order = Dict(1 => "UC", 2 => "ED"),
                    intra_stage_chronologies = Dict(("UC"=>"ED") => Synchronize(from_steps = 24, to_executions = 1)),
                    horizons = Dict("UC" => 24, "ED" => 12),
                    intervals = Dict("UC" => Minute(5), "ED" => Minute(1)),
                    feed_forward = Dict(("ED", :devices, :Generators) => SemiContinuousFF(binary_from_stage = :ON, affected_variables = [:P])),
                    cache = Dict("ED" => [TimeStatusChange(:ON_ThermalStandard)]),
                    ini_cond_chronology = Dict("UC" => Consecutive(), "ED" => Consecutive())
                    )

        sim = Simulation(name = "steps",
                    steps = 5,
                    step_resolution=Hour(24),
                    stages = stages_definition,
                    stages_sequence = sequence,
                    simulation_folder= file_path,
                    verbose = true)
                    
        @test_throws IS.ConflictingInputsError build!(sim)
    end
end

try
    test_sequence_build(file_path)
finally
    @info("removing test files")
    rm(file_path, recursive=true)
end
