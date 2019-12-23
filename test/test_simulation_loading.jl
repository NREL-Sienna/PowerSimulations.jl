if !isdir(joinpath(pwd(), "testing_reading_results"))
    file_path = mkdir(joinpath(pwd(), "testing_reading_results"))
else
    file_path = (joinpath(pwd(), "testing_reading_results"))
end

function test_load_simulation()
    stages_definition = Dict("UC" => Stage(GenericOpProblem, template_uc, c_sys5_uc, GLPK_optimizer),
                        "ED" => Stage(GenericOpProblem, template_ed, c_sys5_ed, GLPK_optimizer))

    sequence = SimulationSequence(order = Dict(1 => "UC", 2 => "ED"),
                   intra_stage_chronologies = Dict(("UC"=>"ED") => SynchronizeTimeBlocks(from_periods = 1)),
                   horizons = Dict("UC" => 24, "ED" => 12),
                   intervals = Dict("UC" => Hour(24), "ED" => Hour(1)),
                   feed_forward = Dict(("ED", :devices, :Generators) => SemiContinuousFF(binary_from_stage = :ON, affected_variables = [:P])),
                   cache = Dict("ED" => [TimeStatusChange(:ON_ThermalStandard)]),
                   ini_cond_chronology = Dict("UC" => Consecutive(), "ED" => Consecutive())
                   )
    sim = Simulation(name = "aggregation",
                 steps = 2, step_resolution =Hour(24),
                 stages = stages_definition,
                 stages_sequence = sequence,
                 simulation_folder= file_path,
                 verbose = true)
    build!(sim)
    sim_results = execute!(sim)
    stage_names = keys(sim.stages)
    step = ["step-1", "step-2"]

    @testset "testing reading and writing to the results folder" begin
        for name in stage_names
            files = collect(readdir(sim_results.results_folder))
            for f in files
                rm("$(sim_results.results_folder)/$f")
            end
        res = load_simulation_results(sim_results, name; write = true)
        loaded_res = load_operation_results(sim_results.results_folder)
        @test loaded_res.variables == res.variables
        end
    end

    @testset "testing file names" begin
        for name in stage_names
            files = collect(readdir(sim_results.results_folder))
            for f in files
                rm("$(sim_results.results_folder)/$f")
            end
            res = load_simulation_results(sim_results, name; write = true)
            variable_list = String.(PSI.get_variable_names(sim, name))
            variable_list = [variable_list; "optimizer_log"; "time_stamp"; "check"]
            file_list = collect(readdir(sim_results.results_folder))
            for name in file_list
                variable = splitext(name)[1]
                @test any(x -> x == variable, variable_list)
            end
        end
    end

    @testset "testing argument errors" begin
        for name in stage_names
            files = collect(readdir(sim_results.results_folder))
            for f in files
                rm("$(sim_results.results_folder)/$f")
            end
            res = load_simulation_results(sim_results, name)
            @test_throws IS.ConflictingInputsError write_results(res, "nothing", "results")
        end
    end
    @testset "testing load simulation results between the two methods of load simulation" begin
        for name in stage_names
            variable = PSI.get_variable_names(sim, name)
            results = load_simulation_results(sim_results, name)
            res = load_simulation_results(sim_results, name, step, variable)
            @test results.variables == res.variables
        end
    end
    
    @testset "Testing to verify raw output results correctly match aggregated for 
    ceding Horizon" begin
        stages_definition = Dict("UC" => Stage(GenericOpProblem, template_uc, c_sys5_uc, GLPK_optimizer),
                               "ED" => Stage(GenericOpProblem, template_ed, c_sys5_ed, GLPK_optimizer))

        sequence = SimulationSequence(order = Dict(1 => "UC", 2 => "ED"),
                   intra_stage_chronologies = Dict(("UC"=>"ED") => SynchronizeTimeBlocks(from_periods = 1)),
                   horizons = Dict("UC" => 24, "ED" => 12),
                   intervals = Dict("UC" => Hour(1), "ED" => Minute(5)),
                   feed_forward = Dict(("ED", :devices, :Generators) => SemiContinuousFF(binary_from_stage = :ON, affected_variables = [:P])),
                   cache = Dict("ED" => [TimeStatusChange(:ON_ThermalStandard)]),
                   ini_cond_chronology = Dict("UC" => Consecutive(), "ED" => Consecutive())
                   )

        sim = Simulation(name = "receding_results",
                 steps = 2, step_resolution =Hour(24),
                 stages = stages_definition,
                 stages_sequence = sequence,
                 simulation_folder= file_path,
                 verbose = true)
        build!(sim)
        sim_results = execute!(sim)
        stages = ["UC", "ED"]
        for stage in stages
            results = load_simulation_results(sim_results, stage)
            vars_names = [:P_ThermalStandard]
            for name in vars_names
                results.variables[name]
                variable_ref = sim_results.ref["stage-$stage"][name]
                vars = results.variables[name]
                output = vars[end-1, :]
                raw_result = first(Feather.read(variable_ref[(size(variable_ref,1)-1), 3]))
                @test isapprox(output, raw_result, atol = 1e-4)
            end
        end
    end
    
    @testset "negative test checking total sums" begin
        stages_definition = Dict("UC" => Stage(GenericOpProblem, template_uc, c_sys5_uc, GLPK_optimizer),
                        "ED" => Stage(GenericOpProblem, template_ed, c_sys5_ed, GLPK_optimizer))

        sequence = SimulationSequence(order = Dict(1 => "UC", 2 => "ED"),
                   intra_stage_chronologies = Dict(("UC"=>"ED") => SynchronizeTimeBlocks(from_periods = 1)),
                   horizons = Dict("UC" => 24, "ED" => 12),
                   intervals = Dict("UC" => Hour(24), "ED" => Hour(1)),
                   feed_forward = Dict(("ED", :devices, :Generators) => SemiContinuousFF(binary_from_stage = :ON, affected_variables = [:P])),
                   cache = Dict("ED" => [TimeStatusChange(:ON_ThermalStandard)]),
                   ini_cond_chronology = Dict("UC" => Consecutive(), "ED" => Consecutive())
                   )

        sim = Simulation(name = "aggregation",
                 steps = 2, step_resolution = Hour(24),
                 stages = stages_definition,
                 stages_sequence = sequence,
                 simulation_folder= file_path,
                 verbose = true)
        build!(sim)
        sim_results = execute!(sim)
        stage_names = keys(sim.stages)
        for name in stage_names
            files = collect(readdir(sim_results.results_folder))
            for f in files
                rm("$(sim_results.results_folder)/$f")
            end
            variable_list = PSI.get_variable_names(sim, name)
            res = load_simulation_results(sim_results, name; write = true)
            file_path = joinpath(sim_results.results_folder,"$(variable_list[1]).feather")
            rm(file_path)
            fake_df = DataFrames.DataFrame(:A => Array(1:10))
            Feather.write(file_path, fake_df)
               @test_logs((:error, r"hash mismatch"), match_mode=:any,
                    @test_throws(IS.HashMismatchError, check_file_integrity(dirname(file_path)))
                )
        end
        for name in stage_names
            variable_list = PSI.get_variable_names(sim, name)
            check_file_path = PSI.get_reference(sim_results, name, 1, variable_list[1])[1]
            rm(check_file_path)
            time_length = sim_results.chronologies["stage-$name"]
            fake_df = DataFrames.DataFrame(:A => Array(1:time_length))
            Feather.write(check_file_path, fake_df)
                @test_logs((:error, r"hash mismatch"), match_mode=:any,
                    @test_throws(IS.HashMismatchError, check_file_integrity(dirname(check_file_path)))
                )
        end
    end

end
try
    test_load_simulation()
finally
    @info("removing test files")
    rm(file_path, recursive=true)
end
