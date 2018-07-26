using PowerSystems
using PowerSimulations
using JuMP

include(string(homedir(),"/.julia/v0.6/PowerSystems/data/data_5bus.jl"))

battery = [GenericBattery(name = "Bat",
                status = true,
                energy = 10.0,
                realpower = 10.0,
                capacity = @NT(min = 0.0, max = 10.0,),
                inputrealpowerlimit = 10.0,
                outputrealpowerlimit = 10.0,
                efficiency = @NT(in = 0.90, out = 0.80),
                )];

generators_hg = [
    HydroFix("HydroFix",true,nodes5[2],
        TechHydro(60.0, 15.0, @NT(min = 0.0, max = 60.0), nothing, nothing, nothing, nothing),
        TimeSeries.TimeArray(DayAhead,solar_ts_DA)
    ),
    HydroCurtailment("HydroCurtailment",true,nodes5[3],
        TechHydro(60.0, 10.0, @NT(min = 0.0, max = 60.0), nothing, nothing, @NT(up = 10.0, down = 10.0), nothing),
        1000.0,TimeSeries.TimeArray(DayAhead,wind_ts_DA) )
]

sys5b = PowerSystem(nodes5, append!(generators5, generators_hg), loads5_DA, branches5, battery,  1000.0)

m=Model()
pcl_vars = PowerSimulations.loadvariables(m, sys5b.loads, sys5b.time_periods)
pcl = [d for d in sys5b.loads if isa(d, PowerSystems.InterruptibleLoad)]

tl = PowerSimulations.variablecost(m, pcl_vars, pcl)

pre_vars = PowerSimulations.activepowervariables(m, sys5b.generators.renewable, sys5b.time_periods)
pre = [d for d in sys5b.generators.renewable if !isa(d, PowerSystems.RenewableFix)]
tre = PowerSimulations.variablecost(m, pre_vars, pre)

pth = PowerSimulations.activepowervariables(m, sys5b.generators.thermal, sys5b.time_periods)
on_thermal, start_thermal, stop_thermal = PowerSimulations.CommitmentVariables(m, sys5b.generators.thermal, sys5b.time_periods)
tth = PowerSimulations.variablecost(m, pth, sys5b.generators.thermal)
tcth = PowerSimulations.commitmentcost(m, on_thermal, start_thermal, stop_thermal, sys5b.generators.thermal)
