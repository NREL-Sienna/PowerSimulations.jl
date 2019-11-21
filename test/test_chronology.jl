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
sim_results = execute!(sim)
stage = ["stage-1", "stage-2"]

@testset "Testing to verify length of time_stamp" begin
    for ix in stage
        results = load_simulation_results(ix, sim_results)
        @test size(unique(results.time_stamp), 1) == size(results.time_stamp, 1)
    end
end

@testset "Testing to verify no gaps in the time_stamp" begin
    for (ix, s) in enumerate(sim.stages)
        results = load_simulation_results(stage[ix], sim_results)
        resolution = convert(Dates.Minute, get_sim_resolution(s))
        time_stamp = results.time_stamp
        length = size(time_stamp,1)
        test = results.time_stamp[1,1]:resolution:results.time_stamp[length,1]
        @test time_stamp[!,:Range] == test
    end
end