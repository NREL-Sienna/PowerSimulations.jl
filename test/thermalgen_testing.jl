using PowerSystems
using JuMP

include(string(homedir(),"/.julia/v0.6/PowerSystems/data/data_5bus.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing, 230.0, 1000.0)

m = Model()

#Test ED
pth = PowerSimulations.generationvariables(m, sys5.generators.thermal, sys5.time_periods)
PowerSimulations.powerconstraints(m, pth, sys5.generators.thermal, sys5.time_periods)
#PowerSimulations.RampConstraints(m, pth ,sys5.generators.thermal, sys5.time_periods)


#Test UC
m=Model()
pth = PowerSimulations.generationvariables(m, sys5.generators.thermal, sys5.time_periods)
on_th, start_th, stop_th = PowerSimulations.CommitmentVariables(m, sys5.generators.thermal, sys5.time_periods)
PowerSimulations.powerconstraints(m, pth, on_th, sys5.generators.thermal, sys5.time_periods)
#PowerSimulations.RampConstraints(m, pth, on_th, sys5.generators.thermal, sys5.time_periods)
PowerSimulations.commitmentconstraints(m, on_th, start_th, stop_th, sys5.generators.thermal, sys5.time_periods)
#PowerSimulations.TimeConstraints(m, on_th, start_th, stop_th, sys5.generators.thermal, sys5.time_periods)

true