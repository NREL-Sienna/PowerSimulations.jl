if !isdir(joinpath(pwd(), "testing_reading_results"))
    file_path = mkdir(joinpath(pwd(), "testing_reading_results"))
else
    file_path = (joinpath(pwd(), "testing_reading_results"))
end

function test_load_simulation()
    stages = Dict(1 => Stage(template_uc, 24, Hour(24), 1, c_sys5_uc, GLPK_optimizer,  Dict(0 => Consecutive())),
                2 => Stage(template_ed, 12, Minute(5), 24, c_sys5_ed, GLPK_optimizer, Dict(1 => Synchronize(24,1), 0 => Consecutive()), TimeStatusChange(:ON_ThermalStandard)))

    sim = Simulation("test", 2, stages, file_path; verbose = true)
    sim_results = execute!(sim)
    stage = [1, 2]
    step = ["step-1", "step-2"]
    @testset "testing reading and writing to the results folder" begin
        for ix in stage
            files = collect(readdir(sim_results.results_folder))
            for f in files
                rm("$(sim_results.results_folder)/$f")
            end
        res = load_simulation_results(sim_results, ix; write = true)
        loaded_res = load_operation_results(sim_results.results_folder)
        @test loaded_res.variables == res.variables
        end
    end

    @testset "testing file names" begin
        for ix in stage
            files = collect(readdir(sim_results.results_folder))
            for f in files
                rm("$(sim_results.results_folder)/$f")
            end
            res = load_simulation_results(sim_results, ix; write = true)
            variable_list = String.(collect(keys(sim.stages[ix].psi_container.variables)))
            variable_list = [variable_list; "optimizer_log"; "time_stamp"; "check"]
            file_list = collect(readdir(sim_results.results_folder))
            for name in file_list
                variable = splitext(name)[1]
                @test any(x -> x == variable, variable_list)
            end
        end
    end

    @testset "testing argument errors" begin
        for ix in stage
            files = collect(readdir(sim_results.results_folder))
            for f in files
                rm("$(sim_results.results_folder)/$f")
            end
            res = load_simulation_results(sim_results, ix)
            @test_throws ArgumentError write_results(res, "nothing", "results")
        end
    end
    @testset "testing load simulation results between the two methods of load simulation" begin
        for ix in stage
            variable = (collect(keys(sim.stages[ix].psi_container.variables)))
            results = load_simulation_results(sim_results, ix)
            res = load_simulation_results(sim_results, ix, step, variable)
            @test results.variables == res.variables
        end
    end
    @testset "negative test checking total sums" begin
        for ix in stage
            files = collect(readdir(sim_results.results_folder))
            for f in files
                rm("$(sim_results.results_folder)/$f")
            end
            variable_list = collect(keys(sim.stages[ix].psi_container.variables))
            res = load_simulation_results(sim_results, ix; write = true)
            file_path = joinpath(sim_results.results_folder,"$(variable_list[1]).feather")
            rm(file_path)
            fake_df = DataFrames.DataFrame(:A => Array(1:10))
            Feather.write(file_path, fake_df)
            @test_throws IS.DataFormatError check_file_integrity(dirname(file_path))
        end
        for ix in stage
            files = collect(readdir(sim_results.results_folder))
            for f in files
                rm("$(sim_results.results_folder)/$f")
            end
            variable_list = collect(keys(sim.stages[ix].psi_container.variables))
            check_file_path = sim_results.ref["stage-$ix"][(variable_list[1])][1,3]
            rm(check_file_path)
            time_length = sim_results.chronologies["stage-$ix"]
            fake_df = DataFrames.DataFrame(:A => Array(1:time_length))
            Feather.write(check_file_path, fake_df)
            @test_throws IS.DataFormatError check_file_integrity(dirname(check_file_path))
        end
    end
end
try
    test_load_simulation()
finally
    @info("removing test files")
    rm(file_path, recursive=true)
end
