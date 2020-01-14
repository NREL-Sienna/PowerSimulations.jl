path = joinpath(pwd(), "test_writing")
!isdir(path) && mkdir(path)
import CSV

function test_write_functions(file_path)

    devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(ThermalStandard, ThermalDispatch),
                                        :Loads =>  DeviceModel(PowerLoad, StaticPowerLoad))
    branches = Dict{Symbol, DeviceModel}(:L => DeviceModel(Line, StaticLine),
                                         :T => DeviceModel(Transformer2W, StaticTransformer),
                                         :TT => DeviceModel(TapTransformer , StaticTransformer))
    services = Dict{Symbol, ServiceModel}()
    template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services);
    op_problem = OperationsProblem(TestOpProblem, template, c_sys5_re; optimizer = OSQP_optimizer, use_parameters = true)
    res = solve_op_problem!(op_problem)

    @testset "test _write_data functions" begin
        PSI._write_data(res.variables, mkdir(joinpath(file_path, "one")))
        readdir(joinpath(file_path, "one"))
        for (k, v) in res.variables
            @test isfile(joinpath(file_path, "one/$k.feather"))
        end

        PSI._write_data(res.variables, res.time_stamp, mkdir(joinpath(file_path, "two")); file_type = CSV)
        for (k, v) in res.variables
            @test isfile(joinpath(file_path, "two/$k.csv"))
        end

        PSI._write_data(res.variables, res.time_stamp, mkdir(joinpath(file_path, "three")))
        for (k, v) in res.variables
            @test isfile(joinpath(file_path, "three/$k.feather"))
        end

        PSI._write_data(res.variables[:P_ThermalStandard], mkdir(joinpath(file_path, "four")), "P_ThermalStandard")
        @test isfile(joinpath(file_path, "four/P_ThermalStandard.feather"))

        #testing if directory is a file
        PSI._write_data(res.variables[:P_ThermalStandard], joinpath(file_path, "four/P_ThermalStandard.feather"), "P_ThermalStandard")
        @test isfile(joinpath(file_path, "four/P_ThermalStandard.feather"))

        PSI._write_optimizer_log(res.optimizer_log, mkdir(joinpath(file_path, "five")))
        @test isfile(joinpath(file_path, "five/optimizer_log.json"))

        PSI.write_to_CSV(res, mkdir(joinpath(file_path, "six")))
        @test !isempty(joinpath(file_path, "six", "results"))
    end

    @testset "test write result functions" begin
        new_path = joinpath(file_path, "seven")
        @test_throws IS.ConflictingInputsError PSI.write_results(res, new_path) # not yet a directory
        PSI.write_results(res, mkdir(new_path))
        @test !isempty(new_path)
    end

end

try test_write_functions(path)
finally
    @info("removing test files")
    rm(path, recursive=true)
end
