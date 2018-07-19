using PowerSystems
using JuMP
using Compat

include(string(homedir(),"/.julia/v0.6/PowerSystems/data/data_5bus.jl"))
sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing,  1000.0)

m = JuMP.Model()
devices_netinjection =  Array{JuMP.GenericAffExpr{Float64,JuMP.Variable},2}(length(sys5.buses), sys5.time_periods)

#Test ED
pth, inyection_array = PowerSimulations.generationvariables(m, devices_netinjection,   sys5.generators.thermal, sys5.time_periods);
PowerSimulations.powerconstraints(m, pth, sys5.generators.thermal, sys5.time_periods)
PowerSimulations.rampconstraints(m, pth, sys5.generators.thermal, sys5.time_periods) : true


#Test UC
m=Model()
pth, inyection_array = PowerSimulations.generationvariables(m, devices_netinjection,   sys5.generators.thermal, sys5.time_periods);
on_thermal, start_thermal, stop_thermal = PowerSimulations.commitmentvariables(m, sys5.generators.thermal, sys5.time_periods)
PowerSimulations.powerconstraints(m, pth, on_thermal, sys5.generators.thermal, sys5.time_periods)
PowerSimulations.rampConstraints(m, pth, on_thermal, sys5.generators.thermal, sys5.time_periods)
PowerSimulations.commitmentconstraints(m, on_thermal, start_thermal, stop_thermal, sys5.generators.thermal, sys5.time_periods)
PowerSimulations.timeconstraints(m, on_thermal, start_thermal, stop_thermal, sys5.generators.thermal, sys5.time_periods) : true

true