using PowerSystems
using PowerSimulations
using JuMP

base_dir = string(dirname(dirname(pathof(PowerSystems))))
println(joinpath(base_dir,"data/data_5bus.jl"))
include(joinpath(base_dir,"data/data_5bus.jl"))

battery = [GenericBattery(name = "Bat",
                status = true,
                bus = nodes5[1],
                realpower = 10.0,
                energy = 5.0,
                capacity = (min = 0.0, max = 0.0),
                inputrealpowerlimits = (min = 0.0, max = 50.0),
                outputrealpowerlimits = (min = 0.0, max = 50.0),
                efficiency = (in = 0.90, out = 0.80),
                )];

generators_hg = [
    HydroFix("HydroFix",true,nodes5[2],
        TechHydro(60.0, 15.0, (min = 0.0, max = 60.0), nothing, nothing, nothing, nothing),
        TimeSeries.TimeArray(DayAhead,solar_ts_DA)
    ),
    HydroCurtailment("HydroCurtailment",true,nodes5[3],
        TechHydro(60.0, 10.0, (min = 0.0, max = 60.0), nothing, nothing, (up = 10.0, down = 10.0), nothing),
        1000.0,TimeSeries.TimeArray(DayAhead,wind_ts_DA) )
]

sys5b = PowerSystem(nodes5, append!(generators5, generators_hg), loads5_DA, branches5, battery,  1000.0)

m=Model()
devices_netinjection =  PowerSimulations.JumpAffineExpressionArray(length(sys5b.buses), sys5b.time_periods)

#Thermal Generator Models
pth, inyection_array = PowerSimulations.activepowervariables(m, devices_netinjection,   sys5b.generators.thermal, sys5b.time_periods);
pre_set = [d for d in sys5b.generators.renewable if !isa(d, RenewableFix)]
pre, inyection_array = PowerSimulations.activepowervariables(m, devices_netinjection,  pre_set, sys5b.time_periods)
test_cl = [d for d in sys5b.loads if !isa(d, PowerSystems.StaticLoad)] # Filter StaticLoads Out
pcl, inyection_array = PowerSimulations.loadvariables(m, devices_netinjection,  test_cl, sys5b.time_periods);
test_hy = [d for d in generators_hg if !isa(d, PowerSystems.HydroFix)] # Filter StaticLoads Out
phg, inyection_array = PowerSimulations.activepowervariables(m, devices_netinjection,  test_hy, sys5b.time_periods)
pbtin, pbtout, inyection_array = PowerSimulations.powerstoragevariables(m, devices_netinjection,  sys5b.storage, sys5b.time_periods)

#CopperPlate Network test
m = PowerSimulations.constructnetwork!(CopperPlatePowerModel, m, devices_netinjection, sys5b)

#Reset EveryThing to Build the nodebalance network
m=Model()
devices_netinjection =  PowerSimulations.JumpAffineExpressionArray(length(sys5b.buses), sys5b.time_periods)

pth, inyection_array = PowerSimulations.activepowervariables(m, devices_netinjection,   sys5b.generators.thermal, sys5b.time_periods);
pre_set = [d for d in sys5b.generators.renewable if !isa(d, RenewableFix)]
pre, inyection_array = PowerSimulations.activepowervariables(m, devices_netinjection,  pre_set, sys5b.time_periods)
test_cl = [d for d in sys5b.loads if !isa(d, PowerSystems.StaticLoad)] # Filter StaticLoads Out
pcl, inyection_array = PowerSimulations.loadvariables(m, devices_netinjection,  test_cl, sys5b.time_periods);
test_hy = [d for d in generators_hg if !isa(d, PowerSystems.HydroFix)] # Filter StaticLoads Out
phg, inyection_array = PowerSimulations.activepowervariables(m, devices_netinjection,  test_hy, sys5b.time_periods)
pbtin, pbtout, inyection_array = PowerSimulations.powerstoragevariables(m, devices_netinjection,  sys5b.storage, sys5b.time_periods)

m = PowerSimulations.constructnetwork!(StandardPTDFForm,m,devices_netinjection,sys5b)

true
