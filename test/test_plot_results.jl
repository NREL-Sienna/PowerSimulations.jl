IS.configure_logging(console_level = Logging.Info)
if !isdir(joinpath(pwd(), "testing_plots"))
    file_path = mkdir(joinpath(pwd(), "testing_plots"))
else
    file_path = joinpath(pwd(), "testing_plots")
end

function test_plots(file_path::String)
    devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(ThermalStandard, ThermalDispatch),
                                    :Loads =>  DeviceModel(PowerLoad, StaticPowerLoad))
    branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(Line, StaticLine),
                                     :T => DeviceModel(Transformer2W, StaticTransformer),
                                     :TT => DeviceModel(TapTransformer , StaticTransformer))
    services = Dict{Symbol, ServiceModel}()
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services);
    op_problem = OperationsProblem(TestOpProblem, template, c_sys5; optimizer = OSQP_optimizer, use_parameters = true)
    res = solve_op_problem!(op_problem)

    @testset "testing bar plot" begin
        results = PSI.OperationsProblemResults(res.variables, res.total_cost, res.optimizer_log, res.time_stamp)
        key_name = collect(keys(results.variables))
        for name in key_name
            variable_bar = get_bar_plot_data(results, string(name))
            sort = sort!(names(results.variables[name]))
            sorted_results = res.variables[name][:, sort]
            for i in 1:length(sort)
                @test isapprox(variable_bar.bar_data[i], sum(sorted_results[:, i]))
            end
            @test typeof(variable_bar) == PSI.BarPlot
        end
        bar_gen = get_bar_gen_data(results)
        @test typeof(bar_gen) == PSI.BarGeneration
    end

    @testset "testing size of stack plot data" begin
        results = PSI.OperationsProblemResults(res.variables, res.total_cost, res.optimizer_log, res.time_stamp)
        key_name = collect(keys(results.variables))
        for name in key_name
            variable_stack = get_stacked_plot_data(results, string(name))
            data = variable_stack.data_matrix
            legend = variable_stack.labels
            @test size(data) == size(res.variables[name])
            @test length(legend) == size(data, 2)
            @test typeof(variable_stack) == PSI.StackedArea
        end
        gen_stack = get_stacked_generation_data(results)
        @test typeof(gen_stack) == PSI.StackedGeneration
    end

end

try
    test_plots(file_path)
finally
    @info("removing test files")
    rm(file_path, recursive=true)
end