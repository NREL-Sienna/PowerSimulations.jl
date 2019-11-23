
ipopt_optimizer = with_optimizer(Ipopt.Optimizer, print_level = 4)
GLPK_optimizer = with_optimizer(GLPK.Optimizer, msg_lev = GLPK.MSG_ALL)

base_dir = string(dirname(dirname(pathof(PowerSimulations))))
DATA_DIR = joinpath(base_dir, "test/test_data")
include(joinpath(DATA_DIR, "data_5bus_pu.jl"))
include(joinpath(DATA_DIR, "data_14bus_pu.jl"))

thermal_generators5_uc_testing(nodes5) = [ThermalStandard("Alta", true, nodes5[1], 0.0, 0.0,
           TechThermal(0.5, PowerSystems.ST, PowerSystems.COAL, (min=0.2, max=0.40),  (min = -0.30, max = 0.30), nothing, nothing),
           ThreePartCost((0.0, 1400.0), 0.0, 4.0, 2.0)
           ),
           ThermalStandard("Park City", true, nodes5[1], 0.0, 0.0,
               TechThermal(2.2125, PowerSystems.ST, PowerSystems.COAL, (min=0.65, max=1.70), (min =-1.275, max=1.275), (up=0.02, down=0.02), nothing),
               ThreePartCost((0.0, 1500.0), 0.0, 1.5, 0.75)
           ),
           ThermalStandard("Solitude", true, nodes5[3], 2.7, 0.00,
               TechThermal(5.20, PowerSystems.ST, PowerSystems.COAL, (min=1.0, max=5.20), (min =-3.90, max=3.90), (up=0.0012, down=0.0012), (up=5.0, down=3.0)),
               ThreePartCost((0.0, 3000.0), 0.0, 3.0, 1.5)
           ),
           ThermalStandard("Sundance", true, nodes5[4], 0.0, 0.00,
               TechThermal(2.5, PowerSystems.ST, PowerSystems.COAL, (min=1.0, max=2.0), (min =-1.5, max=1.5), (up=0.015, down=0.015), (up=2.0, down=1.0)),
               ThreePartCost((0.0, 4000.0), 0.0, 4.0, 2.0)
           ),
           ThermalStandard("Brighton", true, nodes5[5], 6.0, 0.0,
               TechThermal(7.5, PowerSystems.ST, PowerSystems.COAL, (min=3.0, max=6.0), (min =-4.50, max=4.50), (up=0.0015, down=0.0015), (up=5.0, down=3.0)),
               ThreePartCost((0.0, 1000.0), 0.0, 1.5, 0.75)
           )];
nodes = nodes5()
c_sys5_uc = System(nodes, vcat(thermal_generators5_uc_testing(nodes), renewable_generators5(nodes)), vcat(loads5(nodes), interruptible(nodes)), branches5(nodes), nothing, 100.0, nothing, nothing);
for t in 1:2
    for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_uc))
        add_forecast!(c_sys5_uc, l, Deterministic("get_maxactivepower", load_timeseries_DA[t][ix]))
    end
    for (ix, r) in enumerate(get_components(RenewableGen, c_sys5_uc))
        add_forecast!(c_sys5_uc, r, Deterministic("get_rating", ren_timeseries_DA[t][ix]))
    end
    for (ix, i) in enumerate(get_components(InterruptibleLoad, c_sys5_uc))
        add_forecast!(c_sys5_uc, i, Deterministic("get_maxactivepower", Iload_timeseries_DA[t][ix]))
    end
end

c_sys5_ed = System(nodes, vcat(thermal_generators5_uc_testing(nodes), renewable_generators5(nodes)), vcat(loads5(nodes), interruptible(nodes)), branches5(nodes), nothing, 100.0, nothing, nothing);

RealTime = collect(DateTime("1/1/2024 0:00:00", "d/m/y H:M:S"):Minute(5):DateTime("1/1/2024 23:55:00", "d/m/y H:M:S"))

load_timeseries_RT = [[TimeArray(RealTime, repeat(loadbus2_ts_DA,inner=12)),
                     TimeArray(RealTime, repeat(loadbus3_ts_DA,inner=12)),
                     TimeArray(RealTime, repeat(loadbus4_ts_DA,inner=12))],
                    [TimeArray(RealTime+Day(1), rand(288)*0.1 + repeat(loadbus2_ts_DA,inner=12)),
                     TimeArray(RealTime+Day(1), rand(288)*0.1 + repeat(loadbus3_ts_DA,inner=12)),
                     TimeArray(RealTime+Day(1), rand(288)*0.1 + repeat(loadbus4_ts_DA,inner=12))]]

for t in 1:2 # loop over days
    for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_ed))
        ta = load_timeseries_DA[t][ix]
        for i in 1:length(ta) # loop over hours
            ini_time = timestamp(ta[i]) #get the hour
            data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
            add_forecast!(c_sys5_ed, l, Deterministic("get_maxactivepower", data))
        end
    end
end
for t in 1:2
    for (ix, l) in enumerate(get_components(RenewableGen, c_sys5_ed))
        ta = load_timeseries_DA[t][ix]
        for i in 1:length(ta) # loop over hours
            ini_time = timestamp(ta[i]) #get the hour
            data = when(load_timeseries_RT[t][ix], hour,hour(ini_time[1])) # get the subset ts for that hour
            add_forecast!(c_sys5_ed, l, Deterministic("get_rating", data))
        end
    end
end
for t in 1:2
    for (ix, l) in enumerate(get_components(InterruptibleLoad, c_sys5_ed))
        ta = load_timeseries_DA[t][ix]
        for i in 1:length(ta) # loop over hours
            ini_time = timestamp(ta[i]) #get the hour
            data = when(load_timeseries_RT[t][ix], hour,hour(ini_time[1])) # get the subset ts for that hour
            add_forecast!(c_sys5_ed, l, Deterministic("get_maxactivepower", data))
        end
    end
end
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

if !isdir(joinpath(pwd(), "testing_reading_results"))
    file_path = mkdir(joinpath(pwd(), "testing_reading_results"))
else
    file_path = (joinpath(pwd(), "testing_reading_results"))
end
sim = Simulation("test", 2, stages, file_path; verbose = true)
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