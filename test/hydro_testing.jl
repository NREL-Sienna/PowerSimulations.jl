using PowerSystems
using JuMP

base_dir = string(dirname(dirname(pathof(PowerSystems))))
println(joinpath(base_dir,"data/data_5bus.jl"))
include(joinpath(base_dir,"data/data_5bus.jl"))

generators_hg = [
    HydroFix("HydroFix",true,nodes5[2],
        TechHydro(60.0, 15.0, (min = 0.0, max = 60.0), nothing, nothing, nothing, nothing),
        TimeSeries.TimeArray(DayAhead,solar_ts_DA)
    ),
    HydroCurtailment("HydroCurtailment",true,nodes5[3],
        TechHydro(60.0, 10.0, (min = 0.0, max = 60.0), nothing, nothing, (up = 10.0, down = 10.0), nothing),
        1000.0,TimeSeries.TimeArray(DayAhead,wind_ts_DA) )
]

m = Model()
sys5b = PowerSystem(nodes5, append!(generators5, generators_hg), loads5_DA, branches5, nothing,  1000.0)

test_hy = [d for d in sys5b.generators.hydro if !isa(d, PowerSystems.HydroFix)] # Filter StaticLoads Out
phg, inyection_array = PowerSimulations.activepowervariables(m, devices_netinjection,  test_hy, sys5.time_periods)

true