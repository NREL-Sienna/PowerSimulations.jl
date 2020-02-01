using DataFrames
using Dates
using Plots
using PowerSimulationsPlots
using PowerSimulations
using InfrastructureSystems
using Test
using TestSetExtensions
using Weave

const PSI = PowerSimulations
const PSP = PowerSimulationsPlots
const IS = InfrastructureSystems
path = joinpath(pwd(), "plots")
!isdir(path) && mkdir(path)

function test_plots(file_path::String)
    include("test_data.jl")

    @testset "testing results sorting" begin
        Variables = Dict(:P_ThermalStandard => [:one, :two])
        sorted = PSP.sort_data(res; Variables = Variables)
        sorted_two = PSP.sort_data(res)
        sorted_names = [:one, :two]
        sorted_names_two = [:one, :three, :two]
        @test names(sorted.variables[:P_ThermalStandard]) == sorted_names
        @test names(sorted_two.variables[:P_ThermalStandard]) == sorted_names_two
    end

    @testset "testing bar plot" begin
        results = PSI.OperationsProblemResults(
            res.variables,
            res.total_cost,
            res.optimizer_log,
            res.time_stamp,
        )
        for name in keys(results.variables)
            variable_bar = PSP.get_bar_plot_data(results, string(name))
            sort = sort!(names(results.variables[name]))
            sorted_results = res.variables[name][:, sort]
            for i in 1:length(sort)
                @test isapprox(
                    variable_bar.bar_data[i],
                    sum(sorted_results[:, i]),
                    atol = 1.0e-4,
                )
            end
            @test typeof(variable_bar) == PSP.BarPlot
        end
        bar_gen = PSP.get_bar_gen_data(results)
        @test typeof(bar_gen) == PSP.BarGeneration
    end

    @testset "testing size of stack plot data" begin
        results = PSI.OperationsProblemResults(
            res.variables,
            res.total_cost,
            res.optimizer_log,
            res.time_stamp,
        )
        for name in keys(results.variables)
            variable_stack = PSP.get_stacked_plot_data(results, string(name))
            data = variable_stack.data_matrix
            legend = variable_stack.labels
            @test size(data) == size(res.variables[name])
            @test length(legend) == size(data, 2)
            @test typeof(variable_stack) == PSP.StackedArea
        end
        gen_stack = PSP.get_stacked_generation_data(results)
        @test typeof(gen_stack) == PSP.StackedGeneration
    end

    @testset "testing plot production" begin
        bar_plot(res; save = file_path, display = false)
        stack_plot(res; save = file_path, display = false)
        fuel_plot(res, generators; save = file_path, display = false)
        list = readdir(file_path)
        @test list == [
            "Bar_Generation.png",
            "Fuel_Bar.png",
            "Fuel_Stack.png",
            "P_RenewableDispatch_Bar.png",
            "P_RenewableDispatch_Stack.png",
            "P_ThermalStandard_Bar.png",
            "P_ThermalStandard_Stack.png",
            "Stack_Generation.png",
        ]
    end

    @testset "testing report production" begin
        report(res, file_path)
        @test isfile(joinpath(file_path, "report_design.pdf"))
    end
end
try
    test_plots(path)
finally
    @info("removing test files")
    rm(path, recursive = true)
end
