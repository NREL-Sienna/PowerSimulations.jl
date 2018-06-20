using PowerSystems
using JuMP

include(string(homedir(),"/.julia/v0.6/PowerSystems/data/data_5bus.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, 230.0, 1000.0)

m = Model()

#Test ED
pth = PowerSimulations.GenerationVariables(m, sys5.generators.thermal, sys5.timesteps)
PowerSimulations.PowerConstraints(m, pth, sys5.generators.thermal, sys5.timesteps)
#PowerSimulations.RampConstraints(m, pth ,sys5.generators.thermal, sys5.timesteps)


#Test UC
m=Model()
pth = PowerSimulations.GenerationVariables(m, sys5.generators.thermal, sys5.timesteps)
on_th, start_th, stop_th = PowerSimulations.CommitmentVariables(m, sys5.generators.thermal, sys5.timesteps)
PowerSimulations.PowerConstraints(m, pth, on_th, sys5.generators.thermal, sys5.timesteps)
#PowerSimulations.RampConstraints(m, pth, on_th, sys5.generators.thermal, sys5.timesteps)
PowerSimulations.CommitmentConstraints(m, on_th, start_th, stop_th, sys5.generators.thermal, sys5.timesteps)
#PowerSimulations.TimeConstraints(m, on_th, start_th, stop_th, sys5.generators.thermal, sys5.timesteps)

true