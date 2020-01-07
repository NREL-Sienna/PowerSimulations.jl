IS.configure_logging(console_level = Logging.Info)
if !isdir(joinpath(pwd(), "testing_plots"))
    file_path = mkdir(joinpath(pwd(), "testing_plots"))
else
    file_path = joinpath(pwd(), "testing_plots")
end

function test_plots(file_path::String)
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
                        steps = 1, step_resolution =Hour(24),
                        stages = stages_definition,
                        stages_sequence = sequence,
                        simulation_folder= file_path,
                        verbose = true)
    build!(sim)
    sim_results = execute!(sim; verbose = true)
    res_UC = load_simulation_results(sim_results, "UC")
    res_ED = load_simulation_results(sim_results, "ED")

    @testset "testing bar plot" begin
        for res in [res_UC, res_ED]
            results = PSI.OperationsProblemResults(res.variables, res.total_cost, res.optimizer_log, res.time_stamp)
            key_name = collect(keys(results.variables))
                for name in key_name
                        variable_bar = get_bar_plot_data(results, string(name))
                        sort = sort!(names(results.variables[name]))
                        sorted_results = res.variables[name][:, sort]
                        for i in 1:length(sort)
                            @test isapprox(variable_bar.bar_data[i], sum(sorted_results[:, i]))
                        end
                end
        end
    end

    @testset "testing size of stack plot data" begin
        for res in [res_UC, res_ED]
            results = PSI.OperationsProblemResults(res.variables, res.total_cost, res.optimizer_log, res.time_stamp)
            key_name = collect(keys(results.variables))
                for name in key_name
                    variable_stack = get_stacked_plot_data(results, string(name))
                    data = variable_stack.data_matrix
                    legend = variable_stack.labels
                    @test size(data) == size(res.variables[name])
                    @test length(legend) == size(data, 2)
                end
        end
    end

end

try
    test_plots(file_path)
finally
    @info("removing test files")
    rm(file_path, recursive=true)
end