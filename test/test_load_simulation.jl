include("../Simulations_preload.jl");

branches = Dict{Symbol, DeviceModel}()
services = Dict{Symbol, PSI.ServiceModel}()
devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, PSI.ThermalBasicUnitCommitment),
                                    :Ren => DeviceModel(PSY.RenewableDispatch, PSI.RenewableFixed),
                                    :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad),
                                    :ILoads =>  DeviceModel(PSY.InterruptibleLoad, PSI.StaticPowerLoad),
                                    )       
template_uc= OperationsTemplate(CopperPlatePowerModel, devices, branches, services);

## ED Model Ref
branches = Dict{Symbol, DeviceModel}()
services = Dict{Symbol, PSI.ServiceModel}()
devices = Dict{Symbol, DeviceModel}(:Generators => DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatchNoMin, SemiContinuousFF(:P, :ON)),
                                    :Ren => DeviceModel(PSY.RenewableDispatch, PSI.RenewableFullDispatch),
                                    :Loads =>  DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad),
                                    :ILoads =>  DeviceModel(PSY.InterruptibleLoad, PSI.DispatchablePowerLoad),
                                    )       
template_ed= OperationsTemplate(CopperPlatePowerModel, devices, branches, services);

GLPK_optimizer = with_optimizer(GLPK.Optimizer)

stages = Dict(1 => Stage(template_uc, 24, Hour(24), 1, c_sys5_uc, GLPK_optimizer,  Dict(0 => Sequential())),
              2 => Stage(template_ed, 12, Minute(5), 24, c_sys5_ed, GLPK_optimizer, Dict(1 => Synchronize(24,1), 0 => Sequential()), TimeStatusChange(:ON_ThermalStandard)))

sim = Simulation("test", 2, stages, "/Users/lhanig/Documents/"; verbose = true)
sim_results, date_run = execute!(sim)
step = ["step-1", "step-2"]
stages = ["stage-1", "stage-2"]

@testset "testing reading and writing to the results folder" begin
    for (ix, s) in enumerate(stages)
        files = collect(readdir("/Users/lhanig/Documents/test/$date_run/results"))
        for f in files
            rm("/Users/lhanig/Documents/test/$date_run/results/$f")
        end
    res = load_simulation_results(s, sim_results; write = true)
    loaded_res = load_operation_results("/Users/lhanig/Documents/test/$date_run/results")
    @test loaded_res.variables == res.variables
    end
end

@testset "testing file names" begin
    for (ix, s) in enumerate(stages)
        files = collect(readdir("/Users/lhanig/Documents/test/$date_run/results"))
        for f in files
            rm("/Users/lhanig/Documents/test/$date_run/results/$f")
        end
        res = load_simulation_results(s, sim_results; write = true)
        variable_list = String.(collect(keys(sim.stages[ix].canonical.variables)))
        variable_list = [variable_list; "optimizer_log"; "time_stamp"; "check_sum"]
        file_list = collect(readdir("/Users/lhanig/Documents/test/$date_run/results"))
        for name in file_list
            variable = splitext(name)[1]
            @test any(x -> x == variable, variable_list)
        end
    end
end

@testset "testing argument errors" begin
    for (ix, s) in enumerate(stages)
        files = collect(readdir("/Users/lhanig/Documents/test/$date_run/results"))
        for f in files
            rm("/Users/lhanig/Documents/test/$date_run/results/$f")
        end
        res = load_simulation_results(s, sim_results)
        @test_throws ArgumentError write_results(res, "nothing", "results")
    end
end

@testset "checking total sums" begin
    for (ix, s) in enumerate(stages)
        files = collect(readdir("/Users/lhanig/Documents/test/$date_run/results"))
        for f in files
            rm("/Users/lhanig/Documents/test/$date_run/results/$f")
        end
        res = load_simulation_results(s, sim_results; write = true)
        loaded_res = load_operation_results("/Users/lhanig/Documents/test/$date_run/results")
        @test res.check_sum == loaded_res.check_sum
    end
end

@testset "testing load simulation results functionality stage 2" begin
    for (ix,s) in enumerate(stages)
        variable = (collect(keys(sim.stages[ix].canonical.variables)))
        results = load_simulation_results(s, sim_results)
        res = load_simulation_results(s, step, variable, sim_results)
        @test results.variables == res.variables
    end
end