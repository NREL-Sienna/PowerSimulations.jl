using PowerSystems
using PowerSimulations
using JuMP

include(string(homedir(),"/.julia/v0.6/PowerSystems/data/data_5bus.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing,  1000.0)

m = Model()

devices_netinjection =  BusTimeJuMPMapping(length(sys5.buses), sys5.time_periods)

test_cl = [d for d in sys5.loads if !isa(d, PowerSystems.StaticLoad)] # Filter StaticLoads Out

pcl, inyection_array = PowerSimulations.loadvariables(m, devices_netinjection,  test_cl, sys5.time_periods);
m = PowerSimulations.powerconstraints(m, pcl, test_cl, sys5.time_periods)


true
