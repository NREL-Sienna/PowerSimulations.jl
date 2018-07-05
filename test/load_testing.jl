using PowerSystems
using JuMP

include(string(homedir(),"/.julia/v0.6/PowerSystems/data/data_5bus.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing, 230.0, 1000.0)

m = Model()

pcl = PowerSimulations.loadvariables(m, sys5b.loads, sys5b.time_periods)
test_cl = [d for d in sys5.loads if !isa(d, PowerSystems.StaticLoad)]
PowerSimulations.powerconstraints(m, pcl, [sys5.loads[4]], sys5b.time_periods)

true